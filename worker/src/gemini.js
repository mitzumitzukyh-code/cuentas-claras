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

/**
 * Matices por rubro para el prompt de etiqueta.
 *
 * El prompt base está escrito para un producto empaquetado de bodega: busca
 * marca, peso y volumen. Eso funciona con una harina y falla con una blusa,
 * un tornillo o un cargador — no tienen "marca + gramaje" que leer, así que
 * el modelo terminaba inventando una presentación o devolviendo un nombre
 * genérico. Cada rubro dice aquí qué mirar en su lugar.
 *
 * Las claves son los `Rubro.id` de la app (`rubro.dart`). Los rubros que no
 * aparecen —bodega, comida rápida, otro— se quedan con el prompt base, que ya
 * describe su caso.
 */
export const MATICES_POR_RUBRO = {
  ropa: `Esta tienda vende ROPA. Una prenda casi nunca trae marca ni gramaje
legibles en la foto, así que no los busques: nómbrala por lo que se ve —tipo
de prenda, corte y color—, como la anotaría el dueño en su cuaderno.
Ejemplos: "Blusa manga corta negra", "Jean recto azul", "Franela cuello V
blanca", "Chaqueta jean oversize".
En presentacion pon la TALLA solo si se lee en la etiqueta o el empaque; si no
se lee, déjala vacía. Nunca deduzcas la talla del tamaño aparente en la foto.`,

  belleza: `Esta tienda vende productos de BELLEZA. Si el envase tiene marca y
tono, úsalos ("Labial Vogue tono 24", "Base líquida beige"). Si es un producto
sin marca visible, nómbralo por lo que es y su color o acabado. En
presentacion va el contenido (ml, g) o el número de tono, solo si se lee.`,

  quincalleria: `Esta tienda es una QUINCALLERÍA o ferretería. Lo que
identifica a estos productos es el tipo y la MEDIDA, no la marca: "Tornillo
autorroscante 1/2", "Bombillo LED 9W", "Cable #12", "Candado 40mm". En
presentacion va la medida, el calibre o la potencia cuando se lea en la pieza
o su empaque. Si vienen varias unidades en una bolsa, indícalo ("12 uds").`,

  panaderia: `Esta tienda es una PANADERÍA o charcutería. Casi nada trae
etiqueta: nombra la pieza por lo que es, como la canta el dueño en el
mostrador. Ejemplos: "Pan canilla", "Pan de jamón", "Cachito de jamón",
"Queso blanco duro", "Jamón de pierna". En presentacion va el peso solo si se
lee en una etiqueta de balanza; si la pieza se vende por kilo y no hay
etiqueta, déjala vacía. No inventes gramajes a ojo.`,

  electronica: `Esta tienda vende ELECTRÓNICA. Lo que importa es MARCA +
MODELO, y la capacidad cuando aplique: "Xiaomi Redmi 12 128GB", "Cargador tipo
C 20W", "Audífonos inalámbricos negros". No confundas la capacidad de
almacenamiento con el peso. En presentacion va la capacidad (GB), la potencia
(W) o la longitud del cable, solo si se lee.`,
};

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
 * Arma el prompt de etiqueta: base + matiz del rubro + categorías.
 *
 * El rubro se busca en [MATICES_POR_RUBRO] en lugar de concatenarse tal cual:
 * el valor llega del cuerpo de la petición, y meter texto de fuera dentro de
 * un prompt es exactamente como se le da la vuelta a un modelo. Un rubro
 * desconocido simplemente no aporta matiz.
 *
 * Separada de la llamada de red para poder probarla sin pegarle a Gemini.
 */
