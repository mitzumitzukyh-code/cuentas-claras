/**
 * Cronograma de cortes eléctricos.
 *
 * En Venezuela la luz se va por bloques y con horario publicado. Para una
 * bodega eso decide el día entero: cuándo cobrar con punto de venta, cuándo
 * abrir la nevera lo menos posible, a qué hora conviene cerrar.
 *
 * **La tabla vive aquí y no en el APK a propósito.** El cronograma cambia
 * cada mes; si viviera en la app, cada cambio sería compilar, subir a Play y
 * esperar a que la gente actualice — y mientras tanto la app avisaría de una
 * hora que ya no es. Aquí se cambia un literal y se despliega.
 *
 * **Fuera del rango de fechas no se inventa nada.** El cronograma trae
 * `desde` y `hasta`, y la app no manda ni un aviso fuera de ahí. Decir "se va
 * a las 8" cuando se fue a las 3 no es un error pequeño: es la última vez que
 * ese dueño le hace caso a la app.
 */

/**
 * Las cuatro franjas del día, tal como las publica Corpoelec.
 *
 * Son los renglones de la tabla impresa. El corte ocupa la franja entera.
 *
 * `id` es una CLAVE INTERNA y no se le enseña a nadie: nadie en una bodega
 * dice «de dieciocho a veintitrés». Lo que viaja para pintar son `desde` y
 * `hasta` en horas del reloj de 24, y la app las escribe como «6:00 pm a
 * 11:00 pm».
 */
const FRANJAS = [
  { id: '03-08', desde: 3, hasta: 8 },
  { id: '08-13', desde: 8, hasta: 13 },
  { id: '13-18', desde: 13, hasta: 18 },
  { id: '18-23', desde: 18, hasta: 23 },
];

/**
 * Barinas, agosto de 2026.
 *
 * `semanas[s][f][d]` es el BLOQUE al que le toca corte en la semana `s`, la
 * franja `f` y el día `d` (0 = lunes). Está escrito con la misma forma que el
 * papel para que actualizarlo el mes que viene sea copiar la tabla renglón a
 * renglón, sin traducir nada.
 *
 * La columna del DOMINGO se dedujo del patrón: en la foto de la que se
 * transcribió esto el borde derecho estaba cortado. El resto de la tabla
 * confirma la rotación (cada día el corte se adelanta una franja), así que el
 * domingo encaja, pero es la columna que hay que revisar contra el papel.
 */
const BARINAS_AGOSTO_2026 = {
  estado: 'barinas',
  version: '2026-08',
  desde: '2026-08-03',
  hasta: '2026-08-30',
  semanas: [
    // Del 3 al 9 de agosto.
    [
      ['D', 'A', 'B', 'C', 'D', 'A', 'B'],
      ['A', 'B', 'C', 'D', 'A', 'B', 'C'],
      ['B', 'C', 'D', 'A', 'B', 'C', 'D'],
      ['C', 'D', 'A', 'B', 'C', 'D', 'A'],
    ],
    // Del 10 al 16 de agosto.
    [
      ['C', 'D', 'A', 'B', 'C', 'D', 'A'],
      ['D', 'A', 'B', 'C', 'D', 'A', 'B'],
      ['A', 'B', 'C', 'D', 'A', 'B', 'C'],
      ['B', 'C', 'D', 'A', 'B', 'C', 'D'],
    ],
    // Del 17 al 23 de agosto.
    [
      ['B', 'C', 'D', 'A', 'B', 'C', 'D'],
      ['C', 'D', 'A', 'B', 'C', 'D', 'A'],
      ['D', 'A', 'B', 'C', 'D', 'A', 'B'],
      ['A', 'B', 'C', 'D', 'A', 'B', 'C'],
    ],
    // Del 24 al 30 de agosto.
    [
      ['A', 'B', 'C', 'D', 'A', 'B', 'C'],
      ['B', 'C', 'D', 'A', 'B', 'C', 'D'],
      ['C', 'D', 'A', 'B', 'C', 'D', 'A'],
      ['D', 'A', 'B', 'C', 'D', 'A', 'B'],
    ],
  ],
  /**
   * Los sectores de cada bloque, para que el dueño encuentre el suyo sin
   * tener que buscar el papel. Es la mitad de abajo del mismo cronograma.
   */
  sectores: {
    A: [
      'Alto Barinas I 34,5 kV', 'Guasimito', 'Centro', 'Sur', 'Norte',
      'Las Palmas', 'Primero de Diciembre', 'Borburata', 'Ciudad Varyná',
      'Ciudad Tavacare', 'Ciudad Bolivia II', 'Ticoporo', 'Barrancas 34,5 kV',
      'Santa Bárbara II', 'El Real', 'El Tambor',
    ],
    B: [
      'Barinitas 34,5 kV', 'Mirí', 'Parangula', 'Lucha Paiva', 'Centro Norte',
      'San Silvestre', 'Carolina', 'Santa Inés Lucía', 'Pagüeycito',
      'Santa Rosa', 'Negro Primero', 'Hormiga', 'Don Simón', 'Progreso',
      'Curbatí', 'Capitanejo 34,5 kV',
    ],
    C: [
      'Expresa 34,5 kV', 'Socopó II', 'Estadio', 'Agroisleña', 'Comdibaca',
      'Santa Bárbara I', 'Esperanza', 'Toruno', 'Raúl Leoni',
      'Ciudad Nutria 34,5 kV', 'Fundacea', 'Dolores', 'Socopó I', 'Bum Bum',
    ],
    D: [
      'Alto Barinas II 34,5 kV', 'Ciudad Bolivia I', 'Obispos 34,5 kV',
      'Mijagua 34,5 kV', 'Floresta', 'Caaez 34,5 kV', 'Los Pinos',
      'Boconoíto', 'Industrial', 'Otopum-Pajén', 'Cardenera',
      'Canagua 34,5 kV', 'Corocito', 'Libertad', 'El Paguey',
    ],
  },
};

