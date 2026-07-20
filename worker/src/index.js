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
import { enviarATopic, obtenerToken } from './fcm.js';
import { leerEtiqueta, leerLibreta, leerRecibo } from './gemini.js';
import { DIAS_HISTORIAL, construirAvisos } from './tasa.js';

/** Una foto de celular comprimida no debería pasar de esto. Corta abusos. */
const MAX_BYTES_IMAGEN = 6 * 1024 * 1024;

/**
 * Usos de IA por usuario y por día. Corta un bucle descontrolado o un abuso
 * sin estorbar el uso real (nadie fotografía 40 etiquetas al día a mano);
 * cuando exista el plan Premium, este número puede depender del plan.
 */
const MAX_USOS_IA_POR_DIA = 40;

const API_TASA = 'https://ve.dolarapi.com/v1/dolares/oficial';

/** Hora local de Venezuela (UTC−4) a la que sale el resumen de la mañana. */
const HORA_RESUMEN = 8;

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

/** Fecha en Venezuela (UTC−4) como YYYY-MM-DD. */
function hoyEnVenezuela(ahora = new Date()) {
  const ve = new Date(ahora.getTime() - 4 * 60 * 60 * 1000);
  return ve.toISOString().slice(0, 10);
}

function horaEnVenezuela(ahora = new Date()) {
  return new Date(ahora.getTime() - 4 * 60 * 60 * 1000).getUTCHours();
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

  const avisos = construirAvisos({
    anterior: estado.ultima,
    actual: tasa,
    historial,
    esResumen,
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
    ctx.waitUntil(
      revisarTasa(env, { ahora: new Date(evento.scheduledTime) }).then(
        (r) => console.log('revisión', JSON.stringify(r)),
        (e) => console.error('falló la revisión:', e.message),
      ),
    );
  },

  async fetch(peticion, env) {
    const url = new URL(peticion.url);

    if (url.pathname === '/revisar') return manejarRevisar(peticion, env, url);

    // Lecturas con Gemini. Comparten autenticación, límite diario y
    // validación de imagen; solo cambia el prompt (ver gemini.js).
    const lectores = {
      '/leer-etiqueta': (args) => leerEtiqueta(args),
      '/leer-libreta': (args) => leerLibreta(args),
      '/leer-recibo': (args) => leerRecibo(args),
    };
    if (lectores[url.pathname] && peticion.method === 'POST') {
      return manejarLecturaIA(peticion, env, lectores[url.pathname]);
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

  if (!(await bajoElLimiteDiario(env, uid))) {
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

  const { imagenBase64, mimeType, categorias } = cuerpo;
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
    });
    return Response.json(resultado);
  } catch (e) {
    return new Response(`Error: ${e.message}\n`, { status: 500 });
  }
}

/**
 * Cuenta el uso de hoy en KV y dice si todavía queda cuota.
 *
 * KV es de consistencia eventual, así que el conteo puede quedarse corto en
 * ráfagas — para un tope de cortesía contra abusos es más que suficiente, no
 * hace falta un contador exacto.
 */
async function bajoElLimiteDiario(env, uid) {
  const hoy = hoyEnVenezuela();
  const clave = `ia:${uid}:${hoy}`;
  const usados = Number((await env.TASAS.get(clave)) ?? 0);
  if (usados >= MAX_USOS_IA_POR_DIA) return false;

  // 2 días de TTL: la clave de ayer muere sola, sin tarea de limpieza.
  await env.TASAS.put(clave, String(usados + 1), { expirationTtl: 2 * 86400 });
  return true;
}
