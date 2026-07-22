/**
 * Lógica de los avisos de tasa: qué cambió, cuánto, y cómo se lo contamos.
 *
 * Va en su propio módulo, sin nada de Cloudflare ni de Firebase, para poder
 * probarlo con datos inventados sin desplegar ni enviar un push de verdad.
 */

/** Cuántos días de tasas guardamos para poder calcular el ritmo. */
export const DIAS_HISTORIAL = 14;

/**
 * Umbrales, en porcentaje. Cada uno es un topic distinto de FCM.
 *
 * El Worker publica en TODOS los umbrales que la variación supere: una subida
 * del 3,4 % va a `tasa-subida-medio`, `-uno` y `-tres`, pero no a `-cinco`.
 * Como cada dispositivo está suscrito a un solo umbral, nadie recibe repetido.
 */
export const UMBRALES = [
  { id: 'minimo', pct: 0.1 },
  { id: 'medio', pct: 0.5 },
  { id: 'uno', pct: 1 },
  { id: 'tres', pct: 3 },
  { id: 'cinco', pct: 5 },
];

/** Bs con formato venezolano: punto para miles, coma para decimales. */
export function bs(valor) {
  return valor.toLocaleString('es-VE', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

function pct(valor) {
  const signo = valor > 0 ? '+' : '';
  return `${signo}${valor.toFixed(2).replace('.', ',')}%`;
}

/** Variación porcentual entre dos tasas. */
export function variacion(anterior, actual) {
  if (!anterior) return 0;
  return ((actual - anterior) / anterior) * 100;
}

/**
 * Racha de días consecutivos subiendo, mirando el historial de atrás hacia
 * adelante. Es la señal de "esto no fue un salto suelto, viene acelerando".
 */
export function rachaDeSubidas(historial) {
  let racha = 0;
  for (let i = historial.length - 1; i > 0; i--) {
    if (historial[i].tasa > historial[i - 1].tasa) racha++;
    else break;
  }
  return racha;
}

/** Variación acumulada en los últimos [dias] días. */
export function variacionEnDias(historial, dias) {
  if (historial.length < 2) return 0;
  const corte = Date.now() - dias * 24 * 60 * 60 * 1000;
  const viejos = historial.filter((h) => new Date(h.fecha).getTime() >= corte);
  const base = viejos.length >= 2 ? viejos[0] : historial[0];
  return variacion(base.tasa, historial[historial.length - 1].tasa);
}

/**
 * Frase de tendencia para el resumen de la mañana.
 *
 * No es un pronóstico financiero: es la lectura simple que haría un
 * comerciante con los últimos 14 días anotados en su cuaderno — hacia dónde
 * apunta la tasa y a qué ritmo. Siempre devuelve algo, incluso cuando la tasa
 * está quieta: "estable" también es información que el usuario pidió recibir.
 */
export function tendencia(historial) {
  const semana = variacionEnDias(historial, 7);
  const racha = rachaDeSubidas(historial);

  if (racha >= 3 || semana >= 2) {
    return (
      `Viene acelerando (${pct(semana)} en la semana): ` +
      'apunta a seguir subiendo.'
    );
  }
  if (semana >= 0.3) {
    return `Sube poco a poco: ${pct(semana)} en la semana.`;
  }
  if (semana <= -0.3) {
    return `Viene bajando: ${pct(semana)} en la semana.`;
  }
  return 'Se ha mantenido estable esta semana.';
}

/**
 * Decide qué avisos tocan y con qué texto.
 *
 * Devuelve una lista de `{ topics, titulo, cuerpo, datos }`. Vacía cuando no
 * hay nada que contar, que es lo normal: la tasa no se mueve todos los días y
 * avisar de un cambio de 0,01 % solo entrena al usuario a ignorar la app.
 */
export function construirAvisos({ anterior, actual, historial, esResumen }) {
  const avisos = [];
  const delta = actual - (anterior ?? actual);
  const varPct = variacion(anterior, actual);
  const absPct = Math.abs(varPct);

  const datosBase = {
    tasa: String(actual),
    anterior: String(anterior ?? ''),
    variacion: varPct.toFixed(4),
  };

  // --- Subida / bajada ---
  if (anterior && absPct >= UMBRALES[0].pct) {
    const subio = varPct > 0;
    const topics = UMBRALES.filter((u) => absPct >= u.pct).map(
      (u) => `tasa-${subio ? 'subida' : 'bajada'}-${u.id}`,
    );

    avisos.push({
      topics,
      titulo: subio ? '📈 El dólar subió' : '📉 El dólar bajó',
      cuerpo:
        `Bs ${bs(actual)} · ${delta > 0 ? '+' : '−'}${bs(Math.abs(delta))} ` +
        `(${pct(varPct)})`,
      datos: { ...datosBase, tipo: subio ? 'subida' : 'bajada' },
    });
  }

  // --- Ritmo ---
  // Solo cuando hay una tendencia real detrás, no por un salto aislado: para
  // eso ya está el aviso de subida.
  const racha = rachaDeSubidas(historial);
  const semana = variacionEnDias(historial, 7);
  if (racha >= 3 || semana >= 5) {
    const partes = [];
    if (racha >= 3) partes.push(`${racha} días seguidos subiendo`);
    if (semana >= 5) partes.push(`${pct(semana)} en la semana`);

    avisos.push({
      topics: ['tasa-ritmo'],
      titulo: '🚀 El dólar viene acelerando',
      cuerpo: `${partes.join(' · ')}. Hoy está en Bs ${bs(actual)}.`,
      datos: { ...datosBase, tipo: 'ritmo', racha: String(racha) },
    });
  }

  // --- Resumen de la mañana ---
  if (esResumen) {
    let detalle;
    if (!anterior || Math.abs(varPct) < 0.01) {
      detalle = 'sin cambios desde ayer';
    } else {
      detalle =
        `${varPct > 0 ? 'subió' : 'bajó'} ${bs(Math.abs(delta))} ` +
        `(${pct(varPct)}) desde ayer`;
    }
    avisos.push({
      topics: ['tasa-resumen'],
      titulo: `☀️ Hoy el dólar está en Bs ${bs(actual)}`,
      cuerpo: `El BCV ${detalle}. ${tendencia(historial)}`,
      datos: { ...datosBase, tipo: 'resumen' },
    });
  }

  return avisos;
}
