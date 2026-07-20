/**
 * Lecturas con Gemini para Cuenta Clara.
 *
 * Tres usos, todos con la misma regla: la IA SUGIERE y el dueño confirma en
 * la app antes de guardar nada.
 *
 *  - Etiqueta de producto: nombre + categoría + presentación.
 *  - Libreta manuscrita: filas producto/precio/cantidad para el importador.
 *  - Recibo de compra: monto, fecha y categoría del gasto.
 *
 * El código de barras NO pasa por aquí: `mobile_scanner` lo lee sin IA y con
 * más precisión — un modelo de visión no le gana a un lector de barras real.
 */

const MODELO_POR_DEFECTO = 'gemini-2.5-flash';

// ---------------------------------------------------------------------------
// Etiqueta de producto
// ---------------------------------------------------------------------------

const PROMPT_ETIQUETA = `Estás viendo la foto de un producto para el
inventario de una tienda pequeña en Venezuela. Identifica el producto y
sugiere:

- nombreSugerido: nombre corto y claro para el inventario, con marca y
  presentación si son visibles (peso, volumen o unidades) — el estilo que
  usaría el dueño al anotarlo a mano. Ejemplos: "Harina PAN 1kg",
  "Detergente Ariel 1kg", "Refresco Cola 2L", "Jabón de baño".
- presentacion: SOLO la presentación si es visible ("1kg", "2L", "12 uds"),
  o vacío si no se distingue.
- categoriaSugerida: la categoría del producto. Si se te da una lista de
  categorías de la tienda, elige EXACTAMENTE una de esa lista (tal cual está
  escrita) o deja vacío si ninguna encaja; sin lista, deja vacío.

Si la foto no muestra un producto identificable (persona, paisaje, foto
borrosa, etc.), indica esProducto=false y deja el resto vacío.`;

const ESQUEMA_ETIQUETA = {
  type: 'OBJECT',
  properties: {
    esProducto: { type: 'BOOLEAN' },
    nombreSugerido: { type: 'STRING' },
    presentacion: { type: 'STRING' },
    categoriaSugerida: { type: 'STRING' },
    confianza: { type: 'STRING', enum: ['alta', 'media', 'baja'] },
  },
  required: ['esProducto', 'nombreSugerido', 'confianza'],
};

/**
 * Interpreta la respuesta cruda de Gemini y la reduce a lo que la app
 * necesita. Separada de la llamada de red para poder probarla con
 * respuestas de ejemplo, sin pegarle a la API de verdad.
 *
 * `categorias` es la lista de la tienda: una sugerencia fuera de la lista se
 * descarta aquí para que la app nunca reciba una categoría inventada.
 */
export function interpretarRespuestaGemini(json, categorias = []) {
  const datos = extraerJson(json);

  if (!datos.esProducto || !datos.nombreSugerido?.trim()) {
    return { reconocido: false };
  }

  const categoria = datos.categoriaSugerida?.trim() ?? '';
  const categoriaValida = categorias.find(
    (c) => c.toLowerCase() === categoria.toLowerCase(),
  );

  return {
    reconocido: true,
    nombreSugerido: datos.nombreSugerido.trim(),
    presentacion: datos.presentacion?.trim() || null,
    categoriaSugerida: categoriaValida ?? null,
    confianza: ['alta', 'media', 'baja'].includes(datos.confianza)
      ? datos.confianza
      : 'media',
  };
}

/**
 * Envía la foto de una etiqueta a Gemini.
 *
 * @param {string} imagenBase64 Foto en base64, sin el prefijo `data:...`.
 * @param {string} mimeType Ej. `image/jpeg`.
 * @param {string[]} categorias Categorías de la tienda, para que la
 *   sugerencia sea una de ellas y no una inventada.
 */
export async function leerEtiqueta({
  apiKey,
  modelo,
  imagenBase64,
  mimeType,
  categorias = [],
}) {
  const prompt = categorias.length
    ? `${PROMPT_ETIQUETA}\n\nCategorías de la tienda: ${categorias.join(', ')}`
    : PROMPT_ETIQUETA;

  const json = await llamarGemini({
    apiKey,
    modelo,
    prompt,
    esquema: ESQUEMA_ETIQUETA,
    imagenBase64,
    mimeType,
  });
  return interpretarRespuestaGemini(json, categorias);
}

// ---------------------------------------------------------------------------
// Libreta manuscrita
// ---------------------------------------------------------------------------

const PROMPT_LIBRETA = `Estás viendo la foto de una libreta o cuaderno donde
el dueño de una tienda pequeña en Venezuela anota su inventario a mano. Cada
renglón suele tener un producto con su precio (normalmente en dólares) y/o su
cantidad en existencia, en cualquier orden y con abreviaturas.

Transcribe cada renglón legible como una fila con:
- nombre: el nombre del producto tal como está escrito (limpio, sin números
  de precio o cantidad pegados).
- precio: el precio unitario en dólares si está anotado, o null.
- cantidad: las unidades en existencia si están anotadas, o null.

No inventes datos que no estén escritos. Ignora renglones tachados o
ilegibles. Si la foto no muestra una lista de productos, indica
esLista=false.`;

