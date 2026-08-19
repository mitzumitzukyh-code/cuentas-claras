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
  esModeloOcupado,
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
import {
  avisosDeCorte,
  avisosDePrueba,
  cronogramaResuelto,
  enHoraVenezuela,
  estadosConCronograma,
} from './luz.js';
import { construirAvisoStock } from './stock.js';
import {
  DIAS_HISTORIAL,
  construirAviso,
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

/**
 * Horas a las que sale el aviso de tasa: apertura, mediodía y tarde.
 *
 * El dólar se avisa en franjas fijas y nada más (ver tasa.js): un aviso por
 * cada una de estas tres horas, y el resumen de ventas a las 9 pm cierra el
 * día. En cualquier otra hora el cron solo actualiza el historial en silencio.
 */
const HORAS_TASA = [8, 12, 15];

/** Nombre del momento del día para cada hora de aviso. */
const MOMENTO_POR_HORA = { 8: 'manana', 12: 'mediodia', 15: 'tarde' };

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
/**
 * Avisos de corte de luz.
 *
 * Se manda desde el Worker y no con alarmas en el teléfono porque las alarmas
 * locales no sobrevivieron en el dispositivo de pruebas: la ROM las registra
 * —se ven en `dumpsys alarm`— y luego no las dispara. Es la forma más cara de
 * fallar, porque el código parece correcto. Este es el mismo camino que ya
 * funciona todos los días para la tasa del dólar.
 *
 * **Solo lo recibe quien lo pidió.** Va por topic (`luz-barinas-a`), y a ese
 * topic solo se suscribe la app que tiene el interruptor puesto y ese bloque
 * elegido. Al que no lo activó no le llega nada, porque no está suscrito.
 *
 * `forzar` manda el corte de hoy de cada bloque sin esperar a la hora, para
 * probar la entrega de punta a punta.
 */
async function revisarCortesLuz(env, { ahora = new Date(), forzar = false } = {}) {
  const avisos = forzar
    ? avisosDePrueba(ahora)
    : avisosDeCorte(ahora, { estado: 'barinas' });
  if (!avisos.length) return { enviados: 0 };

  const cuenta = cuentaDeServicio(env);
  const token = await obtenerToken(cuenta, env.TASAS);
  const { fecha, hora, minuto } = enHoraVenezuela(ahora);

  const enviados = [];
  for (const aviso of avisos) {
    // Dedup por topic y minuto: Cloudflare puede reintentar una pasada del
    // cron, y el mismo aviso no debe salir dos veces.
    const clave = `luzAvisado:${aviso.topic}:${fecha}:${hora}:${minuto}`;
    if (!forzar && (await env.TASAS.get(clave))) continue;

    await enviarATopic({
      cuenta,
      token,
      topic: aviso.topic,
      titulo: aviso.titulo,
      cuerpo: aviso.cuerpo,
      datos: aviso.datos,
      canal: 'cortes_luz',
    });

    // Dos días de vida: cubre un reintento tardío sin dejar basura en KV.
    if (!forzar) await env.TASAS.put(clave, '1', { expirationTtl: 172800 });
    enviados.push(aviso.topic);
  }

  return { enviados: enviados.length, topics: enviados };
}

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

  // Solo se avisa en las tres franjas del día; el resto de pasadas del cron
  // solo mantiene el historial al día. Un mismo checkpoint no sale dos veces:
  // Cloudflare puede reintentar una pasada del cron, y el segundo envío sería
  // un duplicado exacto.
  const hora = horaEnVenezuela(ahora);
  const momento = MOMENTO_POR_HORA[hora] ?? null;
  const ultimoCheckpoint = estado.ultimoCheckpoint ?? null;
  const yaSalioEsteCheckpoint =
    momento != null &&
    ultimoCheckpoint?.fecha === hoy &&
    ultimoCheckpoint?.hora === hora;

  // La paralela solo hace falta en la mañana, asi que no se consulta en las
  // otras 23 pasadas del cron.
  const paralelo =
    momento === 'manana' && !yaSalioEsteCheckpoint
      ? await consultarParalelo()
      : null;

  const aviso =
    momento && !yaSalioEsteCheckpoint
      ? construirAviso({
          // `anteriorCheckpoint` es la tasa del aviso anterior del mismo día;
          // la de ayer no sirve para decir "desde la mañana".
          anteriorCheckpoint:
            ultimoCheckpoint?.fecha === hoy ? ultimoCheckpoint.tasa : null,
          anterior: estado.ultima,
          actual: tasa,
          historial,
          momento,
          paralelo,
        })
      : null;

  const enviados = [];
  if (aviso) {
    const token = await obtenerToken(cuenta, env.TASAS);
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

  // El estado solo se guarda si de verdad se envió lo que tocaba. Guardarlo
  // antes haría que un fallo de FCM se tragase el aviso para siempre: en la
  // siguiente ejecución la tasa ya sería "la anterior" y no habría cambio.
  if (!validar) {
    await env.TASAS.put(
      'estado',
      JSON.stringify({
        ultima: tasa,
        historial,
        // Solo se marca el checkpoint cuando salió; si el envío falló, el
        // siguiente momento del día podrá salir con su propio texto.
        ultimoCheckpoint: aviso
          ? { fecha: hoy, hora, tasa }
          : estado.ultimoCheckpoint,
        revisadoEn: ahora.toISOString(),
      }),
    );
  }

  return {
    tasa,
    anterior: estado.ultima,
    fuente,
    avisos: aviso ? [aviso.titulo] : [],
    momento,
    topics: enviados,
    validar,
  };
}

/**
 * Cabeceras de seguridad de las páginas públicas.
 *
 * Las tres páginas del Worker son HTML estático con un `<style>` dentro: no
 * cargan scripts, ni imágenes, ni tipografías, ni piden nada de fuera. La CSP
 * lo dice tal cual —`default-src 'none'`— para que si un día alguien mete una
 * etiqueta que traiga algo de otro dominio, el navegador la bloquee en vez de
 * ejecutarla.
 *
 * `style-src 'unsafe-inline'` es lo único que se abre, y solo porque el CSS va
 * incrustado en la propia página. Nada de esto interpola datos del usuario
 * hoy; estas cabeceras son la red por si eso cambia.
 */
const CABECERAS_SEGURIDAD = {
  'Content-Security-Policy':
    "default-src 'none'; style-src 'unsafe-inline'; img-src data:; " +
    "base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  // Sin esto, un navegador puede "adivinar" que un texto es HTML y ejecutarlo.
  'X-Content-Type-Options': 'nosniff',
  // Para navegadores viejos que no entienden `frame-ancestors`.
  'X-Frame-Options': 'DENY',
  // La URL de la política de privacidad no tiene por qué viajar a terceros.
  'Referrer-Policy': 'no-referrer',
  // El Worker solo se sirve por https; esto impide siquiera el primer intento
  // en claro durante un año.
  'Strict-Transport-Security': 'max-age=31536000',
};

/** Una página HTML con sus cabeceras de seguridad puestas. */
function paginaHtml(html) {
  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      ...CABECERAS_SEGURIDAD,
    },
  });
}

