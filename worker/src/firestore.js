/**
 * Acceso de solo lectura a Firestore vía su API REST, para el resumen de
 * ventas — el Worker no tiene el SDK de Firebase Admin (es Node-only), así
 * que se habla HTTP directo con el mismo token OAuth que ya se pide para
 * mandar los avisos por FCM (ver ALCANCE en fcm.js).
 */

/** Extrae el valor plano de un campo con el formato de Firestore REST. */
export function valorDeCampo(campo) {
  if (!campo) return undefined;
  if ('stringValue' in campo) return campo.stringValue;
  if ('doubleValue' in campo) return campo.doubleValue;
  if ('integerValue' in campo) return Number(campo.integerValue);
  if ('booleanValue' in campo) return campo.booleanValue;
  if ('timestampValue' in campo) return campo.timestampValue;
  if ('nullValue' in campo) return null;
  return undefined;
}

async function ejecutarQuery({ token, projectId, parent, structuredQuery }) {
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  const url = parent ? `${base}/${parent}:runQuery` : `${base}:runQuery`;
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ structuredQuery }),
  });
  if (!resp.ok) {
    throw new Error(`Firestore ${resp.status}: ${await resp.text()}`);
  }
  const filas = await resp.json();
  return filas.filter((f) => f.document).map((f) => f.document);
}

/**
 * Membresías de dueño con un token de notificaciones guardado — son los
 * únicos que reciben el resumen de ventas (CLAUDE.md §6: es información
 * financiera, un empleado no la ve).
 */
export async function duenosConToken({ token, projectId }) {
  const docs = await ejecutarQuery({
    token,
    projectId,
    structuredQuery: {
      from: [{ collectionId: 'membresias' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'rol' },
          op: 'EQUAL',
          value: { stringValue: 'dueno' },
        },
      },
    },
  });
  return docs
    .map((d) => ({
      negocioId: valorDeCampo(d.fields.negocioId),
      pushToken: valorDeCampo(d.fields.pushToken),
    }))
    .filter((m) => m.negocioId && m.pushToken);
}

/**
 * Total cobrado y número de cobros de un negocio desde [desde] — se filtran
 * las anuladas aquí (en el cliente) en vez de con un segundo filtro
 * compuesto en la consulta: para el volumen de ventas de un negocio pequeño
 * no vale la pena la complejidad extra.
 */
export async function ventasDesde({ token, projectId, negocioId, desde }) {
  const docs = await ejecutarQuery({
    token,
    projectId,
    parent: `negocios/${negocioId}`,
    structuredQuery: {
      from: [{ collectionId: 'ventas' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'fecha' },
          op: 'GREATER_THAN_OR_EQUAL',
          value: { timestampValue: desde.toISOString() },
        },
      },
    },
  });

  let total = 0;
  let cobros = 0;
  for (const doc of docs) {
    if (valorDeCampo(doc.fields.anulada) === true) continue;
    total += valorDeCampo(doc.fields.totalUSD) ?? 0;
    cobros++;
  }
  return { total, cobros };
}

/**
 * `false` solo si el dueño apagó las alertas de stock del negocio; por defecto
 * están activas (igual que en la app, que asume `alertaStockActiva ?? true`).
 * Un fallo de lectura no debe silenciar las alertas, así que también devuelve
 * `true` si el documento no se pudo leer.
 */
export async function negocioAvisaStock({ token, projectId, negocioId }) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${projectId}` +
    `/databases/(default)/documents/negocios/${negocioId}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!resp.ok) return true;
  const doc = await resp.json();
  return valorDeCampo(doc.fields?.alertaStockActiva) !== false;
}

/**
 * Productos con stock bajo de un negocio: los que tienen umbral configurado
 * (`alertaEn`) y su cantidad ya cayó a ese umbral o menos — la misma regla que
 * `Producto.stockBajo` en la app.
 *
 * El filtro `cantidad <= alertaEn` compara dos campos del mismo documento, algo
 * que las consultas de Firestore no permiten, así que se leen los productos y
 * se filtra aquí. Para el plan gratis (tope de 50 productos) es intrascendente.
 * Devuelve `{ id, nombre, cantidad, agotado }` por producto.
 */
export async function productosBajos({ token, projectId, negocioId }) {
  const docs = await ejecutarQuery({
    token,
    projectId,
    parent: `negocios/${negocioId}`,
    structuredQuery: { from: [{ collectionId: 'productos' }] },
  });

  const bajos = [];
  for (const doc of docs) {
    const alertaEn = valorDeCampo(doc.fields?.alertaEn);
    if (alertaEn == null || alertaEn <= 0) continue;
    const cantidad = valorDeCampo(doc.fields?.cantidad) ?? 0;
    if (cantidad <= alertaEn) {
      bajos.push({
        id: doc.name.split('/').pop(),
        nombre: valorDeCampo(doc.fields?.nombre) ?? 'Producto',
        cantidad,
        agotado: cantidad <= 0,
      });
    }
  }
  return bajos;
}
