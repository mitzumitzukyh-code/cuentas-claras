/**
 * Pruebas de la lógica de avisos. Sin red, sin Cloudflare, sin FCM.
 *
 * Lo que se está protegiendo es la confianza del usuario: un aviso de más
 * entrena a ignorar la app, y uno de menos le hace perder plata. Por eso el
 * grueso de los casos son de "aquí NO se avisa" y de "el texto dice lo que
 * pasó de verdad".
 *
 * El dólar se avisa en tres franjas fijas (8 am, 12 pm, 3 pm), un aviso por
 * franja, salga la tasa igual o movida: el dueño espera el aviso a esa hora,
 * y que no llegue le parece que la app se rompió.
 *
 * Ejecutar:  npm test
 */

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  MOMENTOS,
  TOPIC_TASA,
  construirAviso,
  esDiaHabilVE,
  rachaDeSubidas,
  tasaEsDeHoy,
  variacion,
  variacionEnDias,
} from '../src/tasa.js';

/** Historial sintético: una tasa por día, terminando hoy. */
function historialDe(tasas) {
  const hoy = Date.now();
  return tasas.map((tasa, i) => ({
    fecha: new Date(hoy - (tasas.length - 1 - i) * 86400000)
      .toISOString()
      .slice(0, 10),
    tasa,
  }));
}

describe('variacion', () => {
  it('calcula el porcentaje entre dos tasas', () => {
    assert.equal(variacion(100, 110), 10);
    assert.equal(variacion(100, 95), -5);
  });

  it('devuelve 0 sin tasa anterior (primera ejecución)', () => {
    assert.equal(variacion(null, 700), 0);
  });
});

describe('rachaDeSubidas', () => {
  it('cuenta los días consecutivos al alza', () => {
    assert.equal(rachaDeSubidas(historialDe([700, 710, 720, 730])), 3);
  });

  it('se corta con una bajada', () => {
    assert.equal(rachaDeSubidas(historialDe([700, 730, 720, 725])), 1);
  });

  it('es 0 si la última bajó', () => {
    assert.equal(rachaDeSubidas(historialDe([700, 710, 705])), 0);
  });
});

describe('variacionEnDias', () => {
  it('mide el acumulado de la ventana', () => {
    const v = variacionEnDias(historialDe([700, 710, 720, 730, 770]), 7);
    assert.ok(Math.abs(v - 10) < 0.001, `esperaba ~10%, dio ${v}`);
  });
});

