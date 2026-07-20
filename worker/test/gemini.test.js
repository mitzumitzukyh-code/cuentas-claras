/**
 * Pruebas de la interpretación de la respuesta de Gemini. Sin red: se le dan
 * respuestas de ejemplo, con la misma forma que devuelve la API de verdad.
 */

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  interpretarRespuestaGemini,
  interpretarRespuestaLibreta,
  interpretarRespuestaRecibo,
} from '../src/gemini.js';

function respuestaDe(objeto) {
  return {
    candidates: [
      { content: { parts: [{ text: JSON.stringify(objeto) }] } },
    ],
  };
}

describe('interpretarRespuestaGemini', () => {
  it('devuelve el nombre sugerido cuando reconoce el producto', () => {
    const r = interpretarRespuestaGemini(
      respuestaDe({
        esProducto: true,
        nombreSugerido: 'Harina PAN 1kg',
        confianza: 'alta',
      }),
    );
    assert.deepEqual(r, {
      reconocido: true,
      nombreSugerido: 'Harina PAN 1kg',
      presentacion: null,
      categoriaSugerida: null,
      confianza: 'alta',
    });
  });

  it('acepta la categoría solo si está en la lista de la tienda', () => {
    const r = interpretarRespuestaGemini(
      respuestaDe({
        esProducto: true,
        nombreSugerido: 'Harina PAN 1kg',
        categoriaSugerida: 'víveres',
        presentacion: '1kg',
        confianza: 'alta',
      }),
      ['Víveres', 'Bebidas'],
    );
    // Devuelve la de la lista tal cual está escrita, no la del modelo.
    assert.equal(r.categoriaSugerida, 'Víveres');
    assert.equal(r.presentacion, '1kg');
  });

  it('descarta una categoría que no existe en la tienda', () => {
    const r = interpretarRespuestaGemini(
      respuestaDe({
        esProducto: true,
        nombreSugerido: 'Harina PAN 1kg',
        categoriaSugerida: 'Panadería',
        confianza: 'alta',
      }),
      ['Víveres', 'Bebidas'],
    );
    assert.equal(r.categoriaSugerida, null);
  });

  it('recorta espacios sueltos del nombre', () => {
    const r = interpretarRespuestaGemini(
      respuestaDe({
        esProducto: true,
        nombreSugerido: '  Refresco Cola 2L  ',
        confianza: 'media',
      }),
    );
    assert.equal(r.nombreSugerido, 'Refresco Cola 2L');
  });

  it('marca como no reconocido cuando esProducto es false', () => {
    const r = interpretarRespuestaGemini(
      respuestaDe({ esProducto: false, nombreSugerido: '', confianza: 'baja' }),
    );
    assert.deepEqual(r, { reconocido: false });
  });

  it('no reconoce si el nombre viene vacío aunque diga esProducto=true', () => {
    // Defensivo: un modelo puede alucinar la combinación "es producto pero
    // sin nombre". Sin nombre no hay nada que ofrecerle al usuario.
    const r = interpretarRespuestaGemini(
      respuestaDe({ esProducto: true, nombreSugerido: '   ', confianza: 'alta' }),
    );
    assert.deepEqual(r, { reconocido: false });
  });

  it('usa "media" si la confianza viene fuera del rango esperado', () => {
    const r = interpretarRespuestaGemini(
      respuestaDe({
        esProducto: true,
        nombreSugerido: 'Jabón de baño',
        confianza: 'segurísimo',
      }),
    );
    assert.equal(r.confianza, 'media');
  });

  it('falla con un mensaje claro si no hay candidates', () => {
    assert.throws(
      () => interpretarRespuestaGemini({}),
      /no devolvió contenido/,
    );
  });

  it('falla con un mensaje claro si el texto no es JSON', () => {
    assert.throws(
      () =>
        interpretarRespuestaGemini({
          candidates: [{ content: { parts: [{ text: 'no soy json' }] } }],
        }),
      /JSON válido/,
    );
  });
});

describe('interpretarRespuestaLibreta', () => {
  it('devuelve filas limpias y descarta las sin nombre', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        filas: [
          { nombre: ' Harina PAN 1kg ', precio: 1.2, cantidad: 45 },
          { nombre: 'Arroz Diana', precio: null, cantidad: 30 },
          { nombre: '   ', precio: 3, cantidad: 1 },
        ],
      }),
    );
    assert.deepEqual(r, {
      reconocido: true,
      filas: [
        { nombre: 'Harina PAN 1kg', precio: 1.2, cantidad: 45 },
        { nombre: 'Arroz Diana', precio: null, cantidad: 30 },
      ],
    });
  });

  it('descarta precios y cantidades absurdos (cero o negativos)', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        filas: [{ nombre: 'Pasta', precio: -2, cantidad: 0 }],
      }),
    );
    assert.deepEqual(r.filas, [{ nombre: 'Pasta', precio: null, cantidad: null }]);
  });

  it('no reconoce cuando la foto no es una lista', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({ esLista: false, filas: [] }),
    );
    assert.deepEqual(r, { reconocido: false, filas: [] });
  });
});

describe('interpretarRespuestaRecibo', () => {
  it('devuelve los datos del recibo listos para prellenar', () => {
    const r = interpretarRespuestaRecibo(
      respuestaDe({
        esRecibo: true,
        monto: 35.5,
        moneda: 'USD',
        fecha: '2026-07-18',
        descripcion: 'Mercancía distribuidora',
        categoria: 'mercancia',
      }),
    );
    assert.deepEqual(r, {
      reconocido: true,
      monto: 35.5,
      moneda: 'USD',
      fecha: '2026-07-18',
      descripcion: 'Mercancía distribuidora',
      categoria: 'mercancia',
    });
  });

  it('anula la fecha si no viene como YYYY-MM-DD', () => {
    const r = interpretarRespuestaRecibo(
      respuestaDe({ esRecibo: true, monto: 10, fecha: '18/07/2026' }),
    );
    assert.equal(r.fecha, null);
  });

  it('descarta una categoría fuera de las cuatro del brief', () => {
    const r = interpretarRespuestaRecibo(
      respuestaDe({ esRecibo: true, monto: 10, categoria: 'nómina' }),
    );
    assert.equal(r.categoria, null);
  });

  it('no reconoce cuando la foto no es un recibo', () => {
    const r = interpretarRespuestaRecibo(respuestaDe({ esRecibo: false }));
    assert.deepEqual(r, { reconocido: false });
  });
});
