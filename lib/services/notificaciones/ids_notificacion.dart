/// IDs de notificación de la app, en un solo sitio.
///
/// Android identifica cada notificación por su id: mostrar dos veces el mismo
/// id REEMPLAZA la anterior, y dos ids distintos la APILAN. Por eso los ids
/// tienen que ser constantes por tipo de aviso y nunca derivarse de la hora,
/// de un `hashCode` ni de un número al azar — con un id distinto cada vez, un
/// mismo aviso repetido se ve como cinco notificaciones diferentes en vez de
/// una que se actualiza.
///
/// Los rangos se reservan por familia para que agregar un aviso nuevo no
/// pise a ninguno existente.
abstract final class IdsNotificacion {
  const IdsNotificacion._();

  // --- 1000: avisos que vienen del Worker y se pintan en primer plano ---

  /// Tasa BCV (subida, bajada, ritmo, resumen). Es un valor que se actualiza:
  /// el aviso nuevo debe sustituir al viejo, no sumarse.
  static const tasa = 1001;

  /// Resumen de ventas del día / recordatorio de que no hubo ventas.
  static const resumenVentas = 1002;

  /// Stock bajo o producto agotado.
  static const stock = 1003;

  /// Cabecera del grupo. No es un aviso: es el renglón que Android muestra
  /// arriba cuando hay varios del mismo grupo desplegados.
  static const resumenGrupo = 1000;

  // --- 9100: recordatorios locales programados (cuatro franjas del día) ---

  /// Base de las franjas fijas; cada una ocupa `base + índice de franja`.
  /// Se mantienen los valores históricos para no dejar huérfanas las que ya
  /// estén programadas en dispositivos con la versión anterior instalada.
  static const recordatorioBase = 9100;

  // --- 9200: avisos de corte de luz, programados día por día ---

  /// Base de los avisos del cronograma eléctrico. Cada día programado ocupa
  /// dos ids consecutivos —el aviso antes del corte y el de la vuelta—, así
  /// que una semana cabe en `9200..9213` y el rango llega hasta 9299.
  ///
  /// Van en su propia familia y no colgando de [recordatorioBase] porque se
  /// cancelan y reprograman en bloque cada vez que se abre la app: mezclarlos
  /// con los recordatorios haría que apagar unos borrara los otros.
  /// Aviso de corte de luz que llega por push mientras la app está en
  /// pantalla. Id fijo como los demás: el aviso de la vuelta reemplaza al de
  /// «se va la luz», que es el mismo asunto en su siguiente estado.
  static const luz = 1004;

  // --- 9200: avisos de luz locales (solo la prueba de «así se verá») ---

  /// El aviso de prueba del botón de Ajustes. Los avisos de verdad ya no se
  /// programan en el teléfono —los manda el Worker por push—, así que de esta
  /// familia solo queda este.
  static const luzPrueba = 9298;

  /// Grupo bajo el que Android junta todo lo que manda Cuenta Clara.
  ///
  /// Con el mismo `groupKey`, aunque lleguen varios avisos seguidos el sistema
  /// los pliega en un solo renglón expandible en vez de apilar tarjetas
  /// sueltas — que es la diferencia entre "la app me avisó" y "la app me está
  /// haciendo spam".
  static const grupo = 'cuenta_clara_recordatorios';
}
