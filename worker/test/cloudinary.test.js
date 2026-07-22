/**
 * Pruebas de la subida de fotos. `subirFotoFirmada` se prueba con `fetch`
 * reemplazado (sin red real) para comprobar que firma y arma la petición
 * como Cloudinary la espera; ver la doc de firmas:
 * https://cloudinary.com/documentation/authentication_signatures
 */

import assert from 'node:assert/strict';
import { afterEach, describe, it } from 'node:test';

import { carpetaValida, subirFotoFirmada } from '../src/cloudinary.js';

describe('carpetaValida', () => {
  it('acepta la carpeta de fotos de producto', () => {
    assert.equal(carpetaValida('cuenta-clara/abc123XYZ/productos'), true);
  });

  it('acepta la carpeta de fotos de recibo', () => {
    assert.equal(carpetaValida('cuenta-clara/abc123XYZ/recibos'), true);
  });

  it('acepta la carpeta de foto de perfil del negocio', () => {
    assert.equal(carpetaValida('cuenta-clara/abc123XYZ/perfil'), true);
  });

  it('rechaza una carpeta con un tercer segmento inventado', () => {
    assert.equal(carpetaValida('cuenta-clara/abc123XYZ/lo-que-sea'), false);
  });

  it('rechaza intentos de escapar a otra ruta', () => {
    assert.equal(carpetaValida('cuenta-clara/../otra-cosa/productos'), false);
  });

  it('rechaza valores que no son string', () => {
    assert.equal(carpetaValida(null), false);
    assert.equal(carpetaValida(undefined), false);
  });
});

describe('subirFotoFirmada', () => {
  const original = globalThis.fetch;
  afterEach(() => {
    globalThis.fetch = original;
  });

  it('firma con los mismos parámetros que envía y nunca manda la API Secret', async () => {
    let cuerpoEnviado;
    globalThis.fetch = async (_url, init) => {
      cuerpoEnviado = new URLSearchParams(init.body);
      return {
        ok: true,
        json: async () => ({ secure_url: 'https://res.cloudinary.com/foo.jpg' }),
      };
    };

    const url = await subirFotoFirmada({
      cloudName: 'jwahaxid',
      apiKey: 'clave-publica',
      apiSecret: 'secreto-de-verdad',
      imagenBase64: 'ZmFrZQ==',
      mimeType: 'image/jpeg',
      carpeta: 'cuenta-clara/negocio1/productos',
    });

    assert.equal(url, 'https://res.cloudinary.com/foo.jpg');
    assert.equal(cuerpoEnviado.get('api_key'), 'clave-publica');
    assert.equal(cuerpoEnviado.get('folder'), 'cuenta-clara/negocio1/productos');
    assert.match(cuerpoEnviado.get('file'), /^data:image\/jpeg;base64,ZmFrZQ==$/);
    // La API Secret firma, pero no viaja en el cuerpo.
    assert.equal([...cuerpoEnviado.values()].some((v) => v.includes('secreto-de-verdad')), false);
    // SHA-1 en hex son 40 caracteres.
    assert.match(cuerpoEnviado.get('signature'), /^[0-9a-f]{40}$/);
  });

  it('lanza un error legible si Cloudinary rechaza la subida', async () => {
    globalThis.fetch = async () => ({
      ok: false,
      status: 400,
      text: async () => '{"error":{"message":"bad request"}}',
    });

    await assert.rejects(
      () =>
        subirFotoFirmada({
          cloudName: 'jwahaxid',
          apiKey: 'k',
          apiSecret: 's',
          imagenBase64: 'ZmFrZQ==',
          mimeType: 'image/jpeg',
          carpeta: 'cuenta-clara/negocio1/productos',
        }),
      /Cloudinary respondió 400/,
    );
  });
});