const ESQUEMA_LIBRETA = {
  type: 'OBJECT',
  properties: {
    esLista: { type: 'BOOLEAN' },
    filas: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          nombre: { type: 'STRING' },
          precio: { type: 'NUMBER', nullable: true },
          cantidad: { type: 'NUMBER', nullable: true },
        },
        required: ['nombre'],
      },
    },
  },
  required: ['esLista', 'filas'],
};

/** Reduce la respuesta de la libreta a filas limpias y utilizables. */
export function interpretarRespuestaLibreta(json) {
  const datos = extraerJson(json);
  if (!datos.esLista || !Array.isArray(datos.filas)) {
    return { reconocido: false, filas: [] };
  }

  const filas = datos.filas
    .filter((f) => typeof f?.nombre === 'string' && f.nombre.trim())
    .map((f) => ({
      nombre: f.nombre.trim(),
      precio: numeroPositivo(f.precio),
      cantidad: numeroPositivo(f.cantidad),
    }));

  return { reconocido: filas.length > 0, filas };
}

/** Lee la foto de una libreta de inventario y devuelve sus filas. */
export async function leerLibreta({ apiKey, modelo, imagenBase64, mimeType }) {
  const json = await llamarGemini({
    apiKey,
    modelo,
    prompt: PROMPT_LIBRETA,
    esquema: ESQUEMA_LIBRETA,
    imagenBase64,
    mimeType,
  });
  return interpretarRespuestaLibreta(json);
}

// ---------------------------------------------------------------------------
// Recibo de compra (gastos)
// ---------------------------------------------------------------------------

const CATEGORIAS_GASTO = ['mercancia', 'transporte', 'servicios', 'otro'];

const PROMPT_RECIBO = `Estás viendo la foto de un recibo, factura o nota de
entrega de una compra hecha por una tienda pequeña en Venezuela. Extrae:

- monto: el TOTAL pagado. Si el recibo está en bolívares indica la moneda
  "VES"; si está en dólares, "USD".
- moneda: "USD" o "VES" según lo anterior.
- fecha: la fecha del recibo en formato YYYY-MM-DD, o vacío si no se ve.
- descripcion: qué se compró, en pocas palabras ("Mercancía distribuidora
  Polar", "Gasolina", "Recibo de luz").
- categoria: una de: mercancia (compra de productos para revender),
  transporte (flete, gasolina, encomienda), servicios (luz, agua, internet,
  teléfono, alquiler), otro.

No inventes datos que no estén en la imagen. Si no es un recibo o factura,
indica esRecibo=false.`;

const ESQUEMA_RECIBO = {
  type: 'OBJECT',
  properties: {
    esRecibo: { type: 'BOOLEAN' },
    monto: { type: 'NUMBER', nullable: true },
    // Sin enum: un enum con cadena vacía puede rechazarlo la API, y de todos
    // modos interpretarRespuestaRecibo normaliza a USD/VES.
    moneda: { type: 'STRING' },
    fecha: { type: 'STRING' },
    descripcion: { type: 'STRING' },
    categoria: { type: 'STRING' },
  },
  required: ['esRecibo'],
};

/** Reduce la respuesta del recibo a datos listos para prellenar el gasto. */
export function interpretarRespuestaRecibo(json) {
  const datos = extraerJson(json);
  if (!datos.esRecibo) return { reconocido: false };

  const fecha = /^\d{4}-\d{2}-\d{2}$/.test(datos.fecha ?? '')
    ? datos.fecha
    : null;

  return {
    reconocido: true,
    monto: numeroPositivo(datos.monto),
    moneda: datos.moneda === 'VES' ? 'VES' : 'USD',
    fecha,
    descripcion: datos.descripcion?.trim() || null,
    categoria: CATEGORIAS_GASTO.includes(datos.categoria)
      ? datos.categoria
      : null,
  };
}

/** Lee la foto de un recibo y devuelve monto/fecha/categoría sugeridos. */
export async function leerRecibo({ apiKey, modelo, imagenBase64, mimeType }) {
  const json = await llamarGemini({
    apiKey,
    modelo,
    prompt: PROMPT_RECIBO,
    esquema: ESQUEMA_RECIBO,
    imagenBase64,
    mimeType,
  });
  return interpretarRespuestaRecibo(json);
}

// ---------------------------------------------------------------------------
// Llamada común
// ---------------------------------------------------------------------------

async function llamarGemini({
  apiKey,
  modelo,
  prompt,
  esquema,
  imagenBase64,
  mimeType,
}) {
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
            { text: prompt },
            { inline_data: { mime_type: mimeType, data: imagenBase64 } },
          ],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: esquema,
      },
    }),
  });

  if (!resp.ok) {
    throw new Error(`Gemini respondió ${resp.status}: ${await resp.text()}`);
  }
  return resp.json();
}

function extraerJson(json) {
  const texto = json?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!texto) {
    throw new Error('Gemini no devolvió contenido interpretable.');
  }
  try {
    return JSON.parse(texto);
  } catch {
    throw new Error('La respuesta de Gemini no fue JSON válido.');
  }
}

function numeroPositivo(v) {
  return typeof v === 'number' && Number.isFinite(v) && v > 0 ? v : null;
}