export default {
  /** Disparo programado (ver el cron en wrangler.toml). */
  async scheduled(evento, env, ctx) {
    const ahora = new Date(evento.scheduledTime);

    // El cron pasó a correr cada media hora por los avisos de corte de luz,
    // que tienen que caer a y media —el aviso sale 30 minutos antes y las
    // franjas empiezan en hora en punto—. Lo demás sigue siendo horario:
    // correrlo el doble de veces no lo mejora y sí duplica las consultas al
    // BCV y a Firestore.
    if (ahora.getUTCMinutes() === 0) {
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
    }

    ctx.waitUntil(
      revisarCortesLuz(env, { ahora }).then(
        (r) => console.log('cortes de luz', JSON.stringify(r)),
        (e) => console.error('falló el aviso de luz:', e.message),
      ),
    );
  },

  async fetch(peticion, env) {
    const url = new URL(peticion.url);

    if (url.pathname === '/revisar') return manejarRevisar(peticion, env, url);

    if (url.pathname === '/descargar') return paginaHtml(paginaDescargar());

    // Política de privacidad y términos de uso: públicos, sin autenticación
    // — Play Store exige que la política sea accesible por cualquiera antes
    // de dejar publicar la app.
    if (url.pathname === '/legal/privacidad') {
      return paginaHtml(paginaPrivacidad());
    }
    if (url.pathname === '/legal/terminos') return paginaHtml(paginaTerminos());
    if (url.pathname === '/legal/eliminar-cuenta') {
      return paginaHtml(paginaEliminarCuenta());
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

    // Cronograma de cortes de luz. Público y sin sesión: es información que
    // Corpoelec publica en la calle, no lleva ni un dato del negocio, y la
    // app tiene que poder leerlo aunque no haya sesión abierta todavía.
    if (url.pathname === '/cronograma-luz') {
      const estado = url.searchParams.get('estado') ?? 'barinas';
      const cronograma = cronogramaResuelto(estado);
      if (!cronograma) {
        return Response.json(
          { error: 'sin cronograma', estados: estadosConCronograma() },
          { status: 404 },
        );
      }
      return Response.json(cronograma, {
        headers: {
          'Cache-Control': 'public, max-age=86400',
          'X-Content-Type-Options': 'nosniff',
        },
      });
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
    // `probarLuz=1` manda el corte de hoy a los cuatro topics de bloque sin
    // esperar a la hora, para probar la entrega de verdad.
    if (url.searchParams.get('probarLuz') === '1') {
      const resultado = await revisarCortesLuz(env, { forzar: true });
      return Response.json(resultado);
    }

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
    // El modelo saturado no es un fallo de la app ni de la foto: se
    // distingue con un 503 para que la app pueda decir «está ocupado,
    // intenta en un minuto» en vez de «revisa tu internet», que es lo que
    // se vio en dispositivo con una factura densa.
    if (esModeloOcupado(e)) {
      console.warn('Gemini saturado:', e.message);
      return new Response('El lector está ocupado ahora mismo\n', {
        status: 503,
      });
    }
    // El detalle va al log y no al cliente: `e.message` puede traer la
    // respuesta cruda de Gemini.
    console.error('lectura con IA falló:', e.message);
    return new Response('No se pudo leer la foto\n', { status: 500 });
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
