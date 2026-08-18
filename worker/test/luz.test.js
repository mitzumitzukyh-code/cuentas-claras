/**
 * El cronograma de cortes: la parte que se puede equivocar en silencio.
 *
 * Un aviso con la hora cambiada es peor que no avisar — el dueño deja la
 * nevera abierta o cierra tarde—, así que la rotación y, sobre todo, los
 * bordes del mes se prueban aquí.
 */

import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  avisosDeCorte,
  avisosDePrueba,
  cronogramaResuelto,
  enHoraVenezuela,
  estadosConCronograma,
  hora12,
  topicDe,
} from '../src/luz.js';

/** Un instante UTC a partir de una hora de Venezuela (UTC−4). */
function enVenezuela(fecha, hora, minuto = 0) {
  return new Date(`${fecha}T${String(hora + 4).padStart(2, '0')}:` +
    `${String(minuto).padStart(2, '0')}:00Z`);
}

const barinas = cronogramaResuelto('barinas');

describe('cronogramaResuelto', () => {
  it('conoce Barinas y nada más, por ahora', () => {
    assert.deepEqual(estadosConCronograma(), ['barinas']);
    assert.equal(cronogramaResuelto('zulia'), null);
    assert.equal(cronogramaResuelto(''), null);
  });

  it('cubre los 28 días del cronograma y ni uno más', () => {
    const fechas = Object.keys(barinas.dias);
    assert.equal(fechas.length, 28);
    assert.equal(fechas[0], '2026-08-03');
    assert.equal(fechas.at(-1), '2026-08-30');
  });

  it('cada día le toca a los cuatro bloques, uno por franja', () => {
    for (const [fecha, porBloque] of Object.entries(barinas.dias)) {
      const franjas = Object.values(porBloque);
      assert.equal(franjas.length, 4, `${fecha} no reparte los cuatro bloques`);
      assert.equal(
        new Set(franjas).size,
        4,
        `${fecha} le da la misma franja a dos bloques`,
      );
    }
  });

  // El caso del usuario, y el que se puede contrastar con el papel.
  it('al bloque A le toca lo que dice el cronograma impreso', () => {
    assert.equal(barinas.dias['2026-08-03'].A, '08-13'); // lunes, semana 1
    assert.equal(barinas.dias['2026-08-04'].A, '03-08'); // martes
    assert.equal(barinas.dias['2026-08-05'].A, '18-23'); // miércoles
    assert.equal(barinas.dias['2026-08-13'].A, '18-23'); // jueves, semana 2
    assert.equal(barinas.dias['2026-08-17'].A, '18-23'); // lunes, semana 3
    assert.equal(barinas.dias['2026-08-24'].A, '03-08'); // lunes, semana 4
    assert.equal(barinas.dias['2026-08-30'].A, '13-18'); // domingo, semana 4
  });

  it('el corte se adelanta una franja cada día', () => {
    // Es la rotación que se leyó del papel; si un mes futuro no la cumple,
    // esta prueba no debe "arreglarse": el cronograma manda sobre el patrón.
    const orden = ['03-08', '08-13', '13-18', '18-23'];
    const fechas = Object.keys(barinas.dias);
    for (let i = 1; i < fechas.length; i++) {
      const ayer = orden.indexOf(barinas.dias[fechas[i - 1]].A);
      const hoy = orden.indexOf(barinas.dias[fechas[i]].A);
      assert.equal(hoy, (ayer + 3) % 4, `no rota entre ${fechas[i - 1]} y ${fechas[i]}`);
    }
  });

  it('las franjas viajan con sus horas, no solo con la clave', () => {
    // La app pinta «6:00 pm a 11:00 pm» a partir de estos números; el `id` es
    // una clave interna y nadie se lo enseña al dueño.
    const tarde = barinas.franjas.find((f) => f.id === '18-23');
    assert.equal(tarde.desde, 18);
    assert.equal(tarde.hasta, 23);
  });

  it('trae los sectores de cada bloque para poder elegir el tuyo', () => {
    assert.deepEqual(Object.keys(barinas.sectores).sort(), ['A', 'B', 'C', 'D']);
    assert.ok(barinas.sectores.A.includes('Centro'));
    assert.ok(barinas.sectores.D.includes('Industrial'));
    for (const [bloque, lista] of Object.entries(barinas.sectores)) {
      assert.equal(
        new Set(lista).size,
        lista.length,
        `el bloque ${bloque} repite un sector`,
      );
    }
  });

  it('un sector no está en dos bloques a la vez', () => {
    const vistos = new Map();
    for (const [bloque, lista] of Object.entries(barinas.sectores)) {
      for (const sector of lista) {
        assert.ok(
          !vistos.has(sector),
          `${sector} está en ${vistos.get(sector)} y en ${bloque}`,
        );
        vistos.set(sector, bloque);
      }
    }
  });

  it('declara hasta cuándo vale, que es lo que calla a la app', () => {
    assert.equal(barinas.desde, '2026-08-03');
    assert.equal(barinas.hasta, '2026-08-30');
    // Fuera del rango no hay entradas: la app no tiene de dónde sacar una
    // hora inventada para el 31.
    assert.equal(barinas.dias['2026-08-31'], undefined);
    assert.equal(barinas.dias['2026-08-02'], undefined);
  });
});