describe('construirAviso', () => {
  const base = { actual: 700, anterior: 700, historial: historialDe([700, 700]) };

  it('con un momento desconocido no manda nada', () => {
    assert.equal(
      construirAviso({ ...base, momento: 'medianoche' }),
      null,
    );
  });

  it('siempre sale por el topic de tasa', () => {
    for (const momento of MOMENTOS) {
      const aviso = construirAviso({ ...base, momento });
      assert.deepEqual(aviso.topics, [TOPIC_TASA], `momento=${momento}`);
      assert.equal(aviso.datos.tipo, 'resumen', `momento=${momento}`);
      assert.equal(aviso.datos.momento, momento, `momento=${momento}`);
    }
  });

  it('la mañana dice la tasa en el título', () => {
    const aviso = construirAviso({ ...base, actual: 732.48, momento: 'manana' });
    assert.match(aviso.titulo, /Hoy el dólar está en Bs 732,48/);
  });

  it('la mañana no avisa del cambio cuando la tasa sigue igual', () => {
    const aviso = construirAviso({ ...base, momento: 'manana' });
    assert.match(aviso.cuerpo, /sin cambios desde ayer/);
  });

  it('la mañana cuenta el movimiento y su porcentaje', () => {
    const aviso = construirAviso({
      ...base,
      anterior: 700,
      actual: 714,
      momento: 'manana',
    });
    assert.match(aviso.cuerpo, /subió 14,00/);
    assert.match(aviso.cuerpo, /\+2,00%/);
  });

  it('la mañana dice "estable" cuando la semana estuvo quieta', () => {
    const aviso = construirAviso({
      ...base,
      historial: historialDe([732.48, 732.48, 732.48]),
      momento: 'manana',
    });
    assert.match(aviso.cuerpo, /estable esta semana/);
  });

  it('la mañana anticipa la subida cuando viene acelerando', () => {
    const aviso = construirAviso({
      anterior: 730,
      actual: 740,
      historial: historialDe([700, 710, 720, 730, 740]),
      momento: 'manana',
    });
    assert.match(aviso.cuerpo, /apunta a seguir subiendo/);
  });

  it('la mañana menciona la bajada semanal', () => {
    const aviso = construirAviso({
      anterior: 700,
      actual: 700,
      historial: historialDe([710, 705, 700]),
      momento: 'manana',
    });
    assert.match(aviso.cuerpo, /Viene bajando/);
  });

  it('el mediodía y la tarde no traen tendencia ni referencia', () => {
    for (const momento of ['mediodia', 'tarde']) {
      const aviso = construirAviso({ ...base, momento, paralelo: 1234.5 });
      assert.doesNotMatch(aviso.cuerpo, /acelerando|estable|referencia|P2P/);
    }
  });

  it('el mediodía cuenta el cambio desde la mañana', () => {
    const aviso = construirAviso({
      actual: 704.2,
      anteriorCheckpoint: 700,
      anterior: 700,
      historial: historialDe([700, 700]),
      momento: 'mediodia',
    });
    assert.match(aviso.titulo, /🕛 El dólar al mediodía: Bs 704,20/);
    assert.match(aviso.cuerpo, /subió 4,20 \(\+0,60%\) desde la mañana/);
  });

  it('el mediodía dice sin cambios desde la mañana', () => {
    const aviso = construirAviso({
      ...base,
      anteriorCheckpoint: 700,
      momento: 'mediodia',
    });
    assert.match(aviso.cuerpo, /Sin cambios desde la mañana/);
  });

  it('la tarde cuenta el cambio desde el mediodía', () => {
    const aviso = construirAviso({
      actual: 690,
      anteriorCheckpoint: 700,
      anterior: 700,
      historial: historialDe([700, 700]),
      momento: 'tarde',
    });
    assert.match(aviso.titulo, /🕒 El dólar en la tarde: Bs 690,00/);
    assert.match(aviso.cuerpo, /bajó 10,00 \(-1,43%\) desde el mediodía/);
  });

  it('la tarde dice sin cambios desde el mediodía', () => {
    const aviso = construirAviso({
      ...base,
      anteriorCheckpoint: 700,
      momento: 'tarde',
    });
    assert.match(aviso.cuerpo, /Sin cambios desde el mediodía/);
  });

  it('sin checkpoint previo mide contra la última tasa conocida', () => {
    // El de las 8 no salió (falló, o la app se instaló a media mañana): el
    // mediodía sale igual, contra la tasa más reciente que se tenga.
    const aviso = construirAviso({
      actual: 704.2,
      anteriorCheckpoint: null,
      anterior: 700,
      historial: historialDe([700, 700]),
      momento: 'mediodia',
    });
    assert.match(aviso.cuerpo, /desde la mañana/);
    assert.equal(aviso.datos.anterior, '700');
  });

  it('sin ninguna tasa previa sale el primer aviso del día', () => {
    const aviso = construirAviso({
      actual: 700,
      anterior: null,
      anteriorCheckpoint: null,
      historial: historialDe([700]),
      momento: 'tarde',
    });
    assert.match(aviso.cuerpo, /Primer aviso del día/);
  });
});

