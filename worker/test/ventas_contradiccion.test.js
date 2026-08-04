import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { resumenesAEnviar } from '../src/ventas.js';

/**
 * El caso reportado en dispositivo: a las 21:02 llegaron juntas "Vendiste
 * $4,50 en 1 cobro hoy" y "Todavía no registras ventas hoy". No era desfase
 * horario ni cron duplicado: el dueño administra dos negocios y el resumen
 * sale uno por negocio, al mismo teléfono.
 */
describe('resumenesAEnviar', () => {
  const TELEFONO = 'token-del-telefono';
  const OTRO = 'token-de-otro-telefono';

  it('silencia el "sin ventas" cuando otro negocio del mismo teléfono vendió', () => {
    const pendientes = [
      { negocioId: 'electronico-jt', pushToken: TELEFONO, cobros: 1, total: 4.5 },
      { negocioId: 'sucursal-2', pushToken: TELEFONO, cobros: 0, total: 0 },
    ];
    const enviar = resumenesAEnviar(pendientes);
    assert.equal(enviar.length, 1);
    assert.equal(enviar[0].negocioId, 'electronico-jt');
  });

  it('el orden no importa: el silencio se decide con el cuadro completo', () => {
    const pendientes = [
      { negocioId: 'sucursal-2', pushToken: TELEFONO, cobros: 0, total: 0 },
      { negocioId: 'electronico-jt', pushToken: TELEFONO, cobros: 3, total: 12 },
    ];
    const enviar = resumenesAEnviar(pendientes);
    assert.deepEqual(
      enviar.map((p) => p.negocioId),
      ['electronico-jt'],
    );
  });

  it('dos negocios con ventas mandan sus dos resúmenes', () => {
    const pendientes = [
      { negocioId: 'a', pushToken: TELEFONO, cobros: 1, total: 4.5 },
      { negocioId: 'b', pushToken: TELEFONO, cobros: 2, total: 9 },
    ];
    assert.equal(resumenesAEnviar(pendientes).length, 2);
  });

  it('un teléfono sin ventas en ninguno sí recibe el recordatorio', () => {
    const pendientes = [
      { negocioId: 'a', pushToken: TELEFONO, cobros: 0, total: 0 },
      { negocioId: 'b', pushToken: TELEFONO, cobros: 0, total: 0 },
    ];
    // Los dos pasan el filtro; que el teléfono no reciba la MISMA frase dos
    // veces lo resuelve `huellaDeEnvio` aguas abajo.
    assert.equal(resumenesAEnviar(pendientes).length, 2);
  });

  it('lo que vendió un teléfono no silencia a otro teléfono', () => {
    const pendientes = [
      { negocioId: 'a', pushToken: TELEFONO, cobros: 1, total: 4.5 },
      { negocioId: 'b', pushToken: OTRO, cobros: 0, total: 0 },
    ];
    const enviar = resumenesAEnviar(pendientes);
    assert.deepEqual(
      enviar.map((p) => p.negocioId),
      ['a', 'b'],
    );
  });

  it('sin pendientes no manda nada', () => {
    assert.deepEqual(resumenesAEnviar([]), []);
  });
});
