/**
 * Pruebas de la lógica de avisos. Sin red, sin Cloudflare, sin FCM.
 *
 * Lo que se está protegiendo es la confianza del usuario: un aviso de más
 * entrena a ignorar la app, y uno de menos le hace perder plata. Por eso el
 * grueso de los casos son de "aquí NO se avisa".
 *
 * Ejecutar:  npm test
 */

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  construirAvisos,
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

describe('construirAvisos', () => {
  const base = { historial: historialDe([700, 700]), esResumen: false };

  it('no avisa nada si la tasa no se movió', () => {
    const avisos = construirAvisos({ ...base, anterior: 700, actual: 700 });
    assert.equal(avisos.length, 0);
  });

  it('no avisa por un cambio por debajo del umbral más bajo', () => {
    // 0,05 % está por debajo del 0,1 % mínimo.
    const avisos = construirAvisos({ ...base, anterior: 700, actual: 700.35 });
    assert.equal(avisos.length, 0);
  });

  it('no avisa en la primera ejecución, sin tasa previa', () => {
    // Sin `anterior` no hay variación que contar: avisar aquí seria ruido.
    const avisos = construirAvisos({ ...base, anterior: null, actual: 700 });
    assert.equal(avisos.length, 0);
  });

  it('avisa de subida y acierta el texto', () => {
    const [aviso] = construirAvisos({
      ...base,
      anterior: 732.48,
      actual: 745.2,
    });
    assert.equal(aviso.titulo, '📈 El dólar subió');
    assert.match(aviso.cuerpo, /Bs 745,20/);
    assert.match(aviso.cuerpo, /\+12,72/);
    assert.match(aviso.cuerpo, /\+1,74%/);
    assert.equal(aviso.datos.tipo, 'subida');
  });

  it('avisa de bajada con el signo correcto', () => {
    const [aviso] = construirAvisos({ ...base, anterior: 700, actual: 686 });
    assert.equal(aviso.titulo, '📉 El dólar bajó');
    assert.match(aviso.cuerpo, /−14,00/);
    assert.match(aviso.cuerpo, /-2,00%/);
  });

  it('publica en todos los umbrales que la variación supera', () => {
    // +3,4 % alcanza minimo, medio, uno y tres, pero no cinco.
    const [aviso] = construirAvisos({ ...base, anterior: 700, actual: 723.8 });
    assert.deepEqual(aviso.topics, [
      'tasa-subida-minimo',
      'tasa-subida-medio',
      'tasa-subida-uno',
      'tasa-subida-tres',
    ]);
  });

  it('un cambio pequeño solo alcanza el umbral más bajo', () => {
    // 0,3 % supera "minimo" (0,1 %) pero no "medio" (0,5 %).
    const [aviso] = construirAvisos({ ...base, anterior: 700, actual: 702.1 });
    assert.deepEqual(aviso.topics, ['tasa-subida-minimo']);
  });

  it('avisa del ritmo tras varios días seguidos subiendo', () => {
    const avisos = construirAvisos({
      anterior: 730,
      actual: 740,
      historial: historialDe([700, 710, 720, 730, 740]),
      esResumen: false,
    });
    const ritmo = avisos.find((a) => a.datos.tipo === 'ritmo');
    assert.ok(ritmo, 'esperaba un aviso de ritmo');
    assert.match(ritmo.cuerpo, /días seguidos subiendo/);
    assert.deepEqual(ritmo.topics, ['tasa-ritmo']);
  });

  it('no avisa del ritmo por un salto aislado', () => {
    // Un solo día fuerte ya lo cubre el aviso de subida; repetirlo como
    // "ritmo" seria mandar dos notificaciones por el mismo hecho.
    const avisos = construirAvisos({
      anterior: 700,
      actual: 730,
      historial: historialDe([700, 700, 700, 730]),
      esResumen: false,
    });
    assert.equal(avisos.filter((a) => a.datos.tipo === 'ritmo').length, 0);
  });

  it('el resumen sale aunque no haya cambio', () => {
    const avisos = construirAvisos({
      anterior: 732.48,
      actual: 732.48,
      historial: historialDe([732.48, 732.48]),
      esResumen: true,
    });
    assert.equal(avisos.length, 1);
    assert.match(avisos[0].titulo, /Hoy el dólar está en Bs 732,48/);
    assert.match(avisos[0].cuerpo, /sin cambios desde ayer/);
  });

  it('el resumen cuenta el movimiento cuando lo hubo', () => {
    const avisos = construirAvisos({
      anterior: 700,
      actual: 714,
      historial: historialDe([700, 714]),
      esResumen: true,
    });
    const resumen = avisos.find((a) => a.datos.tipo === 'resumen');
    assert.match(resumen.cuerpo, /subió 14,00/);
  });

  it('el resumen dice "estable" cuando la semana estuvo quieta', () => {
    const avisos = construirAvisos({
      anterior: 732.48,
      actual: 732.48,
      historial: historialDe([732.48, 732.48, 732.48]),
      esResumen: true,
    });
    assert.match(avisos[0].cuerpo, /estable esta semana/);
  });

  it('el resumen anticipa la subida cuando viene acelerando', () => {
    const avisos = construirAvisos({
      anterior: 730,
      actual: 740,
      historial: historialDe([700, 710, 720, 730, 740]),
      esResumen: true,
    });
    const resumen = avisos.find((a) => a.datos.tipo === 'resumen');
    assert.match(resumen.cuerpo, /apunta a seguir subiendo/);
  });

  it('el resumen menciona la bajada semanal', () => {
    const avisos = construirAvisos({
      anterior: 700,
      actual: 700,
      historial: historialDe([710, 705, 700]),
      esResumen: true,
    });
    const resumen = avisos.find((a) => a.datos.tipo === 'resumen');
    assert.match(resumen.cuerpo, /Viene bajando/);
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

describe('construirAvisos · tasa paralela en el resumen', () => {
  const base = {
    anterior: 700,
    actual: 700,
    historial: historialDe([700, 700]),
    esResumen: true,
  };

  it('el título lleva las dos tasas cuando hay paralela', () => {
    const [resumen] = construirAvisos({ ...base, paralelo: 1234.5 });
    assert.match(resumen.titulo, /BCV Bs 700,00/);
    assert.match(resumen.titulo, /Paralelo Bs 1.234,50/);
    assert.equal(resumen.datos.paralelo, '1234.5');
  });

  it('sin paralela el resumen sale igual, solo que sin ella', () => {
    // Binance puede cortar por rate-limit: eso no puede tumbar el aviso de la
    // tasa oficial, que es el que el usuario pidió.
    const [resumen] = construirAvisos({ ...base, paralelo: null });
    assert.match(resumen.titulo, /Hoy el dólar está en Bs 700,00/);
    assert.equal(resumen.datos.paralelo, '');
  });

  it('una paralela absurda se descarta como si no hubiera', () => {
    for (const malo of [0, -5, NaN, Infinity]) {
      const [resumen] = construirAvisos({ ...base, paralelo: malo });
      assert.equal(resumen.datos.paralelo, '', `paralelo=${malo}`);
    }
  });

  it('la paralela no se cuela en los avisos de subida', () => {
    // Los umbrales y sus topics son del BCV; mezclar la paralela ahí haria que
    // un salto del mercado P2P disparara el aviso del dólar oficial.
    const avisos = construirAvisos({
      anterior: 700,
      actual: 750,
      historial: historialDe([700, 750]),
      esResumen: false,
      paralelo: 1234.5,
    });
    assert.ok(avisos.length > 0);
    for (const a of avisos) {
      assert.equal(a.datos.paralelo, undefined);
    }
  });
});
