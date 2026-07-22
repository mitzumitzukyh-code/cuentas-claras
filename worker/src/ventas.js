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
