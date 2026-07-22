import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { mensajeResumenVentas } from '../src/ventas.js';

describe('mensajeResumenVentas', () => {
  it('invita a usar la app en vez de decir "vendiste $0" si no hubo cobros', () => {
    const m = mensajeResumenVentas({ total: 0, cobros: 0 });
    assert.equal(m.titulo, '👋 ¿Cómo va tu día?');
    assert.match(m.cuerpo, /Todavía no registras ventas hoy/);
    assert.equal(m.datos.tipo, 'recordatorio_ventas');
  });

  it('arma el texto con el total y la cantidad de cobros', () => {
    const m = mensajeResumenVentas({ total: 34, cobros: 7 });
    assert.equal(m.titulo, '🌙 Cierre del día');
    assert.equal(m.cuerpo, 'Vendiste $34.00 en 7 cobros hoy.');
    assert.equal(m.datos.tipo, 'resumen_ventas');
  });

  it('usa singular con un solo cobro', () => {
    const m = mensajeResumenVentas({ total: 2, cobros: 1 });
    assert.match(m.cuerpo, /1 cobro hoy\.$/);
  });
});
