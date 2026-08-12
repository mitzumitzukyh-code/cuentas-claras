/**
 * Worker de avisos de tasa BCV para Cuenta Clara.
 *
 * Cada hora consulta ve.dolarapi.com, compara con la última tasa conocida y,
 * si hay algo que contar, publica en los topics de FCM correspondientes.
 *
 * Existe en Cloudflare y no en Cloud Functions porque estas exigen el plan
 * Blaze (tarjeta). FCM en cambio se puede usar desde cualquier sitio con una
 * cuenta de servicio, así que el plan gratuito de Firebase sigue bastando.
 */

import { usuarioAutenticado } from './auth.js';
import { carpetaValida, subirFotoFirmada } from './cloudinary.js';
import { enviarAToken, enviarATopic, obtenerToken } from './fcm.js';
import {
  leerEtiqueta,
  leerFiados,
  leerLibreta,
  leerRecibo,
} from './gemini.js';
import { paginaDescargar } from './descargar.js';
import {
  duenosConToken,
  negocioAvisaStock,
  productosBajos,
  ventasDesde,
} from './firestore.js';
import { paginaEliminarCuenta, paginaPrivacidad, paginaTerminos } from './legal.js';
import { construirAvisoStock } from './stock.js';
import {
  DIAS_HISTORIAL,
  construirAvisos,
  esDiaHabilVE,
  tasaEsDeHoy,
} from './tasa.js';
import {
  huellaDeEnvio,
  mensajeResumenVentas,
  resumenesAEnviar,
} from './ventas.js';

/** Una foto de celular comprimida no debería pasar de esto. Corta abusos. */
const MAX_BYTES_IMAGEN = 6 * 1024 * 1024;

/**
 * Usos de IA por usuario y por día. Corta un bucle descontrolado o un abuso
 * sin estorbar el uso real (nadie fotografía 40 etiquetas al día a mano);
 * cuando exista el plan Premium, este número puede depender del plan.
 */
const MAX_USOS_IA_POR_DIA = 40;

const API_TASA = 'https://ve.dolarapi.com/v1/dolares/oficial';

/**
 * Misma casa que [API_TASA]: si el BCV llega, la paralela llega.
 *
 * **No es Binance P2P a proposito, aunque sea lo que usa la app.** Ese
 * endpoint responde 403 a las peticiones que salen de Cloudflare —comprobado
 * con y sin cabeceras de navegador—, asi que `consultarParalelo` devolvia
 * `null` en todas las ejecuciones y el resumen de la manana llevaba meses
 * saliendo solo con el BCV. Desde el telefono si funciona, que es por lo que
 * la app la muestra bien y el push no la traia: el fallo no estaba en el
 * codigo del aviso sino en quien hacia la llamada.
 */
const API_PARALELO = 'https://ve.dolarapi.com/v1/dolares/paralelo';

/** Hora local de Venezuela (UTC−4) a la que sale el resumen de la mañana. */
const HORA_RESUMEN = 8;

/** Hora local de Venezuela a la que sale el resumen de ventas del día. */
const HORA_RESUMEN_VENTAS = 21;

function cuentaDeServicio(env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT) {
    throw new Error(
      'Falta el secreto FIREBASE_SERVICE_ACCOUNT. ' +
        'Cárgalo con: wrangler secret put FIREBASE_SERVICE_ACCOUNT',
    );
  }
  return JSON.parse(env.FIREBASE_SERVICE_ACCOUNT);
}

async function consultarTasa() {
  const resp = await fetch(API_TASA, {
    headers: { accept: 'application/json' },
  });
  if (!resp.ok) throw new Error(`dolarapi respondió ${resp.status}`);

  const json = await resp.json();
  const tasa = Number(json.promedio ?? json.venta);
  if (!Number.isFinite(tasa) || tasa <= 0) {
    throw new Error(`Tasa inválida en la respuesta: ${JSON.stringify(json)}`);
  }
  return { tasa, fuente: json.fechaActualizacion };
}

/**
 * Tasa paralela del dia, para el resumen de la manana.
 *
 * Devuelve `null` ante cualquier fallo en vez de lanzar — la paralela es un
 * extra del resumen, y quedarse sin el aviso del BCV porque la paralela no
 * responda seria cambiar un problema por otro peor.
 */
