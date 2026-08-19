/**
 * Lógica de los avisos de tasa: qué pasó desde el último aviso y cómo se lo
 * contamos.
 *
 * Va en su propio módulo, sin nada de Cloudflare ni de Firebase, para poder
 * probarlo con datos inventados sin desplegar ni enviar un push de verdad.
 *
 * El dólar se avisa en franjas fijas del día y nada más: 8 am, 12 pm y 3 pm.
 * Avisar en cuanto la tasa se mueve —el diseño anterior, con umbrales
 * horarios— mandaba varias notificaciones al día con el mismo dato y se leía
 * como spam; el dueño terminaba apagando también el resumen de la mañana, que
 * es el que sí servía. Una cifra nueva no tiene nada de urgente: lo urgente
 * es que llegue a la hora que el dueño ya espera.
 */
export const DIAS_HISTORIAL = 14;

/** Los tres momentos del día en que sale el aviso de tasa. */
export const MOMENTOS = ['manana', 'mediodia', 'tarde'];

/**
 * Topic único de los avisos de tasa.
 *
 * Los tres momentos salen por el mismo topic: son el mismo dato —la tasa del
 * día— actualizado, y quien lo recibe lo pidió con un solo interruptor. Antes
 * había un topic por tipo (subida, bajada, ritmo) y por umbral; eso se fue
 * con los avisos horarios.
 */
export const TOPIC_TASA = 'tasa-resumen';

/**
 * ¿El BCV publica tasa ese día?
 *
 * Solo de lunes a viernes. El cron corre cada hora los siete días, así que sin
 * esto el resumen de la mañana salía sábado y domingo diciendo "el BCV sin
 * cambios desde ayer" — que es verdad, pero es ruido: el BCV no trabaja, no ha
 * pasado nada, y quien lo recibe dos veces cada fin de semana aprende a
 * ignorar los avisos de tasa.
 *
 * Se mira en hora de Venezuela (UTC−4), no en la del servidor: a medianoche
 * UTC del sábado en Venezuela todavía es viernes.
 */
export function esDiaHabilVE(ahora = new Date()) {
  const ve = new Date(ahora.getTime() - 4 * 60 * 60 * 1000);
  const dia = ve.getUTCDay();
  return dia >= 1 && dia <= 5;
}

/**
 * ¿La tasa que devolvió la API es de hoy?
 *
 * `fechaActualizacion` viene ya en hora de Venezuela. Un feriado no cae en fin
 * de semana pero el BCV tampoco publica, así que [esDiaHabilVE] no lo atrapa y
 * esto sí: la fecha se queda en el último día hábil.
 *
 * Ante una fecha ausente o ilegible devuelve `true` — no bloquear es preferible
 * a callar un aviso real por no saber leer un campo.
 */
export function tasaEsDeHoy(fechaActualizacion, ahora = new Date()) {
  if (!fechaActualizacion) return true;
  const publicada = new Date(fechaActualizacion);
  if (Number.isNaN(publicada.getTime())) return true;

  const dia = (d) =>
    new Date(d.getTime() - 4 * 60 * 60 * 1000).toISOString().slice(0, 10);
  return dia(publicada) === dia(ahora);
}

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
 * El aviso de una franja del día: la tasa de ahora y cuánto cambió desde el
 * aviso anterior.
 *
 * Sale SIEMPRE en la franja —también con la tasa quieta, porque lo que el
 * dueño espera es saber que sigue igual— y devuelve un solo aviso, no una
 * lista: por franja toca una notificación, y una sola.
 *
 * `anteriorCheckpoint` es la tasa del aviso anterior del MISMO día (la mañana
 * para el mediodía, el mediodía para la tarde); si no existe —el de las 8 no
 * llegó a salir— se mide contra `anterior`, la última tasa conocida. `paralelo`
 * solo se usa en la mañana, que es donde ya se miraban las cifras del día.
 *
 * Con un `momento` que no conozca devuelve `null`, para que el llamador pueda
 * confiar en que "momento desconocido no manda nada".
 */
export function construirAviso({
  anterior,
  anteriorCheckpoint,
  actual,
  historial,
  momento,
  paralelo = null,
}) {
  if (!MOMENTOS.includes(momento)) return null;

  const esManana = momento === 'manana';
  const base = anteriorCheckpoint ?? anterior;
  const varPct = variacion(base, actual);
  const delta = actual - (base ?? actual);

  // La paralela es solo de la mañana, que es donde el dueño ya mira las
  // cifras del día; ni se consulta ni se anuncia en las otras franjas.
  const conParalela =
    esManana && paralelo != null && Number.isFinite(paralelo) && paralelo > 0;

  const titulo = esManana
    ? conParalela
      ? `☀️ BCV Bs ${bs(actual)} · Paralelo Bs ${bs(paralelo)}`
      : `☀️ Hoy el dólar está en Bs ${bs(actual)}`
    : momento === 'mediodia'
      ? `🕛 El dólar al mediodía: Bs ${bs(actual)}`
      : `🕒 El dólar en la tarde: Bs ${bs(actual)}`;

  let cuerpo;
  if (!base) {
    cuerpo = 'Primer aviso del día.';
  } else if (Math.abs(varPct) < 0.01) {
    cuerpo = esManana
      ? `El BCV sin cambios desde ayer. ${tendencia(historial)}`
      : `Sin cambios desde ${momento === 'mediodia' ? 'la mañana' : 'el mediodía'}.`;
  } else {
    const subio = varPct > 0;
    const detalle = `${subio ? 'subió' : 'bajó'} ${bs(Math.abs(delta))} (${pct(varPct)})`;
    cuerpo = esManana
      ? `El BCV ${detalle} desde ayer. ${tendencia(historial)}`
      : `El dólar ${detalle} desde ${momento === 'mediodia' ? 'la mañana' : 'el mediodía'}.`;
  }

  // La paralela va aquí y no en un aviso aparte: es el sitio donde el dueño
  // ya mira las cifras del día, y un segundo push a la misma hora diciendo
  // otro número se lee como spam. Además, el push y la app sacan la paralela
  // de sitios distintos (ver `API_PARALELO`): sin decirlo, el dueño abre la
  // app después del push, ve otro número y concluye que una de las dos miente.
  const deDonde = esManana && conParalela
    ? ' Paralelo de referencia — en la app ves el del mercado P2P.'
    : '';

  return {
    topics: [TOPIC_TASA],
    titulo,
    cuerpo: esManana ? `${cuerpo}${deDonde}` : cuerpo,
    datos: {
      tasa: String(actual),
      anterior: String(base ?? ''),
      variacion: varPct.toFixed(4),
      // `resumen` a propósito en las tres franjas: es el tipo que la app ya
      // sabe pintar y rutear; el momento va aparte para quien quiera distinguir.
      tipo: 'resumen',
      momento,
      // Vacío y no ausente cuando Binance no respondió: el cliente distingue
      // "no hay paralela hoy" de "esta versión no la manda".
      paralelo: conParalela ? String(paralelo) : '',
    },
  };
}
