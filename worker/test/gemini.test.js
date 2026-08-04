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
  it('pasa las cifras COMO TEXTO, sin tocarlas', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        tipoDocumento: 'inventario',
        filas: [
          {
            nombre: ' Harina PAN 1kg ',
            codigo: 'HP-01',
            precio: '4.500,80',
            cantidad: '45',
            confianzaPrecio: 'alta',
            confianzaCantidad: 'alta',
          },
        ],
      }),
    );
    // El Worker NO normaliza: "4.500,80" llega intacto y lo interpreta Dart,
    // donde la regla es determinista y está probada. Pedirle la conversión al
    // modelo daba a veces 4.5 y a veces 450080.
    assert.equal(r.filas[0].precio, '4.500,80');
    assert.equal(r.filas[0].cantidad, '45');
    assert.equal(r.filas[0].codigo, 'HP-01');
    assert.equal(r.filas[0].nombre, 'Harina PAN 1kg');
  });

  it('descarta las filas sin nombre', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        filas: [
          { nombre: 'Arroz Diana', precio: '', cantidad: '30' },
          { nombre: '   ', precio: '3', cantidad: '1' },
        ],
      }),
    );
    assert.equal(r.filas.length, 1);
    assert.equal(r.filas[0].nombre, 'Arroz Diana');
    // Un campo que no se leyó viaja vacío, no como cero: cero es un valor.
    assert.equal(r.filas[0].precio, '');
  });

  it('la confianza es por campo y por defecto media', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        filas: [
          { nombre: 'Pasta', confianzaPrecio: 'baja' },
          { nombre: 'Aceite', confianzaPrecio: 'inventada' },
        ],
      }),
    );
    assert.equal(r.filas[0].confianzaPrecio, 'baja');
    assert.equal(r.filas[0].confianzaCantidad, 'media');
    assert.equal(r.filas[1].confianzaPrecio, 'media');
  });

  it('reconoce una factura de compra y conserva el total declarado', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        tipoDocumento: 'factura_compra',
        totalDeclarado: '423',
        filas: [{ nombre: 'Caja de jabón', precio: '12,00', cantidad: '10' }],
      }),
    );
    assert.equal(r.tipoDocumento, 'factura_compra');
    assert.equal(r.totalDeclarado, '423');
  });

  it('un tipo de documento inventado cae en desconocido', () => {
    const r = interpretarRespuestaLibreta(
      respuestaDe({
        esLista: true,
        tipoDocumento: 'recibo_de_luz',
        filas: [{ nombre: 'Algo' }],
      }),
    );
    assert.equal(r.tipoDocumento, 'desconocido');
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