async function consultarParalelo() {
  try {
    const resp = await fetch(API_PARALELO, {
      headers: { accept: 'application/json' },
    });
    if (!resp.ok) throw new Error(`dolarapi respondió ${resp.status}`);

    const json = await resp.json();
    const tasa = Number(json.promedio ?? json.venta);
    if (!Number.isFinite(tasa) || tasa <= 0) {
      throw new Error(`paralelo inválido: ${JSON.stringify(json)}`);
    }
    return tasa;
  } catch (e) {
    console.error('paralelo no disponible:', e.message);
    return null;
  }
}

/** Fecha en Venezuela (UTC−4) como YYYY-MM-DD. */
function hoyEnVenezuela(ahora = new Date()) {
  const ve = new Date(ahora.getTime() - 4 * 60 * 60 * 1000);
  return ve.toISOString().slice(0, 10);
}

function horaEnVenezuela(ahora = new Date()) {
  return new Date(ahora.getTime() - 4 * 60 * 60 * 1000).getUTCHours();
}

/** Instante UTC que corresponde a las 00:00 de Venezuela del día de [ahora]. */
function inicioDiaVenezuela(ahora = new Date()) {
  const ve = new Date(ahora.getTime() - 4 * 60 * 60 * 1000);
  return new Date(
    Date.UTC(ve.getUTCFullYear(), ve.getUTCMonth(), ve.getUTCDate(), 4, 0, 0),
  );
}

/**
 * Resumen de ventas del día, uno por dueño con notificaciones activas — a
 * diferencia de la tasa BCV (topics compartidos), esto es personal por
 * negocio, así que se manda por token de dispositivo, uno a la vez.
 *
 * Solo actúa a la hora de cierre (`HORA_RESUMEN_VENTAS`); en cualquier otra
 * hora del cron no hace nada. El fallo de un negocio no bloquea a los demás.
 */
async function revisarResumenVentas(env, { ahora = new Date(), forzar = false } = {}) {
  if (!forzar && horaEnVenezuela(ahora) !== HORA_RESUMEN_VENTAS) {
    return { enviados: 0, motivo: 'no es la hora de cierre' };
  }

  const cuenta = cuentaDeServicio(env);
  const tokenOAuth = await obtenerToken(cuenta, env.TASAS);
  const duenos = await duenosConToken({
    token: tokenOAuth,
    projectId: cuenta.project_id,
  });

  const hoy = hoyEnVenezuela(ahora);
  const desde = inicioDiaVenezuela(ahora);
  let enviados = 0;

  // Textos ya mandados a cada teléfono en esta corrida (ver `huellaDeEnvio`).
  // El dedup de KV es por negocio y no puede ver esto: un mismo dispositivo
  // figura como dueño en varios negocios y todos le mandan la misma frase.
  const yaEnviado = new Set();

  // Paso 1 — leer qué vendió cada negocio pendiente. Nada se manda todavía:
  // hace falta el cuadro completo del teléfono para decidir (ver
  // `resumenesAEnviar`).
  const pendientes = [];
  for (const { negocioId, pushToken } of duenos) {
    // Evita mandarlo dos veces si el cron llegara a dispararse más de una
    // vez en la misma hora — no debería pasar, pero es barato cubrirlo.
    // `forzar` (prueba manual) lo salta a propósito.
    const clave = `resumenVentas:${negocioId}`;
    if (!forzar && (await env.TASAS.get(clave)) === hoy) continue;

    try {
      const { total, cobros } = await ventasDesde({
        token: tokenOAuth,
        projectId: cuenta.project_id,
        negocioId,
        desde,
      });
      pendientes.push({ negocioId, pushToken, total, cobros, clave });
    } catch (e) {
      console.error(`resumen de ventas falló para ${negocioId}:`, e.message);
    }
  }

  // Paso 2 — enviar. Un teléfono que ya recibe un resumen con ventas no recibe
  // además el "todavía no registras ventas" de otro de sus negocios.
  const aEnviar = new Set(resumenesAEnviar(pendientes).map((p) => p.negocioId));

  for (const { negocioId, pushToken, total, cobros, clave } of pendientes) {
    try {
      if (aEnviar.has(negocioId)) {
        const mensaje = mensajeResumenVentas({ total, cobros });
        const huella =
          mensaje &&
          huellaDeEnvio({
            destino: pushToken,
            titulo: mensaje.titulo,
            cuerpo: mensaje.cuerpo,
          });
        if (mensaje && !yaEnviado.has(huella)) {
          yaEnviado.add(huella);
          await enviarAToken({
            cuenta,
            token: tokenOAuth,
            destino: pushToken,
            titulo: mensaje.titulo,
            cuerpo: mensaje.cuerpo,
            datos: mensaje.datos,
            canal: 'resumen_ventas',
            // Etiqueta estable: si FCM reintenta la entrega, Android reemplaza
            // el aviso en vez de apilar otro igual.
            etiqueta: `resumen_ventas:${negocioId}`,
          });
          enviados++;
        }
      }
      // Se marca como hecho aunque no se mandara nada (0 cobros, o silenciado
      // porque otro negocio del mismo teléfono sí vendió): si no, cada
      // revisión de la misma hora repetiría la consulta a Firestore el resto
      // del día. Una prueba forzada NO se marca — si no, cancelaría el envío
      // real de esta noche para ese negocio.
      if (!forzar) {
        await env.TASAS.put(clave, hoy, { expirationTtl: 3 * 86400 });
      }
    } catch (e) {
      console.error(`resumen de ventas falló para ${negocioId}:`, e.message);
    }
  }

  return { enviados, negocios: duenos.length };
}

