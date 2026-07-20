/**
 * Lectura de etiquetas de producto con Gemini.
 *
 * Solo se ocupa del NOMBRE (con marca y presentación/peso, ej. "Harina PAN
 * 1kg"): el código de barras ya lo lee `mobile_scanner` sin IA y con más
 * precisión — un modelo de visión no le gana a un lector de barras real.
 */

const MODELO_POR_DEFECTO = 'gemini-2.5-flash';

const PROMPT = `Estás viendo la foto de un producto para el inventario de una
tienda pequeña en Venezuela. Identifica el producto y sugiere un nombre corto
y claro para el inventario, con marca y presentación si son visibles (peso,
volumen o unidades) — el mismo estilo que usaría el dueño de la tienda al
anotarlo a mano. Ejemplos del estilo esperado: "Harina PAN 1kg",
"Detergente Ariel 1kg", "Refresco Cola 2L", "Jabón de baño".

Si la foto no muestra un producto identificable (persona, paisaje, foto
borrosa, etc.), indica esProducto=false y deja nombreSugerido vacío.`;

const ESQUEMA_RESPUESTA = {
  type: 'OBJECT',
  properties: {
    esProducto: { type: 'BOOLEAN' },
    nombreSugerido: { type: 'STRING' },
    confianza: { type: 'STRING', enum: ['alta', 'media', 'baja'] },
  },
  required: ['esProducto', 'nombreSugerido', 'confianza'],
};

/**
 * Interpreta la respuesta cruda de Gemini y la reduce a lo que la app
 * necesita. Separada de la llamada de red para poder probarla con
 * respuestas de ejemplo, sin pegarle a la API de verdad.
 */
export function interpretarRespuestaGemini(json) {
  const texto = json?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!texto) {
    throw new Error('Gemini no devolvió contenido interpretable.');
  }

  let datos;
  try {
    datos = JSON.parse(texto);
  } catch {
    throw new Error('La respuesta de Gemini no fue JSON válido.');
  }

  if (!datos.esProducto || !datos.nombreSugerido?.trim()) {
    return { reconocido: false };
  }

  return {
    reconocido: true,
    nombreSugerido: datos.nombreSugerido.trim(),
    confianza: ['alta', 'media', 'baja'].includes(datos.confianza)
      ? datos.confianza
      : 'media',
  };
}

/**
 * Envía la foto a Gemini y devuelve la interpretación ya lista para la app.
 *
 * @param {string} imagenBase64 Foto en base64, sin el prefijo `data:...`.
 * @param {string} mimeType Ej. `image/jpeg`.
 */
export async function leerEtiqueta({ apiKey, modelo, imagenBase64, mimeType }) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${modelo || MODELO_POR_DEFECTO}:generateContent?key=${apiKey}`;

  const resp = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: PROMPT },
            { inline_data: { mime_type: mimeType, data: imagenBase64 } },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: ESQUEMA_RESPUESTA,
      },
    }),
  });

  if (!resp.ok) {
    throw new Error(`Gemini respondió ${resp.status}: ${await resp.text()}`);
  }

  return interpretarRespuestaGemini(await resp.json());
}
