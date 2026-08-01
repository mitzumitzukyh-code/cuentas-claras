/**
 * Envío de push por la API HTTP v1 de FCM.
 *
 * Los Workers no corren Node, así que no hay `googleapis` ni `jsonwebtoken`:
 * el JWT se firma a mano con Web Crypto, que es lo único disponible. A cambio
 * no hay dependencias que mantener ni actualizar.
 */

// Un mismo token OAuth sirve para varios alcances a la vez (JWT con scope
// separado por espacios) — así el resumen de ventas puede leer Firestore con
// el mismo token que ya se pedía para mandar los avisos de tasa, sin abrir
// un segundo flujo de autenticación.
const ALCANCE =
  'https://www.googleapis.com/auth/firebase.messaging ' +
  'https://www.googleapis.com/auth/datastore';

/** base64url sin relleno, que es lo que exige JWT. */
function base64url(datos) {
  const bytes =
    typeof datos === 'string' ? new TextEncoder().encode(datos) : datos;
  let bin = '';
  for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Pasa la clave PEM de la cuenta de servicio a algo que Web Crypto entienda. */
async function importarClave(pem) {
  const cuerpo = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binario = Uint8Array.from(atob(cuerpo), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    binario,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/**
 * Token OAuth para enviar push.
 *
 * Se cachea en KV porque dura una hora y el cron corre cada hora: pedir uno
 * nuevo en cada ejecución es una llamada de red extra por nada. Se guarda con
 * cinco minutos de margen para no usar uno que caduque a mitad del envío.
 */
export async function obtenerToken(cuenta, kv) {
  const cacheado = await kv?.get('oauth_token', { type: 'json' });
  if (cacheado && cacheado.expira > Date.now() + 5 * 60 * 1000) {
    return cacheado.token;
  }

  const ahora = Math.floor(Date.now() / 1000);
  const cabecera = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const cuerpo = base64url(
    JSON.stringify({
      iss: cuenta.client_email,
      scope: ALCANCE,
      aud: cuenta.token_uri,
      iat: ahora,
      exp: ahora + 3600,
    }),
  );

  const clave = await importarClave(cuenta.private_key);
  const firma = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    clave,
    new TextEncoder().encode(`${cabecera}.${cuerpo}`),
  );
  const jwt = `${cabecera}.${cuerpo}.${base64url(firma)}`;

  const resp = await fetch(cuenta.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!resp.ok) {
    throw new Error(`OAuth ${resp.status}: ${await resp.text()}`);
  }

  const datos = await resp.json();
  await kv?.put(
    'oauth_token',
    JSON.stringify({
      token: datos.access_token,
      expira: Date.now() + datos.expires_in * 1000,
    }),
    { expirationTtl: datos.expires_in },
  );
  return datos.access_token;
}

/**
 * Publica una notificación en un topic.
 *
 * `validar` usa el modo `validate_only` de FCM: comprueba el mensaje entero
 * contra el servidor sin entregarlo a ningún teléfono. Es lo que permite
 * probar el Worker en serio sin llenar de avisos falsos el móvil.
 */
export async function enviarATopic({
  cuenta,
  token,
  topic,
  titulo,
  cuerpo,
  datos = {},
  validar = false,
}) {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        validate_only: validar,
        message: {
          topic,
          notification: { title: titulo, body: cuerpo },
          data: datos,
          android: {
            priority: 'high',
            notification: {
              // Coinciden con el manifest de la app: sin el canal, Android 8+
              // descarta la notificación en silencio.
              channel_id: 'tasa_bcv',
              icon: 'ic_notificacion',
              color: '#0F9D82',
            },
          },
        },
      }),
    },
  );

  if (!resp.ok) {
    throw new Error(`FCM ${resp.status} en '${topic}': ${await resp.text()}`);
  }
  return resp.json();
}

/**
 * Publica una notificación directo a un dispositivo (por su token), no a un
 * topic — es lo que necesita el resumen de ventas: cada dueño ve solo lo
 * suyo, así que no puede ir por un canal compartido.
 */
export async function enviarAToken({
  cuenta,
  token,
  destino,
  titulo,
  cuerpo,
  datos = {},
  canal = 'tasa_bcv',
  etiqueta,
}) {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: destino,
          notification: { title: titulo, body: cuerpo },
          data: datos,
          android: {
            priority: 'high',
            notification: {
              // Debe coincidir con un canal que la app ya haya declarado
              // (ver `canalTasa`/`canalVentas` en push_service.dart) — Android
              // 8+ descarta en silencio cualquier aviso de un canal que no
              // existe todavía en el dispositivo.
              channel_id: canal,
              icon: 'ic_notificacion',
              color: '#0F9D82',
              // `tag` es el equivalente del id de notificación en Android:
              // dos avisos con la misma etiqueta se reemplazan en vez de
              // apilarse. Sin ella, cada reintento de FCM deja otra copia.
              ...(etiqueta ? { tag: etiqueta } : {}),
            },
          },
        },
      }),
    },
  );

  if (!resp.ok) {
    throw new Error(`FCM ${resp.status} a token: ${await resp.text()}`);
  }
  return resp.json();
}