/**
 * Avisa al dueño cuando un producto ACABA de quedarse en stock bajo (o
 * agotado). Se envía al token del dueño, uno por negocio — es información de su
 * inventario, igual que el resumen de ventas.
 *
 * Solo avisa en la TRANSICIÓN a stock bajo, no cada hora: se guarda en KV la
 * lista de productos que ya estaban bajos y solo se notifican los nuevos. Al
 * reabastecer, el producto sale de esa lista y podrá volver a avisar si cae de
 * nuevo. Así el cron puede correr cada hora sin convertirse en spam.
 *
 * `forzar` (prueba manual) ignora el dedup —avisa de todos los bajos actuales—
 * y NO guarda el estado, para no alterar el dedup real de ese negocio.
 */
async function revisarStockBajo(env, { forzar = false } = {}) {
  const cuenta = cuentaDeServicio(env);
  const tokenOAuth = await obtenerToken(cuenta, env.TASAS);
  const duenos = await duenosConToken({
    token: tokenOAuth,
    projectId: cuenta.project_id,
  });

  let enviados = 0;
  for (const { negocioId, pushToken } of duenos) {
    try {
      const activa = await negocioAvisaStock({
        token: tokenOAuth,
        projectId: cuenta.project_id,
        negocioId,
      });
      if (!activa) continue;

      const bajos = await productosBajos({
        token: tokenOAuth,
        projectId: cuenta.project_id,
        negocioId,
      });
      const idsBajos = bajos.map((p) => p.id).sort();

      const clave = `stockAvisado:${negocioId}`;
      const previos = forzar
        ? []
        : (await env.TASAS.get(clave, { type: 'json' })) ?? [];
      const nuevos = bajos.filter((p) => !previos.includes(p.id));

      const aviso = construirAvisoStock(nuevos);
      if (aviso) {
        await enviarAToken({
          cuenta,
          token: tokenOAuth,
          destino: pushToken,
          titulo: aviso.titulo,
          cuerpo: aviso.cuerpo,
          datos: aviso.datos,
          canal: 'stock_bajo',
        });
        enviados++;
      }

      // Se guarda SIEMPRE el estado actual (aunque no se enviara nada): los
      // reabastecidos salen del set y los que siguen bajos no re-avisan. La
      // prueba forzada no guarda, para no pisar el dedup real.
      if (!forzar) {
        await env.TASAS.put(clave, JSON.stringify(idsBajos), {
          expirationTtl: 30 * 86400,
        });
      }
    } catch (e) {
      console.error(`stock bajo falló para ${negocioId}:`, e.message);
    }
  }

  return { enviados, negocios: duenos.length };
}

/**
 * Revisa la tasa y envía lo que toque. Devuelve un resumen para los logs.
 *
 * `validar` propaga el modo `validate_only` de FCM: permite ejercitar todo el
 * camino —incluida la autenticación y el formato del mensaje— sin que llegue
 * un aviso al teléfono de nadie.
 */
