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
