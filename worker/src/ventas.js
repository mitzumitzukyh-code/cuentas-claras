/**
 * Texto del resumen de ventas del día — lógica pura, sin red, para poder
 * probarla con datos inventados (mismo criterio que tasa.js).
 */

/** Bs con formato venezolano (duplicado pequeño de `bs()` en tasa.js: mismo
 * formato pero este módulo no depende de tasa.js a propósito, para poder
 * probarlo aislado). */
function usd(valor) {
  return valor.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

/**
 * Huella de un mensaje ya enviado a un dispositivo en esta corrida.
 *
 * El resumen sale UNO POR NEGOCIO (un dueño de tres bodegas quiere las tres
 * cuentas), pero el destinatario es un token de dispositivo, y el mismo
 * teléfono puede figurar como dueño en varios negocios: cada uno que visita
 * le graba su token en la membresía y ninguno se lo quita. Con varios
 * negocios sin ventas, los textos salen IDÉNTICOS —"👋 ¿Cómo va tu día?"— y
 * el teléfono recibe la misma frase repetida, que es lo que se vio: cinco
 * copias iguales en la misma tanda.
 *
 * El dedup de KV no lo tapa porque su clave es por negocio
 * (`resumenVentas:<negocioId>`): cinco negocios son cinco claves distintas y
 * las cinco pasan.
 *
 * Así que se deduplica por lo único que el usuario percibe: mismo destino +
 * mismo texto = un solo aviso. Dos negocios con cifras distintas siguen
 * mandando sus dos resúmenes, que es lo correcto.
 */
export function huellaDeEnvio({ destino, titulo, cuerpo }) {
  return `${destino}|${titulo}|${cuerpo}`;
}

/**
 * De todos los resúmenes pendientes, cuáles se mandan de verdad.
 *
 * El resumen sale uno por negocio, pero el destinatario es un TELÉFONO, y el
 * mismo teléfono administra varios negocios. Con uno que vendió y otro que no,
 * al dueño le llegaban juntas "🌙 Cierre del día · Vendiste $4,50 en 1 cobro
 * hoy" y "👋 ¿Cómo va tu día? · Todavía no registras ventas hoy". Las dos eran
 * ciertas —de negocios distintos— pero el teléfono no dice cuál es cuál, así
 * que se leen como una contradicción y entrenan a ignorar el aviso.
 *
 * `huellaDeEnvio` no lo tapaba: deduplica textos IDÉNTICOS, y estos difieren.
 *
 * Regla: si a un teléfono le toca al menos un resumen con ventas, las ramas
 * "sin ventas" de sus otros negocios no se envían. El recordatorio de usar la
 * app no tiene sentido para quien hoy ya vendió.
 *
 * Espera objetos `{ pushToken, cobros }` y devuelve el mismo arreglo filtrado,
 * en el mismo orden.
 */
export function resumenesAEnviar(pendientes) {
  const conVenta = new Set(
    pendientes.filter((p) => p.cobros > 0).map((p) => p.pushToken),
  );
  return pendientes.filter((p) => p.cobros > 0 || !conVenta.has(p.pushToken));
}

/**
 * Arma el resumen de ventas del día — con cobros, cuánto vendiste; sin
 * ellos, una invitación amigable a usar la app en vez de quedarse callado.
 * Nunca "vendiste $0 hoy": eso no le sirve a nadie y solo entrena al dueño a
 * ignorar la notificación (mismo criterio que los avisos de tasa), así que
 * el mensaje cambia de tono en vez de desaparecer.
 */
export function mensajeResumenVentas({ total, cobros }) {
  if (cobros === 0) {
    return {
      titulo: '👋 ¿Cómo va tu día?',
      cuerpo:
        'Todavía no registras ventas hoy. Cuenta Clara te ayuda a llevar ' +
        'el control de tus ventas y tu inventario sin esfuerzo — cóbrale a ' +
        'tu próximo cliente desde la app.',
      datos: { tipo: 'recordatorio_ventas' },
    };
  }

  return {
    titulo: '🌙 Cierre del día',
    cuerpo:
      `Vendiste $${usd(total)} en ${cobros} ` +
      `${cobros === 1 ? 'cobro' : 'cobros'} hoy.`,
    datos: {
      tipo: 'resumen_ventas',
      total: String(total),
      cobros: String(cobros),
    },
  };
}
