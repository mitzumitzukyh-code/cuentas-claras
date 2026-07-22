import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { construirAvisoStock } from '../src/stock.js';

describe('construirAvisoStock', () => {
  it('no arma nada si no hay productos nuevos en stock bajo', () => {
    assert.equal(construirAvisoStock([]), null);
    assert.equal(construirAvisoStock(null), null);
    assert.equal(construirAvisoStock(undefined), null);
  });

  it('un solo agotado usa su nombre en el título', () => {
    const a = construirAvisoStock([
      { nombre: 'Harina PAN', cantidad: 0, agotado: true },
    ]);
    assert.equal(a.titulo, '🛑 Harina PAN se agotó');
    assert.equal(a.cuerpo, 'Harina PAN');
    assert.equal(a.datos.tipo, 'stock');
    assert.equal(a.datos.agotados, '1');
    assert.equal(a.datos.porAgotarse, '0');
  });

  it('varios agotados cuentan en el título y listan hasta 3 en el cuerpo', () => {
    const a = construirAvisoStock([
      { nombre: 'Arroz', cantidad: 0, agotado: true },
      { nombre: 'Café', cantidad: 0, agotado: true },
      { nombre: 'Azúcar', cantidad: 0, agotado: true },
      { nombre: 'Sal', cantidad: 0, agotado: true },
    ]);
    assert.equal(a.titulo, '🛑 4 productos se agotaron');
    assert.equal(a.cuerpo, 'Arroz, Café, Azúcar');
    assert.equal(a.datos.agotados, '4');
  });

  it('sin agotados, avisa de los que quedan por agotarse', () => {
    const a = construirAvisoStock([
      { nombre: 'Aceite', cantidad: 2, agotado: false },
    ]);
    assert.equal(a.titulo, '⚠️ Queda poco de Aceite');
    assert.equal(a.cuerpo, 'Aceite');
    assert.equal(a.datos.agotados, '0');
    assert.equal(a.datos.porAgotarse, '1');
  });

  it('agotado manda en el título y menciona los por agotarse en el cuerpo', () => {
    const a = construirAvisoStock([
      { nombre: 'Leche', cantidad: 0, agotado: true },
      { nombre: 'Pan', cantidad: 3, agotado: false },
      { nombre: 'Huevos', cantidad: 5, agotado: false },
    ]);
    assert.equal(a.titulo, '🛑 Leche se agotó');
    assert.equal(a.cuerpo, 'Leche. Y 2 por agotarse.');
    assert.equal(a.datos.agotados, '1');
    assert.equal(a.datos.porAgotarse, '2');
  });
});