const CRONOGRAMAS = { barinas: BARINAS_AGOSTO_2026 };

/** Los estados con cronograma cargado. */
export function estadosConCronograma() {
  return Object.keys(CRONOGRAMAS);
}

/**
 * Venezuela está en UTC−4 todo el año, sin horario de verano desde 2016.
 *
 * El Worker corre en UTC y el cronograma está en hora de Venezuela, así que
 * cada pasada del cron hay que traducir. Se resta fijo en vez de usar
 * `Intl.DateTimeFormat` con zona: son cinco líneas contra una dependencia de
 * la base de husos del runtime, y aquí un fallo son avisos a deshora.
 */
const HORAS_UTC_MENOS_VENEZUELA = 4;

/** La fecha y la hora venezolanas de un instante UTC. */
export function enHoraVenezuela(ahora) {
  const local = new Date(ahora.getTime() - HORAS_UTC_MENOS_VENEZUELA * 3600000);
  return {
    fecha: local.toISOString().slice(0, 10),
    hora: local.getUTCHours(),
    minuto: local.getUTCMinutes(),
  };
}

/** Cuánto antes del corte se avisa. */
const MINUTOS_DE_AVISO = 30;

/** `18` → `6:00 pm`. Nadie dice «a las dieciocho horas». */
export function hora12(hora24) {
  const h = ((hora24 % 24) + 24) % 24;
  const sufijo = h < 12 ? 'am' : 'pm';
  const doce = h % 12 === 0 ? 12 : h % 12;
  return `${doce}:00 ${sufijo}`;
}

/** El topic de FCM de un bloque. La app se suscribe al suyo y a ninguno más. */
export function topicDe(estado, bloque) {
  return `luz-${estado}-${String(bloque).toLowerCase()}`;
}

/**
 * Qué avisos toca mandar en esta pasada del cron.
 *
 * Devuelve una lista —normalmente vacía— con el topic y el texto. No manda
 * nada: eso lo hace quien llama, que es el que tiene el token de FCM.
 *
 * Se emite un aviso cuando la pasada del cron **cae dentro del minuto
 * exacto** que le toca. Con el cron cada media hora eso significa dos
 * momentos: `MINUTOS_DE_AVISO` antes del corte, y la hora en punto en que
 * debería volver la luz. Si una pasada se pierde, ese aviso no se manda:
 * mandarlo tarde sería peor —«se va la luz en 30 minutos» media hora después
 * de que se fue es exactamente el aviso que enseña a ignorar la app.
 */
