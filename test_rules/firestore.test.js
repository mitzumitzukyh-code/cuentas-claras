/**
 * Pruebas de las reglas de seguridad de Firestore (../firestore.rules).
 *
 * El principio que se está protegiendo (CLAUDE.md §4): ningún usuario puede
 * leer ni escribir datos de un negocio donde no tenga membresía. Y como la
 * membresía ES el permiso, crear una membresía tiene que ser más difícil que
 * simplemente declararse miembro.
 *
 * Ejecutar con:  npm install && npm test
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  Timestamp,
} = require('firebase/firestore');

const DUENO = 'uid_dueno';
const EMPLEADO = 'uid_empleado';
const INTRUSO = 'uid_intruso';
const NEGOCIO = 'negocio_1';

let testEnv;

/** Firestore autenticado como [uid]. */
function como(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

const membresiaId = (uid, negocioId) => `${uid}_${negocioId}`;

/** Fecha futura/pasada como Timestamp, para las invitaciones. */
const enHoras = (h) =>
  Timestamp.fromDate(new Date(Date.now() + h * 60 * 60 * 1000));

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'cuenta-clara-test',
    firestore: {
      rules: fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

/**
 * Estado de partida de cada prueba: un negocio fundado por DUENO, con EMPLEADO
 * dentro y un producto. Se siembra saltándose las reglas.
 */
beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'negocios', NEGOCIO), {
      nombre: 'Bodega La Esquina',
      rubro: 'bodega',
      creadoPor: DUENO,
    });
    await setDoc(doc(db, 'membresias', membresiaId(DUENO, NEGOCIO)), {
      usuarioId: DUENO,
      negocioId: NEGOCIO,
      rol: 'dueno',
    });
    await setDoc(doc(db, 'membresias', membresiaId(EMPLEADO, NEGOCIO)), {
      usuarioId: EMPLEADO,
      negocioId: NEGOCIO,
      rol: 'empleado',
    });
    await setDoc(doc(db, 'negocios', NEGOCIO, 'productos', 'p1'), {
      nombre: 'Harina',
      precio: 1.5,
      cantidad: 10,
    });
    await setDoc(doc(db, 'negocios', NEGOCIO, 'gastos', 'g1'), {
      categoria: 'mercancia',
      monto: 20,
    });
  });
});

describe('Aislamiento entre negocios', () => {
  it('un intruso no puede leer productos de un negocio ajeno', async () => {
    await assertFails(
      getDoc(doc(como(INTRUSO), 'negocios', NEGOCIO, 'productos', 'p1')),
    );
  });

  it('un intruso no puede leer el negocio', async () => {
    await assertFails(getDoc(doc(como(INTRUSO), 'negocios', NEGOCIO)));
  });

  it('un miembro sí puede leer los productos', async () => {
    await assertSucceeds(
      getDoc(doc(como(EMPLEADO), 'negocios', NEGOCIO, 'productos', 'p1')),
    );
  });
});

describe('Autoconcesión de membresía (la vulnerabilidad principal)', () => {
  it('un intruso NO puede declararse dueño de un negocio ajeno', async () => {
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'dueno',
      }),
    );
  });

  it('un intruso NO puede colarse ni siquiera como empleado', async () => {
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'empleado',
      }),
    );
  });

  it('no puede esquivarlo usando otro ID de documento', async () => {
    // El ID es lo que consulta esMiembro(), no el campo usuarioId.
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', 'id_arbitrario'), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'dueno',
      }),
    );
  });

  it('no puede inventarse un código de invitación', async () => {
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'empleado',
        codigoInvitacion: 'ABC234',
      }),
    );
  });

  it('el fundador SÍ puede crearse su membresía de dueño', async () => {
    const db = como(INTRUSO); // aquí "intruso" es solo un usuario cualquiera
    await assertSucceeds(
      setDoc(doc(db, 'negocios', 'negocio_nuevo'), {
        nombre: 'Mi negocio',
        rubro: 'bodega',
        creadoPor: INTRUSO,
      }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'membresias', membresiaId(INTRUSO, 'negocio_nuevo')), {
        usuarioId: INTRUSO,
        negocioId: 'negocio_nuevo',
        rol: 'dueno',
      }),
    );
  });

  it('no puede crear un negocio a nombre de otro', async () => {
    await assertFails(
      setDoc(doc(como(INTRUSO), 'negocios', 'negocio_nuevo'), {
        nombre: 'Mi negocio',
        creadoPor: DUENO,
      }),
    );
  });

  it('el dueño no puede reescribir creadoPor', async () => {
    await assertFails(
      updateDoc(doc(como(DUENO), 'negocios', NEGOCIO), { creadoPor: INTRUSO }),
    );
  });

  it('el dueño sí puede editar el resto de los ajustes', async () => {
    await assertSucceeds(
      updateDoc(doc(como(DUENO), 'negocios', NEGOCIO), { nombre: 'Nuevo nombre' }),
    );
  });
});

