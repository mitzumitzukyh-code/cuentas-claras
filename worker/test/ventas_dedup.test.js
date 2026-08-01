import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { huellaDeEnvio, mensajeResumenVentas } from '../src/ventas.js';

/**
 * El bug que cubren estas pruebas: un mismo teléfono figuraba como dueño en
 * varios negocios (cada negocio que se visita le graba el token en su
 * membresía y ninguno se lo quita), y el resumen sale UNO POR NEGOCIO. Con
 * cinco negocios sin ventas del día, los cinco textos son idénticos y al
 * teléfono le llegaban cinco copias de "👋 ¿Cómo va tu día?" a la vez.
 *
 * El dedup por KV no lo tapa: su clave es `resumenVentas:<negocioId>`, así que
 * cinco negocios son cinco claves distintas y las cinco pasan.
 */
describe('huellaDeEnvio', () => {
  const TOKEN = 'fcm-token-del-telefono';

  it('da la misma huella para el mismo texto en el mismo dispositivo', () => {
    // Dos negocios distintos, los dos sin ventas: el texto sale idéntico.
    const a = mensajeResumenVentas({ total: 0, cobros: 0 });
    const b = mensajeResumenVentas({ total: 0, cobros: 0 });

    assert.equal(
      huellaDeEnvio({ destino: TOKEN, titulo: a.titulo, cuerpo: a.cuerpo }),
      huellaDeEnvio({ destino: TOKEN, titulo: b.titulo, cuerpo: b.cuerpo }),
    );
  });

  it('distingue dos resúmenes con cifras distintas', () => {
    // Un dueño de dos bodegas de verdad tiene que seguir recibiendo las dos
    // cuentas: el dedup no puede tragarse la segunda.
    const a = mensajeResumenVentas({ total: 34, cobros: 7 });
    const b = mensajeResumenVentas({ total: 12, cobros: 2 });

    assert.notEqual(
      huellaDeEnvio({ destino: TOKEN, titulo: a.titulo, cuerpo: a.cuerpo }),
      huellaDeEnvio({ destino: TOKEN, titulo: b.titulo, cuerpo: b.cuerpo }),
    );
  });

  it('distingue el mismo texto en dos dispositivos', () => {
    const m = mensajeResumenVentas({ total: 0, cobros: 0 });

    assert.notEqual(
      huellaDeEnvio({ destino: TOKEN, titulo: m.titulo, cuerpo: m.cuerpo }),
      huellaDeEnvio({ destino: 'otro-token', titulo: m.titulo, cuerpo: m.cuerpo }),
    );
  });

  it('un conjunto de huellas colapsa la tanda de cinco negocios sin ventas', () => {
    const negocios = ['n1', 'n2', 'n3', 'n4', 'n5'];
    const enviadas = new Set();

    for (const _ of negocios) {
      const m = mensajeResumenVentas({ total: 0, cobros: 0 });
      enviadas.add(
        huellaDeEnvio({ destino: TOKEN, titulo: m.titulo, cuerpo: m.cuerpo }),
      );
    }

    assert.equal(enviadas.size, 1, 'debería salir un solo aviso, no cinco');
  });
});