export function avisosDeCorte(ahora, { estado = 'barinas' } = {}) {
  const c = CRONOGRAMAS[estado];
  if (!c) return [];

  const { fecha, hora, minuto } = enHoraVenezuela(ahora);
  const avisos = [];

  for (const bloque of Object.keys(c.sectores)) {
    const franja = franjaDe(c, fecha, bloque);
    if (!franja) continue;

    // Media hora antes del corte. `30` es tanto el minuto como la antelación
    // porque las franjas empiezan siempre en hora en punto.
    const horaDelAviso = (franja.desde - 1 + 24) % 24;
    if (hora === horaDelAviso && minuto === 60 - MINUTOS_DE_AVISO) {
      avisos.push({
        topic: topicDe(estado, bloque),
        titulo: `Se va la luz a las ${hora12(franja.desde)}`,
        cuerpo: `Hoy te toca de ${hora12(franja.desde)} a ` +
          `${hora12(franja.hasta)}. Cobra lo que puedas y carga el teléfono.`,
        datos: { tipo: 'luz', bloque, cuando: 'antes' },
      });
    }

    // La hora a la que debería volver. «Debería»: el Worker no tiene forma de
    // saber si volvió, y prometer luz que no llegó es peor que callarse.
    if (hora === franja.hasta && minuto === 0) {
      avisos.push({
        topic: topicDe(estado, bloque),
        titulo: 'Ya debería haber vuelto la luz',
        cuerpo: `El corte de hoy era hasta las ${hora12(franja.hasta)}.`,
        datos: { tipo: 'luz', bloque, cuando: 'vuelta' },
      });
    }
  }

  return avisos;
}

/**
 * Un aviso por bloque con el corte de hoy, sin mirar la hora.
 *
 * Es para `?probarLuz=1`: prueba la entrega de punta a punta —Worker, FCM,
 * suscripción, canal, teléfono— sin tener que esperar a que sean las 12:30.
 * Lleva «(prueba)» en el título para que nadie lo confunda con el de verdad.
 */
export function avisosDePrueba(ahora, { estado = 'barinas' } = {}) {
  const c = CRONOGRAMAS[estado];
  if (!c) return [];

  const { fecha } = enHoraVenezuela(ahora);
  const avisos = [];
  for (const bloque of Object.keys(c.sectores)) {
    const franja = franjaDe(c, fecha, bloque);
    if (!franja) continue;
    avisos.push({
      topic: topicDe(estado, bloque),
      titulo: `🧪 Prueba · se va la luz a las ${hora12(franja.desde)}`,
      cuerpo: `Hoy al bloque ${bloque} le toca de ${hora12(franja.desde)} a ` +
        `${hora12(franja.hasta)}.`,
      datos: { tipo: 'luz', bloque, cuando: 'prueba' },
    });
  }
  return avisos;
}

/** Días completos entre dos fechas `yyyy-mm-dd`, en UTC para no arrastrar husos. */
function diasEntre(desde, fecha) {
  const a = Date.parse(`${desde}T00:00:00Z`);
  const b = Date.parse(`${fecha}T00:00:00Z`);
  if (Number.isNaN(a) || Number.isNaN(b)) return null;
  return Math.round((b - a) / 86400000);
}

/**
 * La franja de corte de un bloque en una fecha, o `null` si ese día no le
 * toca o la fecha cae fuera del cronograma.
 *
 * @param {string} fecha `yyyy-mm-dd`
 * @param {string} bloque `A` | `B` | `C` | `D`
 */
export function franjaDe(cronograma, fecha, bloque) {
  const dias = diasEntre(cronograma.desde, fecha);
  if (dias === null || dias < 0) return null;
  if (diasEntre(fecha, cronograma.hasta) < 0) return null;

  const semana = Math.floor(dias / 7);
  const dia = dias % 7;
  const filas = cronograma.semanas[semana];
  if (!filas) return null;

  const b = String(bloque || '').toUpperCase();
  for (let f = 0; f < filas.length; f++) {
    if (filas[f][dia] === b) return FRANJAS[f];
  }
  return null;
}

/**
 * El cronograma completo de un estado, ya resuelto día por día.
 *
 * Se manda resuelto y no como tabla rotatoria para que la app no tenga que
 * reimplementar la rotación: si un mes trae un día irregular —un feriado, un
 * racionamiento especial—, aquí se corrige y la app no se entera.
 */
export function cronogramaResuelto(estado) {
  const c = CRONOGRAMAS[String(estado || '').toLowerCase()];
  if (!c) return null;

  const total = diasEntre(c.desde, c.hasta);
  const dias = {};
  for (let i = 0; i <= total; i++) {
    const fecha = new Date(Date.parse(`${c.desde}T00:00:00Z`) + i * 86400000)
      .toISOString()
      .slice(0, 10);
    const porBloque = {};
    for (const bloque of Object.keys(c.sectores)) {
      const franja = franjaDe(c, fecha, bloque);
      if (franja) porBloque[bloque] = franja.id;
    }
    dias[fecha] = porBloque;
  }

  return {
    estado: c.estado,
    version: c.version,
    desde: c.desde,
    hasta: c.hasta,
    franjas: FRANJAS,
    sectores: c.sectores,
    dias,
  };
}