export async function revisarTasa(env, { validar = false, ahora = new Date() } = {}) {
  const cuenta = cuentaDeServicio(env);
  const { tasa, fuente } = await consultarTasa();

  // El BCV no publica sábados, domingos ni feriados, pero el cron corre las 24
  // horas de los 7 días: sin esta puerta el resumen de la mañana salía cada
  // fin de semana repitiendo la tasa del viernes, y dos avisos inútiles por
  // semana enseñan a ignorar los avisos que sí importan.
  //
  // El día de la semana atrapa el fin de semana; `fechaActualizacion`, los
  // feriados, que caen en día hábil y tampoco traen tasa nueva.
  if (!validar && (!esDiaHabilVE(ahora) || !tasaEsDeHoy(fuente, ahora))) {
    return {
      tasa,
      fuente,
      avisos: [],
      topics: [],
      motivo: esDiaHabilVE(ahora)
        ? 'el BCV no publicó hoy (feriado)'
        : 'fin de semana: el BCV no publica',
    };
  }

  const estado = (await env.TASAS.get('estado', { type: 'json' })) ?? {
    ultima: null,
    historial: [],
  };

  const hoy = hoyEnVenezuela(ahora);
  const historial = [...estado.historial];
  const ultimoDelHistorial = historial[historial.length - 1];

  // Una entrada por día: el cron corre cada hora, pero el ritmo se mide en
  // días. Si ya hay entrada de hoy se actualiza en lugar de duplicar.
  if (ultimoDelHistorial?.fecha === hoy) {
    ultimoDelHistorial.tasa = tasa;
  } else {
    historial.push({ fecha: hoy, tasa });
  }
  while (historial.length > DIAS_HISTORIAL) historial.shift();

  // El resumen sale una vez al día, a la hora fijada.
  const esResumen =
    horaEnVenezuela(ahora) === HORA_RESUMEN && estado.ultimoResumen !== hoy;

  // La paralela solo hace falta para el resumen, asi que no se consulta en las
  // otras 23 pasadas del cron.
  const paralelo = esResumen ? await consultarParalelo() : null;

  const avisos = construirAvisos({
    anterior: estado.ultima,
    actual: tasa,
    historial,
    esResumen,
    paralelo,
  });

  const enviados = [];
  if (avisos.length) {
    const token = await obtenerToken(cuenta, env.TASAS);
    for (const aviso of avisos) {
      for (const topic of aviso.topics) {
        await enviarATopic({
          cuenta,
          token,
          topic,
          titulo: aviso.titulo,
          cuerpo: aviso.cuerpo,
          datos: aviso.datos,
          validar,
        });
        enviados.push(topic);
      }
    }
  }

  // El estado solo se guarda si de verdad se envió lo que tocaba. Guardarlo
  // antes haría que un fallo de FCM se tragase el aviso para siempre: en la
  // siguiente ejecución la tasa ya sería "la anterior" y no habría cambio.
  if (!validar) {
    await env.TASAS.put(
      'estado',
      JSON.stringify({
        ultima: tasa,
        historial,
        ultimoResumen: esResumen ? hoy : estado.ultimoResumen,
        revisadoEn: ahora.toISOString(),
      }),
    );
  }

  return {
    tasa,
    anterior: estado.ultima,
    fuente,
    avisos: avisos.map((a) => a.titulo),
    topics: enviados,
    validar,
  };
}

