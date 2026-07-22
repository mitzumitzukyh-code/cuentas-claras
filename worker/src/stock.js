/**
 * Texto del aviso de stock bajo. Puro y sin dependencias, para probarlo sin
 * Firestore ni FCM (ver `worker/test/stock.test.js`).
 *
 * Recibe SOLO los productos que ACABAN de caer en stock bajo (los que ya
 * estaban bajos no se repiten — de eso se encarga el dedup en KV del index),
 * y arma un único mensaje. Espeja el texto de la pantalla de Notificaciones de
 * la app para que el push y lo que se ve dentro digan lo mismo.
 */
export function construirAvisoStock(nuevosBajos) {
  if (!nuevosBajos || nuevosBajos.length === 0) return null;

  const agotados = nuevosBajos.filter((p) => p.agotado);
  const porAgotarse = nuevosBajos.filter((p) => !p.agotado);
  const nombres = (lista) => lista.map((p) => p.nombre).slice(0, 3).join(', ');

  let titulo;
  let cuerpo;

  // Lo agotado manda en el título: es lo más urgente. Si además hay productos
  // por agotarse, se mencionan en el cuerpo para no perder el dato.
  if (agotados.length > 0) {
    titulo =
      agotados.length === 1
        ? `🛑 ${agotados[0].nombre} se agotó`
        : `🛑 ${agotados.length} productos se agotaron`;
    cuerpo =
      porAgotarse.length > 0
        ? `${nombres(agotados)}. Y ${porAgotarse.length} por agotarse.`
        : nombres(agotados);
  } else {
    titulo =
      porAgotarse.length === 1
        ? `⚠️ Queda poco de ${porAgotarse[0].nombre}`
        : `⚠️ ${porAgotarse.length} productos por agotarse`;
    cuerpo = nombres(porAgotarse);
  }

  return {
    titulo,
    cuerpo,
    datos: {
      tipo: 'stock',
      agotados: String(agotados.length),
      porAgotarse: String(porAgotarse.length),
    },
  };
}