/**
 * El viernes 14 de agosto de 2026 el cronograma reparte así:
 * bloque C de 3 a 8 am, D de 8 am a 1 pm, A de 1 a 6 pm, B de 6 a 11 pm.
 */
describe('avisosDeCorte', () => {
  it('traduce la hora UTC a la de Venezuela', () => {
    const r = enHoraVenezuela(new Date('2026-08-14T16:30:00Z'));
    assert.deepEqual(r, { fecha: '2026-08-14', hora: 12, minuto: 30 });
  });

  it('el cambio de día se cuenta en hora venezolana, no en UTC', () => {
    // Las 10 pm del 14 en Venezuela son las 2 am del 15 en UTC. Si el corte
    // se buscara con la fecha UTC, el aviso saldría con el cronograma del
    // día siguiente.
    const r = enHoraVenezuela(new Date('2026-08-15T02:00:00Z'));
    assert.equal(r.fecha, '2026-08-14');
    assert.equal(r.hora, 22);
  });

  it('avisa media hora antes del corte, y a un solo bloque', () => {
    const avisos = avisosDeCorte(enVenezuela('2026-08-14', 12, 30));
    assert.equal(avisos.length, 1);
    assert.equal(avisos[0].topic, 'luz-barinas-a');
    assert.match(avisos[0].titulo, /1:00 pm/);
    assert.match(avisos[0].cuerpo, /1:00 pm a 6:00 pm/);
    assert.equal(avisos[0].datos.cuando, 'antes');
  });

  it('avisa a la hora en que debería volver', () => {
    // A las 6:00 pm se le acaba el corte al bloque A.
    const avisos = avisosDeCorte(enVenezuela('2026-08-14', 18, 0));
    const deA = avisos.find((a) => a.topic === 'luz-barinas-a');
    assert.ok(deA, 'al bloque A le toca el aviso de vuelta');
    assert.match(deA.titulo, /debería haber vuelto/);
    assert.equal(deA.datos.cuando, 'vuelta');
  });

  it('no dice nada en una pasada cualquiera del cron', () => {
    assert.deepEqual(avisosDeCorte(enVenezuela('2026-08-14', 15, 0)), []);
    assert.deepEqual(avisosDeCorte(enVenezuela('2026-08-14', 12, 0)), []);
  });

  // Mandarlo tarde es peor que no mandarlo: «se va la luz en 30 minutos»
  // media hora después de que se fue enseña a ignorar la app.
  it('no arrastra el aviso a la pasada siguiente', () => {
    assert.deepEqual(avisosDeCorte(enVenezuela('2026-08-14', 13, 0))
      .filter((a) => a.datos.cuando === 'antes'), []);
  });

  it('fuera del cronograma no manda nada', () => {
    assert.deepEqual(avisosDeCorte(enVenezuela('2026-08-31', 12, 30)), []);
    assert.deepEqual(avisosDeCorte(enVenezuela('2026-09-15', 12, 30)), []);
  });

  it('cada bloque recibe el suyo, a su hora', () => {
    // Al bloque D, que ese día va de 8 am a 1 pm, le toca a las 7:30 am.
    const temprano = avisosDeCorte(enVenezuela('2026-08-14', 7, 30));
    assert.equal(temprano.length, 1);
    assert.equal(temprano[0].topic, 'luz-barinas-d');
  });

  it('el topic lleva estado y bloque, en minúscula', () => {
    assert.equal(topicDe('barinas', 'A'), 'luz-barinas-a');
    assert.equal(topicDe('barinas', 'd'), 'luz-barinas-d');
  });

  it('un estado sin cronograma no genera avisos', () => {
    assert.deepEqual(avisosDeCorte(new Date(), { estado: 'zulia' }), []);
  });
});

describe('los textos que llegan al teléfono', () => {
  it('nunca llevan hora militar', () => {
    assert.equal(hora12(13), '1:00 pm');
    assert.equal(hora12(23), '11:00 pm');
    assert.equal(hora12(3), '3:00 am');
    assert.equal(hora12(12), '12:00 pm');
    assert.equal(hora12(0), '12:00 am');

    for (const hora of [0, 30]) {
      for (const aviso of avisosDeCorte(enVenezuela('2026-08-14', 12, hora))) {
        assert.ok(!/\b(1[3-9]|2[0-4]):/.test(aviso.titulo + aviso.cuerpo));
      }
    }
  });
});

describe('avisosDePrueba', () => {
  it('manda uno por bloque sin mirar la hora, y se identifica', () => {
    const avisos = avisosDePrueba(enVenezuela('2026-08-14', 15, 12));
    assert.equal(avisos.length, 4);
    for (const a of avisos) {
      assert.match(a.titulo, /Prueba/);
      assert.equal(a.datos.cuando, 'prueba');
    }
  });

  it('fuera del cronograma tampoco inventa nada', () => {
    assert.deepEqual(avisosDePrueba(enVenezuela('2026-09-01', 15, 0)), []);
  });
});