export default {
  /** Disparo programado (ver el cron en wrangler.toml). */
  async scheduled(evento, env, ctx) {
    const ahora = new Date(evento.scheduledTime);
    ctx.waitUntil(
      revisarTasa(env, { ahora }).then(
        (r) => console.log('revisión', JSON.stringify(r)),
        (e) => console.error('falló la revisión:', e.message),
      ),
    );
    ctx.waitUntil(
      revisarResumenVentas(env, { ahora }).then(
        (r) => console.log('resumen de ventas', JSON.stringify(r)),
        (e) => console.error('falló el resumen de ventas:', e.message),
      ),
    );
    ctx.waitUntil(
      revisarStockBajo(env).then(
        (r) => console.log('stock bajo', JSON.stringify(r)),
        (e) => console.error('falló el stock bajo:', e.message),
      ),
    );
  },

  async fetch(peticion, env) {
    const url = new URL(peticion.url);

    if (url.pathname === '/revisar') return manejarRevisar(peticion, env, url);

    if (url.pathname === '/descargar') {
      return new Response(paginaDescargar(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }

    // Política de privacidad y términos de uso: públicos, sin autenticación
    // — Play Store exige que la política sea accesible por cualquiera antes
    // de dejar publicar la app.
    if (url.pathname === '/legal/privacidad') {
      return new Response(paginaPrivacidad(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }
    if (url.pathname === '/legal/terminos') {
      return new Response(paginaTerminos(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }
    if (url.pathname === '/legal/eliminar-cuenta') {
      return new Response(paginaEliminarCuenta(), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' },
      });
    }

    // Lecturas con Gemini. Comparten autenticación, límite diario y
    // validación de imagen; solo cambia el prompt (ver gemini.js).
    const lectores = {
      '/leer-etiqueta': (args) => leerEtiqueta(args),
      '/leer-fiados': (args) => leerFiados(args),
      '/leer-libreta': (args) => leerLibreta(args),
      '/leer-recibo': (args) => leerRecibo(args),
    };
    if (lectores[url.pathname] && peticion.method === 'POST') {
      return manejarLecturaIA(peticion, env, lectores[url.pathname]);
    }

    if (url.pathname === '/subir-foto' && peticion.method === 'POST') {
      return manejarSubirFoto(peticion, env);
    }

    return new Response('Worker de Cuenta Clara\n', { status: 200 });
  },
};

/**
 * Endpoint manual de los avisos de tasa, para probar sin esperar al cron.
 *
 * Pide un token compartido porque, si no, cualquiera que dé con la URL
 * podría dispararte notificaciones a todos los dispositivos.
 */
async function manejarRevisar(peticion, env, url) {
  const enviado = peticion.headers.get('x-token') ?? url.searchParams.get('token');
  if (!env.TOKEN_MANUAL || enviado !== env.TOKEN_MANUAL) {
    return new Response('No autorizado\n', { status: 401 });
  }

  try {
    // `probar=1` manda un push de prueba real a `tasa-resumen` sin importar
    // si la tasa cambió — para confirmar que la entrega de punta a punta
    // (Worker → FCM → teléfono) funciona, sin esperar a que se mueva el
    // dólar de verdad.
    if (url.searchParams.get('probar') === '1') {
      const cuenta = cuentaDeServicio(env);
      const token = await obtenerToken(cuenta, env.TASAS);
      const resultado = await enviarATopic({
        cuenta,
        token,
        topic: 'tasa-resumen',
        titulo: '🧪 Prueba de Cuenta Clara',
        cuerpo: 'Si ves esto, las notificaciones están funcionando.',
        datos: { tipo: 'prueba' },
      });
      return Response.json({ prueba: true, topic: 'tasa-resumen', resultado });
    }

    // `probarVentas=1` corre el resumen de ventas ahora mismo, sin importar
    // la hora ni si ya se mandó hoy — para probar la entrega real sin
    // esperar a las 9pm.
    if (url.searchParams.get('probarVentas') === '1') {
      const resultado = await revisarResumenVentas(env, { forzar: true });
      return Response.json(resultado);
    }

    // `probarStock=1` avisa de todos los productos bajos actuales sin importar
    // el dedup — para probar la entrega sin tener que agotar algo a propósito.
    if (url.searchParams.get('probarStock') === '1') {
      const resultado = await revisarStockBajo(env, { forzar: true });
      return Response.json(resultado);
    }

    const resultado = await revisarTasa(env, {
      validar: url.searchParams.get('validar') === '1',
    });
    return Response.json(resultado);
  } catch (e) {
    return new Response(`Error: ${e.message}\n`, { status: 500 });
  }
}

/**
 * Camino común de las lecturas con Gemini (etiqueta, libreta, recibo).
 *
 * Protegido por sesión de Firebase (ver auth.js), no por un token fijo: estos
 * endpoints los llama la app en el día a día, así que un secreto compartido
 * tendría el mismo problema que se quiso evitar con la clave de Gemini —
 * solo que embebido en el propio APK en vez de en el Worker.
 */
async function manejarLecturaIA(peticion, env, lector) {
  const uid = await usuarioAutenticado(peticion, env.FIREBASE_WEB_API_KEY);
  if (!uid) {
    return new Response('No autorizado\n', { status: 401 });
  }
  if (!env.GEMINI_API_KEY) {
    return new Response('Falta configurar GEMINI_API_KEY\n', { status: 500 });
  }

  // Se lee la cuota (sin gastarla todavía) antes de tocar el resto de la
  // petición: si esto falla, es un problema de KV, no del dueño, así que
  // responde limpio en vez de dejar reventar una excepción sin capturar.
  let clave, usados;
  try {
    ({ clave, usados } = await usosDeHoy(env, uid));
  } catch {
    return new Response(
      'No se pudo verificar el límite diario, intenta de nuevo.\n',
      { status: 500 },
    );
  }
  if (usados >= MAX_USOS_IA_POR_DIA) {
    return new Response(
      'Límite diario de lecturas con IA alcanzado. Vuelve mañana.\n',
      { status: 429 },
    );
  }

  let cuerpo;
  try {
    cuerpo = await peticion.json();
  } catch {
    return new Response('Cuerpo inválido: se esperaba JSON\n', { status: 400 });
  }

  const { imagenBase64, mimeType, categorias, rubro } = cuerpo;
  if (!imagenBase64 || !mimeType) {
    return new Response('Faltan imagenBase64 o mimeType\n', { status: 400 });
  }
  // Cada 4 caracteres base64 son 3 bytes; suficiente para descartar fotos
  // gigantes sin decodificar la imagen entera primero.
  if (imagenBase64.length * 0.75 > MAX_BYTES_IMAGEN) {
    return new Response('La imagen es demasiado grande\n', { status: 413 });
  }

  try {
    const resultado = await lector({
      apiKey: env.GEMINI_API_KEY,
      modelo: env.GEMINI_MODELO,
      imagenBase64,
      mimeType,
      categorias: Array.isArray(categorias)
        ? categorias.filter((c) => typeof c === 'string').slice(0, 30)
        : [],
      // El rubro solo sirve para elegir un matiz ya escrito (ver
      // `MATICES_POR_RUBRO`); nunca se concatena al prompt tal cual.
      rubro: typeof rubro === 'string' ? rubro : '',
    });
    // La cuota solo se gasta cuando la lectura de verdad llegó a Gemini y
    // volvió con algo usable: un cuerpo mal formado, una foto gigante o un
    // error de Gemini/red no deben costarle al dueño uno de sus 40 cupos.
    await registrarUso(env, clave, usados);
    return Response.json(resultado);
  } catch (e) {
    return new Response(`Error: ${e.message}\n`, { status: 500 });
  }
}

/**
 * Lee cuántas lecturas con IA ha gastado hoy este usuario.
 *
 * KV es de consistencia eventual y el get+put de aquí no es atómico, así que
 * dos peticiones casi simultáneas del mismo uid (doble toque, dos
 * dispositivos con la misma cuenta) podrían colarse un par de lecturas de
 * más antes de que el conteo se ponga al día. Como tope de cortesía contra
 * abusos —no una cuota exacta ni de seguridad— ese margen es aceptable.
 */
/**
 * Sube la foto de un producto o de un recibo a Cloudinary.
 *
 * Protegido por sesión de Firebase, igual que las lecturas con IA — ver el
 * comentario en cloudinary.js sobre por qué ya no se sube directo desde la
 * app con un preset sin firma.
 */
async function manejarSubirFoto(peticion, env) {
  const uid = await usuarioAutenticado(peticion, env.FIREBASE_WEB_API_KEY);
  if (!uid) {
    return new Response('No autorizado\n', { status: 401 });
  }
  if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
    return new Response('Falta configurar Cloudinary\n', { status: 500 });
  }

  let cuerpo;
  try {
    cuerpo = await peticion.json();
  } catch {
    return new Response('Cuerpo inválido: se esperaba JSON\n', { status: 400 });
  }

  const { imagenBase64, mimeType, carpeta } = cuerpo;
  if (!imagenBase64 || !mimeType) {
    return new Response('Faltan imagenBase64 o mimeType\n', { status: 400 });
  }
  if (imagenBase64.length * 0.75 > MAX_BYTES_IMAGEN) {
    return new Response('La imagen es demasiado grande\n', { status: 413 });
  }
  if (!carpetaValida(carpeta)) {
    return new Response('Carpeta inválida\n', { status: 400 });
  }

  try {
    const url = await subirFotoFirmada({
      cloudName: env.CLOUDINARY_CLOUD_NAME,
      apiKey: env.CLOUDINARY_API_KEY,
      apiSecret: env.CLOUDINARY_API_SECRET,
      imagenBase64,
      mimeType,
      carpeta,
    });
    return Response.json({ url });
  } catch (e) {
    return new Response(`Error: ${e.message}\n`, { status: 500 });
  }
}

async function usosDeHoy(env, uid) {
  const hoy = hoyEnVenezuela();
  const clave = `ia:${uid}:${hoy}`;
  const usados = Number((await env.TASAS.get(clave)) ?? 0);
  return { clave, usados };
}

async function registrarUso(env, clave, usadosAntes) {
  try {
    // 2 días de TTL: la clave de ayer muere sola, sin tarea de limpieza.
    await env.TASAS.put(clave, String(usadosAntes + 1), {
      expirationTtl: 2 * 86400,
    });
  } catch {
    // Si KV falla al escribir el contador no se bloquea la respuesta: el
    // dueño ya recibió su lectura, solo no quedó contabilizada (cupo de
    // cortesía, no un candado de seguridad).
  }
}
