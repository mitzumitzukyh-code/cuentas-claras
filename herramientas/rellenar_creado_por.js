#!/usr/bin/env node
/**
 * Rellena `creadoPor` en los negocios que no lo tienen.
 *
 * POR QUÉ HACE FALTA
 * ------------------
 * `negocios/{id}.creadoPor` apareció después que los primeros negocios, así
 * que los documentos viejos no lo traen. Desde que existe la capa de planes eso
 * tiene una consecuencia visible: `planDelNegocioProvider` no sabe a quién
 * preguntarle el plan y devuelve `gratis`, así que un dueño que pagó Premium se
 * vería en el plan gratis sin entender por qué.
 *
 * POR QUÉ NO LO HACE LA APP
 * -------------------------
 * Las reglas de Firestore declaran `creadoPor` inmutable en el `update`, y no
 * por descuido: es la prueba que autoriza a concederse la membresía de dueño
 * (`esFundador`). Si el cliente pudiera reescribirlo, cualquier dueño podría
 * regalar —o robar— la capacidad de fundar membresías sobre un negocio. Por eso
 * esto va con el Admin SDK, que se salta las reglas, y por eso lo ejecuta una
 * persona y no la app.
 *
 * CÓMO SE USA
 * -----------
 *   npm install firebase-admin
 *   set GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\a\tu-clave.json
 *
 *   node herramientas/rellenar_creado_por.js            # solo mira e informa
 *   node herramientas/rellenar_creado_por.js --aplicar  # escribe
 *
 * Sin `--aplicar` no toca nada: enumera lo que haría y por qué. Léelo antes.
 *
 * QUÉ NO HACE
 * -----------
 * No adivina. Un negocio se rellena solo si tiene **exactamente una** membresía
 * con rol `dueno`. Con cero no hay a quién atribuirlo; con dos o más, elegir
 * sería repartir a dedo quién puede fundar membresías. Esos casos se listan
 * aparte para que los resuelvas mirándolos, no por mayoría.
 */

const admin = require('firebase-admin');

const aplicar = process.argv.includes('--aplicar');

admin.initializeApp();
const db = admin.firestore();

/** Los negocios sin `creadoPor`, con el id del documento. */
async function negociosSinCreador() {
  const snap = await db.collection('negocios').get();
  return snap.docs.filter((d) => !d.get('creadoPor'));
}

/** Los uid con rol `dueno` en ese negocio. */
async function duenosDe(negocioId) {
  const snap = await db
    .collection('membresias')
    .where('negocioId', '==', negocioId)
    .where('rol', '==', 'dueno')
    .get();
  return snap.docs.map((d) => d.get('usuarioId')).filter(Boolean);
}

async function main() {
  console.log(
    aplicar
      ? '── MODO ESCRITURA ──────────────────────────────'
      : '── SOLO INFORME (usa --aplicar para escribir) ──',
  );

  const pendientes = await negociosSinCreador();
  if (pendientes.length === 0) {
    console.log('\nTodos los negocios tienen `creadoPor`. No hay nada que hacer.');
    return;
  }

  console.log(`\n${pendientes.length} negocio(s) sin \`creadoPor\`:\n`);

  const listos = [];
  const ambiguos = [];

  for (const doc of pendientes) {
    const nombre = doc.get('nombre') || '(sin nombre)';
    const duenos = await duenosDe(doc.id);

    if (duenos.length === 1) {
      listos.push({ doc, nombre, uid: duenos[0] });
      console.log(`  ✓ ${nombre}  [${doc.id}]`);
      console.log(`      dueño único → ${duenos[0]}`);
    } else {
      ambiguos.push({ doc, nombre, duenos });
      console.log(`  ! ${nombre}  [${doc.id}]`);
      console.log(
        duenos.length === 0
          ? '      SIN membresía de dueño — no hay a quién atribuirlo'
          : `      ${duenos.length} dueños: ${duenos.join(', ')}`,
      );
    }
  }

  if (ambiguos.length > 0) {
    console.log(
      `\n${ambiguos.length} se omiten: elegir por ellos sería repartir a dedo ` +
        'quién puede fundar membresías. Resuélvelos mirando cada caso.',
    );
  }

  if (!aplicar) {
    console.log(
      `\nNada escrito. Se escribirían ${listos.length}. ` +
        'Repite con --aplicar cuando la lista te cuadre.',
    );
    return;
  }

  if (listos.length === 0) {
    console.log('\nNo hay ninguno sin ambigüedad. Nada que escribir.');
    return;
  }

  const lote = db.batch();
  for (const { doc, uid } of listos) {
    lote.update(doc.ref, { creadoPor: uid });
  }
  await lote.commit();
  console.log(`\nListo: ${listos.length} negocio(s) actualizados.`);
}

main().catch((e) => {
  console.error('\nFalló:', e.message);
  process.exit(1);
});
