import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/luz/data/cronograma_repository.dart';
import '../../features/luz/domain/cronograma_luz.dart';
import 'ids_notificacion.dart';
import 'push_service.dart';

/// Suscribe el teléfono al aviso de corte de su bloque.
///
/// **Los avisos los manda el Worker por push, no el teléfono.** La primera
/// versión programaba alarmas locales con `zonedSchedule`, y en el
/// dispositivo de pruebas —un ZTE— quedaban registradas en `dumpsys alarm` y
/// luego no se disparaban nunca. Es la forma más cara de fallar: el código
/// parece correcto, las pruebas pasan y el aviso no llega. El push por topic
/// es el mismo camino que la app ya usa todos los días para la tasa del
/// dólar, y ese sí funciona en ese teléfono.
///
/// Lo que se pierde: sin internet no hay aviso. Pero un aviso local que el
/// sistema nunca dispara tampoco es un aviso.
///
/// **Solo se suscribe quien lo pidió.** El topic es `luz-barinas-a`; a él solo
/// llega quien tiene el interruptor puesto y ese bloque elegido.
class LuzService {
  LuzService(this._locales, this._messaging, this._cronogramas);

  final FlutterLocalNotificationsPlugin _locales;
  final FirebaseMessaging _messaging;
  final CronogramaRepository _cronogramas;

  /// El estado del que hay cronograma. Cuando haya más, sale de las
  /// preferencias como el bloque.
  static const _estado = 'barinas';

  /// Los bloques posibles. Se usa para darse de baja de los que no toquen,
  /// aunque el registro local crea que nunca se estuvo suscrito: esa fue la
  /// causa de que los avisos de tasa llegaran repetidos, y aquí el síntoma
  /// sería recibir el corte de otro bloque, que es peor —una hora que no es.
  static const _bloques = ['A', 'B', 'C', 'D'];

  /// Igual que en los avisos de tasa: en ROMs con Play Services dañado estas
  /// llamadas pueden colgarse sin lanzar nada.
  static const _timeout = Duration(seconds: 8);

  static String topicDe(String bloque) =>
      'luz-$_estado-${bloque.toLowerCase()}';

  Future<void> iniciar() async {
    await _locales
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canalLuz);
    await sincronizar();
  }

  /// Deja la suscripción igual a lo que dicen los ajustes.
  ///
  /// Se llama al arrancar y cada vez que se toca el interruptor o el bloque.
  /// Da de baja todos los bloques que no sean el elegido, siempre: es barato
  /// y cierra el agujero de quedarse escuchando un bloque viejo.
  Future<void> sincronizar() async {
    final bloque = _cronogramas.activo ? _cronogramas.bloque : null;

    for (final b in _bloques) {
      if (b == bloque) continue;
      try {
        await _messaging.unsubscribeFromTopic(topicDe(b)).timeout(_timeout);
      } catch (_) {
        // Best-effort: se reintenta en el próximo arranque.
      }
    }

    if (bloque == null) return;
    await _messaging.subscribeToTopic(topicDe(bloque)).timeout(_timeout);
  }

  /// Enseña cómo se verá el aviso, ahora mismo.
  ///
  /// Es una notificación local inmediata —no una alarma— y por eso sí llega:
  /// lo que este teléfono no respeta son las programadas. Prueba el canal, el
  /// permiso y el aspecto; la entrega del aviso de verdad depende del Worker,
  /// y esa se prueba recibiendo uno.
  Future<void> probar() async {
    final franja = await _franjaDeHoy();
    final aviso = franja == null
        ? (
            titulo: 'Así se verá el aviso',
            cuerpo: 'Te avisaremos media hora antes de que se vaya la luz en '
                'tu bloque.',
          )
        : avisoAntesDelCorte(franja);

    await _locales.show(
      IdsNotificacion.luzPrueba,
      '🧪 ${aviso.titulo}',
      aviso.cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(
          canalLuz.id,
          canalLuz.name,
          channelDescription: canalLuz.description,
          importance: Importance.high,
          priority: Priority.high,
          groupKey: IdsNotificacion.grupo,
        ),
      ),
    );
  }

  Future<FranjaCorte?> _franjaDeHoy() async {
    final bloque = _cronogramas.bloque;
    if (bloque == null) return null;
    final cronograma = await _cronogramas.vigente();
    return cronograma?.franja(DateTime.now(), bloque);
  }
}

final luzServiceProvider = Provider<LuzService>((ref) {
  return LuzService(
    FlutterLocalNotificationsPlugin(),
    ref.watch(firebaseMessagingProvider),
    ref.watch(cronogramaRepositoryProvider),
  );
});
