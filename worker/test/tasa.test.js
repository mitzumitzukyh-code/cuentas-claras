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
  rachaDeSubidas,
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
    // 0,2 % está por debajo del 0,5 % mínimo.
    const avisos = construirAvisos({ ...base, anterior: 700, actual: 701.4 });
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
    // +3,4 % alcanza medio, uno y tres, pero no cinco.
    const [aviso] = construirAvisos({ ...base, anterior: 700, actual: 723.8 });
    assert.deepEqual(aviso.topics, [
      'tasa-subida-medio',
      'tasa-subida-uno',
      'tasa-subida-tres',
    ]);
  });

  it('un cambio pequeño solo alcanza el umbral más bajo', () => {
    const [aviso] = construirAvisos({ ...base, anterior: 700, actual: 705 });
    assert.deepEqual(aviso.topics, ['tasa-subida-medio']);
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
});