describe('construirAviso · tasa paralela en la mañana', () => {
  const base = {
    anterior: 700,
    actual: 700,
    historial: historialDe([700, 700]),
    momento: 'manana',
  };

  it('el título lleva las dos tasas cuando hay paralela', () => {
    const aviso = construirAviso({ ...base, paralelo: 1234.5 });
    assert.match(aviso.titulo, /BCV Bs 700,00/);
    assert.match(aviso.titulo, /Paralelo Bs 1.234,50/);
    assert.equal(aviso.datos.paralelo, '1234.5');
  });

  it('sin paralela la mañana sale igual, solo que sin ella', () => {
    // La fuente de la paralela puede caerse: eso no puede tumbar el aviso de
    // la tasa oficial, que es el que el usuario pidió.
    const aviso = construirAviso({ ...base, paralelo: null });
    assert.match(aviso.titulo, /Hoy el dólar está en Bs 700,00/);
    assert.equal(aviso.datos.paralelo, '');
  });

  it('el cuerpo dice de dónde sale la paralela', () => {
    // El push y la app usan fuentes distintas y las cifras no coinciden. Sin
    // esta frase, el dueño abre la app tras el push, ve otro número y da por
    // hecho que una de las dos está mal.
    const aviso = construirAviso({ ...base, paralelo: 1234.5 });
    assert.match(aviso.cuerpo, /referencia/);
    assert.match(aviso.cuerpo, /mercado P2P/);
  });

  it('sin paralela el cuerpo no explica ninguna fuente', () => {
    const aviso = construirAviso({ ...base, paralelo: null });
    assert.doesNotMatch(aviso.cuerpo, /referencia/);
    assert.doesNotMatch(aviso.cuerpo, /P2P/);
  });

  it('una paralela absurda se descarta como si no hubiera', () => {
    for (const malo of [0, -5, NaN, Infinity]) {
      const aviso = construirAviso({ ...base, paralelo: malo });
      assert.equal(aviso.datos.paralelo, '', `paralelo=${malo}`);
    }
  });

  it('la paralela no se cuela en el mediodía ni en la tarde', () => {
    // La paralela solo se consulta en la mañana; si alguien la pasara igual,
    // no debe colarse en el aviso de las otras franjas.
    for (const momento of ['mediodia', 'tarde']) {
      const aviso = construirAviso({ ...base, momento, paralelo: 1234.5 });
      assert.equal(aviso.datos.paralelo, '', `momento=${momento}`);
      assert.doesNotMatch(aviso.titulo, /Paralelo/);
    }
  });
});

describe('esDiaHabilVE', () => {
  // Las fechas se dan en UTC; la función resta las 4 horas de Venezuela.
  it('de lunes a viernes sí', () => {
    for (const dia of ['10', '11', '12', '13', '14']) {
      const f = new Date(`2026-08-${dia}T14:00:00Z`);
      assert.equal(esDiaHabilVE(f), true, `2026-08-${dia}`);
    }
  });

  it('sábado y domingo no — el BCV no publica', () => {
    assert.equal(esDiaHabilVE(new Date('2026-08-15T14:00:00Z')), false);
    assert.equal(esDiaHabilVE(new Date('2026-08-16T14:00:00Z')), false);
  });

  it('se mide en Venezuela, no en UTC', () => {
    // Sábado 02:00 UTC es todavía viernes 22:00 en Venezuela: sí es hábil.
    assert.equal(esDiaHabilVE(new Date('2026-08-15T02:00:00Z')), true);
    // Sábado 05:00 UTC ya es sábado 01:00 allá: no lo es.
    assert.equal(esDiaHabilVE(new Date('2026-08-15T05:00:00Z')), false);
  });
});

describe('tasaEsDeHoy', () => {
  const martes = new Date('2026-08-11T12:00:00Z'); // 08:00 en Venezuela

  it('reconoce la tasa publicada hoy', () => {
    assert.equal(tasaEsDeHoy('2026-08-11T00:00:00-04:00', martes), true);
  });

  it('una tasa de ayer no es de hoy — el caso del feriado', () => {
    // Feriado en día hábil: el BCV no publica y la API repite la del viernes.
    assert.equal(tasaEsDeHoy('2026-08-10T00:00:00-04:00', martes), false);
  });

  it('sin fecha, o con una ilegible, no bloquea', () => {
    // Callar un aviso real por no saber leer un campo seria peor que
    // mandar uno de mas.
    assert.equal(tasaEsDeHoy(null, martes), true);
    assert.equal(tasaEsDeHoy('', martes), true);
    assert.equal(tasaEsDeHoy('cualquier cosa', martes), true);
  });
});
