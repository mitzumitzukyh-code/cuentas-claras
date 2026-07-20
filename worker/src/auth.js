/**
 * Verifica que quien llama al Worker sea un usuario real de la app.
 *
 * El endpoint de lectura de etiquetas consume cuota de Gemini en cada
 * llamada, así que no puede quedar abierto: cualquiera con la URL podría
 * agotarla. La app ya autentica con Firebase, así que reutiliza eso en vez
 * de inventar un secreto nuevo que también habría que proteger.
 *
 * Se verifica delegando en la API de Identity Toolkit de Google en vez de
 * validar el JWT a mano (JWKS, rotación de claves, RS256...): es una llamada
 * HTTP más por petición, pero es Google quien certifica que el token es
 * válido — más simple y sin superficie propia que mantener.
 *
 * La `apiKey` que recibe NO es secreta: es la misma que ya va en
 * `firebase_options.dart`, publicada en el propio APK. Identifica el
 * proyecto, no autoriza nada por sí sola.
 */
export async function usuarioAutenticado(peticion, apiKeyFirebase) {
  const cabecera = peticion.headers.get('authorization') || '';
  const idToken = cabecera.startsWith('Bearer ') ? cabecera.slice(7) : null;
  if (!idToken) return false;

  const resp = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${apiKeyFirebase}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ idToken }),
    },
  );
  if (!resp.ok) return false;

  const datos = await resp.json();
  return Array.isArray(datos.users) && datos.users.length > 0;
}