describe('Invitaciones', () => {
  const CODIGO = 'ABC234';

  async function sembrarInvitacion(extra = {}) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'invitaciones', CODIGO), {
        negocioId: NEGOCIO,
        negocioNombre: 'Bodega La Esquina',
        rol: 'empleado',
        expiraEn: enHoras(24),
        usado: false,
        ...extra,
      });
    });
  }

  it('un código válido deja entrar al invitado como empleado', async () => {
    await sembrarInvitacion();
    await assertSucceeds(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'empleado',
        codigoInvitacion: CODIGO,
      }),
    );
  });

  it('un código de empleado NO sirve para entrar como dueño', async () => {
    await sembrarInvitacion();
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'dueno',
        codigoInvitacion: CODIGO,
      }),
    );
  });

  it('un código caducado no sirve', async () => {
    await sembrarInvitacion({ expiraEn: enHoras(-1) });
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'empleado',
        codigoInvitacion: CODIGO,
      }),
    );
  });

  it('un código ya usado no sirve', async () => {
    await sembrarInvitacion({ usado: true });
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'empleado',
        codigoInvitacion: CODIGO,
      }),
    );
  });

  it('un código de OTRO negocio no abre este', async () => {
    await sembrarInvitacion({ negocioId: 'otro_negocio' });
    await assertFails(
      setDoc(doc(como(INTRUSO), 'membresias', membresiaId(INTRUSO, NEGOCIO)), {
        usuarioId: INTRUSO,
        negocioId: NEGOCIO,
        rol: 'empleado',
        codigoInvitacion: CODIGO,
      }),
    );
  });

  it('los códigos no se pueden enumerar', async () => {
    await sembrarInvitacion();
    await assertFails(getDocs(collection(como(INTRUSO), 'invitaciones')));
  });

  it('un código concreto sí se puede consultar para validarlo', async () => {
    await sembrarInvitacion();
    await assertSucceeds(getDoc(doc(como(INTRUSO), 'invitaciones', CODIGO)));
  });

  it('un código caducado no se puede marcar como usado', async () => {
    await sembrarInvitacion({ expiraEn: enHoras(-1) });
    await assertFails(
      updateDoc(doc(como(INTRUSO), 'invitaciones', CODIGO), { usado: true }),
    );
  });

  it('solo el dueño genera códigos', async () => {
    await assertFails(
      setDoc(doc(como(EMPLEADO), 'invitaciones', 'XYZ789'), {
        negocioId: NEGOCIO,
        rol: 'empleado',
        expiraEn: enHoras(24),
        usado: false,
      }),
    );
    await assertSucceeds(
      setDoc(doc(como(DUENO), 'invitaciones', 'XYZ789'), {
        negocioId: NEGOCIO,
        rol: 'empleado',
        expiraEn: enHoras(24),
        usado: false,
      }),
    );
  });
});

describe('Roles: qué puede hacer un empleado', () => {
  it('puede registrar una venta', async () => {
    await assertSucceeds(
      setDoc(doc(como(EMPLEADO), 'negocios', NEGOCIO, 'ventas', 'v1'), {
        items: [],
        totalUSD: 5,
        vendidoPor: EMPLEADO,
        anulada: false,
      }),
    );
  });

  it('puede descontar stock', async () => {
    await assertSucceeds(
      updateDoc(doc(como(EMPLEADO), 'negocios', NEGOCIO, 'productos', 'p1'), {
        cantidad: 9,
      }),
    );
  });

  it('NO puede anular una venta', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'negocios', NEGOCIO, 'ventas', 'v1'), {
        totalUSD: 5,
        anulada: false,
      });
    });
    await assertFails(
      updateDoc(doc(como(EMPLEADO), 'negocios', NEGOCIO, 'ventas', 'v1'), {
        anulada: true,
      }),
    );
  });

  it('NO puede eliminar productos', async () => {
    await assertFails(
      deleteDoc(doc(como(EMPLEADO), 'negocios', NEGOCIO, 'productos', 'p1')),
    );
  });

  it('NO puede ver los gastos (información financiera)', async () => {
    await assertFails(
      getDoc(doc(como(EMPLEADO), 'negocios', NEGOCIO, 'gastos', 'g1')),
    );
  });

  it('el dueño sí ve los gastos', async () => {
    await assertSucceeds(
      getDoc(doc(como(DUENO), 'negocios', NEGOCIO, 'gastos', 'g1')),
    );
  });

  it('NO puede ascenderse a dueño', async () => {
    await assertFails(
      updateDoc(
        doc(como(EMPLEADO), 'membresias', membresiaId(EMPLEADO, NEGOCIO)),
        { rol: 'dueno' },
      ),
    );
  });

  it('ninguna venta se puede borrar, ni siquiera por el dueño', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'negocios', NEGOCIO, 'ventas', 'v1'), {
        totalUSD: 5,
      });
    });
    await assertFails(
      deleteDoc(doc(como(DUENO), 'negocios', NEGOCIO, 'ventas', 'v1')),
    );
  });
});

describe('Sin autenticar', () => {
  it('no se lee nada', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'negocios', NEGOCIO, 'productos', 'p1')));
    await assertFails(getDoc(doc(db, 'membresias', membresiaId(DUENO, NEGOCIO))));
  });
});