export function armarPromptEtiqueta({ categorias = [], rubro = '' } = {}) {
  const partes = [PROMPT_ETIQUETA];

  const matiz = Object.hasOwn(MATICES_POR_RUBRO, rubro)
    ? MATICES_POR_RUBRO[rubro]
    : null;
  if (matiz) partes.push(matiz);

  if (categorias.length) {
    partes.push(`Categorías de la tienda: ${categorias.join(', ')}`);
  }
  return partes.join('\n\n');
}

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
  rubro = '',
}) {
  const prompt = armarPromptEtiqueta({ categorias, rubro });

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

const PROMPT_LIBRETA = `Estás viendo la foto de una lista de inventario de una
tienda pequeña en Venezuela. Puede ser impresa, de otra app, o escrita a mano
en un cuaderno.

PRIMERO, antes de transcribir nada, identifica los ENCABEZADOS de la tabla y en
qué posición horizontal está cada columna (código, descripción, existencia,
precio, costo, talla, color…). Después lee cada fila mapeando cada celda a SU
columna por la posición, no por el orden en que aparecen los números. Una fila
a la que le falta una celda deja ese campo vacío: NO corras los valores de la
columna siguiente para rellenarlo — ese corrimiento es el error más caro,
porque mete una existencia en el lugar de un precio.

Si la lista no tiene encabezados (un cuaderno a mano), usa el sentido común del
renglón: el nombre del producto, y las cifras que lo acompañen.

Devuelve, por cada fila legible:
- nombre: el producto tal como está escrito, limpio, sin cifras pegadas.
- codigo: el código o referencia del artículo si hay columna de código; si no,
  cadena vacía.
- precio: el precio unitario TAL COMO ESTÁ ESCRITO, como texto y sin tocarlo
  ("4.500,80", "$3,50"). No lo conviertas ni le quites los puntos: de eso se
  encarga la app. Cadena vacía si no se lee.
- cantidad: la existencia, también como texto y sin tocar. Cadena vacía si no
  se lee.
- talla y color: solo si la lista tiene columna de talla o de color. Si no
  las tiene, cadena vacía en ambas.
- confianzaPrecio y confianzaCantidad: "alta" si la cifra se lee nítida y sin
  ambigüedad; "media" si es legible pero podría confundirse; "baja" si estás
  adivinando. Es por CAMPO, no por documento: en una misma fila el nombre puede
  ser nítido y el precio dudoso.

Además:
- tipoDocumento: "inventario" si es una lista de existencias del negocio;
  "factura_compra" si es una factura o nota de entrega de un proveedor (trae
  precios de costo, no de venta); "desconocido" si no distingues.
- totalDeclarado: si la lista declara un total de artículos o de renglones
  ("Total Artículos: 423"), esa cifra como texto. Cadena vacía si no lo dice.
- esLista: false si la foto no muestra una lista de productos.

REGLAS DURAS:
- Nunca inventes un valor que no esté escrito. Ante la duda, campo vacío: la
  app le pedirá al dueño que lo complete. Un precio inventado se cobra.
- Nunca uses 0 para decir "no se lee". Cero es un valor, no una ausencia.
- Ignora renglones tachados, subtotales y encabezados repetidos.
- Devuelve JSON estricto y nada más: sin markdown, sin explicaciones.`;

const ESQUEMA_LIBRETA = {
  type: 'OBJECT',
  properties: {
    esLista: { type: 'BOOLEAN' },
    tipoDocumento: { type: 'STRING' },
    totalDeclarado: { type: 'STRING' },
    filas: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          nombre: { type: 'STRING' },
          codigo: { type: 'STRING' },
          // Las cifras viajan como TEXTO a propósito: "4.500,80" lo interpreta
          // Dart con una regla determinista. Pedirle al modelo que devuelva un
          // número daba a veces 4.5 y a veces 450080, sin forma de saber cuál.
          precio: { type: 'STRING' },
          cantidad: { type: 'STRING' },
          talla: { type: 'STRING' },
          color: { type: 'STRING' },
          confianzaPrecio: { type: 'STRING' },
          confianzaCantidad: { type: 'STRING' },
        },
        required: ['nombre'],
      },
    },
  },
  required: ['esLista', 'filas'],
};

/** Texto limpio de un campo, o cadena vacía. */
function texto(v) {
  return typeof v === 'string' ? v.trim() : '';
}

/** Una de las tres confianzas; cualquier otra cosa es "media". */
function confianza(v) {
  const c = texto(v).toLowerCase();
  return c === 'alta' || c === 'baja' ? c : 'media';
}

