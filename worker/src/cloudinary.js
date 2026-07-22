/**
 * Subida de fotos a Cloudinary para Cuenta Clara.
 *
 * Antes la app subía directo a Cloudinary con un preset "sin firma"
 * (`unsigned`): cualquiera que le sacara el nombre de cloud y el preset al
 * APK —trivial, son cadenas de texto planas— podía mandar fotos a esa cuenta
 * sin tener sesión en la app ni cuenta en Cuenta Clara siquiera. Ahora la
 * subida pasa por aquí: exige sesión de Firebase (ver `usuarioAutenticado` en
 * auth.js) y firma cada subida con la API Secret de Cloudinary, que nunca
 * sale del Worker.
 */

/** Solo estas carpetas existen hoy (ver ProductoRepository/GastoRepository/NegocioRepository). */
const CARPETA_VALIDA = /^cuenta-clara\/[A-Za-z0-9_-]{1,80}\/(productos|recibos|perfil)$/;

export function carpetaValida(carpeta) {
  return typeof carpeta === 'string' && CARPETA_VALIDA.test(carpeta);
}

/**
 * Firma de Cloudinary: SHA-1 de los parámetros (ordenados alfabéticamente,
 * sin URL-encodear) con la API Secret pegada al final. Así lo pide su API:
 * https://cloudinary.com/documentation/authentication_signatures
 */
async function firmar(params, apiSecret) {
  const cadena = Object.keys(params)
    .sort()
    .map((k) => `${k}=${params[k]}`)
    .join('&');
  const bytes = new TextEncoder().encode(cadena + apiSecret);
  const hash = await crypto.subtle.digest('SHA-1', bytes);
  return [...new Uint8Array(hash)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/** Sube la imagen y devuelve su URL https pública. */
export async function subirFotoFirmada({
  cloudName,
  apiKey,
  apiSecret,
  imagenBase64,
  mimeType,
  carpeta,
}) {
  const timestamp = Math.floor(Date.now() / 1000);
  const signature = await firmar({ folder: carpeta, timestamp }, apiSecret);

  const cuerpo = new URLSearchParams({
    file: `data:${mimeType};base64,${imagenBase64}`,
    api_key: apiKey,
    timestamp: String(timestamp),
    folder: carpeta,
    signature,
  });

  const resp = await fetch(
    `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: cuerpo.toString(),
    },
  );

  if (!resp.ok) {
    throw new Error(`Cloudinary respondió ${resp.status}: ${await resp.text()}`);
  }

  const json = await resp.json();
  if (!json.secure_url) {
    throw new Error('Cloudinary no devolvió la URL de la imagen.');
  }
  return json.secure_url;
}
