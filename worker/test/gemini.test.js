/**
 * Pruebas de la interpretación de la respuesta de Gemini. Sin red: se le dan
 * respuestas de ejemplo, con la misma forma que devuelve la API de verdad.
 */

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { interpretarRespuestaGemini } from '../src/gemini.js';

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
      confianza: 'alta',
    });
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