/** Reduce la respuesta de la libreta a filas limpias y utilizables. */
export function interpretarRespuestaLibreta(json) {
  const datos = extraerJson(json);
  if (!datos.esLista || !Array.isArray(datos.filas)) {
    return { reconocido: false, filas: [] };
  }

  // Las cifras se pasan como texto y sin tocar: normalizarlas es trabajo de
  // Dart, donde la regla es determinista y está probada.
  const filas = datos.filas
    .filter((f) => typeof f?.nombre === 'string' && f.nombre.trim())
    .map((f) => ({
      nombre: f.nombre.trim(),
      codigo: texto(f.codigo),
      precio: texto(f.precio),
      cantidad: texto(f.cantidad),
      talla: texto(f.talla),
      color: texto(f.color),
      confianzaPrecio: confianza(f.confianzaPrecio),
      confianzaCantidad: confianza(f.confianzaCantidad),
    }));

  const tipos = ['inventario', 'factura_compra', 'desconocido'];
  const tipoDocumento = tipos.includes(texto(datos.tipoDocumento))
    ? texto(datos.tipoDocumento)
    : 'desconocido';

  return {
    reconocido: filas.length > 0,
    filas,
    tipoDocumento,
    totalDeclarado: texto(datos.totalDeclarado),
  };
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
// Cuaderno de fiados
// ---------------------------------------------------------------------------

const PROMPT_FIADOS = `Estás viendo la foto de la página de un cuaderno donde
el dueño de una tienda pequeña en Venezuela lleva a mano quién le debe plata.
Casi siempre es letra manuscrita, a veces con columnas y a veces solo renglones
sueltos.

Cada renglón útil tiene un NOMBRE de persona y un MONTO que esa persona debe.
Puede traer además una fecha y una nota de qué se llevó.

Devuelve, por cada renglón legible:
- nombre: el nombre de la persona tal como está escrito, limpio y sin cifras
  pegadas. Si solo hay un apodo ("la señora del kiosco"), ese apodo.
- monto: la cifra que debe, TAL COMO ESTÁ ESCRITA, como texto y sin tocarla
  ("1.500", "20,50", "3$"). No la conviertas, no le quites los puntos ni las
  comas: de eso se encarga la app con una regla determinista.
- fecha: la fecha del renglón en formato YYYY-MM-DD si se lee completa y sin
  ambigüedad. Cadena vacía en cualquier otro caso — incluido cuando solo hay
  día y mes sin año.
- concepto: qué se llevó, si el renglón lo dice ("2 harinas", "cerveza").
  Cadena vacía si no.
- confianzaNombre y confianzaMonto: "alta" si se lee nítido y sin ambigüedad;
  "media" si es legible pero podría confundirse; "baja" si estás adivinando.
  Es por CAMPO: en un mismo renglón el nombre puede ser claro y el monto
  dudoso.

REGLAS DURAS:
- NO interpretes la moneda ni la conviertas. El dueño ya le dijo a la app si su
  cuaderno está en bolívares o en dólares. Un "150" se devuelve como "150" sin
  decidir de qué moneda es: equivocarse ahí multiplica una deuda por setecientos.
- Un renglón TACHADO es una deuda ya pagada: NO lo devuelvas. Es el error más
  caro de esta pantalla — revive una deuda que el cliente ya salió de pagar.
- Si un mismo nombre aparece varias veces con montos distintos, devuelve un
  renglón por cada uno. La app decide si suman o si es el saldo actualizado.
- Nunca inventes un nombre ni un monto. Ante la duda, campo vacío.
- Nunca uses 0 para decir "no se lee". Cero es un monto, no una ausencia.
- Ignora totales, subtotales y encabezados.
- esCuaderno: false si la foto no muestra una lista de deudas de personas.
- Devuelve JSON estricto y nada más: sin markdown, sin explicaciones.`;

const ESQUEMA_FIADOS = {
  type: 'OBJECT',
  properties: {
    esCuaderno: { type: 'BOOLEAN' },
    filas: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          nombre: { type: 'STRING' },
          // Como en la libreta de inventario: la cifra viaja como TEXTO. Un
          // "1.500" que el modelo devuelva como número puede llegar 1.5.
          monto: { type: 'STRING' },
          fecha: { type: 'STRING' },
          concepto: { type: 'STRING' },
          confianzaNombre: { type: 'STRING' },
          confianzaMonto: { type: 'STRING' },
        },
        required: ['nombre'],
      },
    },
  },
  required: ['esCuaderno', 'filas'],
};

/**
 * Interpreta la respuesta del modelo para un cuaderno de fiados.
 *
 * Una fila sin monto legible se conserva: el dueño la completa en la tabla de
 * revisión. Lo que no se conserva es una fila sin nombre — sin saber de quién
 * es la deuda no hay nada que anotar.
 */
export function interpretarRespuestaFiados(json) {
  const datos = extraerJson(json);
  if (!datos.esCuaderno || !Array.isArray(datos.filas)) {
    return { reconocido: false, filas: [] };
  }

  const filas = datos.filas
    .filter((f) => typeof f?.nombre === 'string' && f.nombre.trim())
    .map((f) => ({
      nombre: f.nombre.trim(),
      monto: texto(f.monto),
      fecha: texto(f.fecha),
      concepto: texto(f.concepto),
      confianzaNombre: confianza(f.confianzaNombre),
      confianzaMonto: confianza(f.confianzaMonto),
    }));

  return { reconocido: filas.length > 0, filas };
}

export async function leerFiados({ apiKey, modelo, imagenBase64, mimeType }) {
  const json = await llamarGemini({
    apiKey,
    modelo,
    prompt: PROMPT_FIADOS,
    esquema: ESQUEMA_FIADOS,
    imagenBase64,
    mimeType,
  });
  return interpretarRespuestaFiados(json);
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
