import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/providers/firebase_providers.dart';

/// Canal de los empujones para usar la app. Va aparte de los avisos de tasa,
/// ventas y stock: esos son información que el dueño pidió, esto son
/// recordatorios. Separarlos deja que silencie uno sin perder los otros desde
/// los ajustes del sistema, que es lo que la gente hace cuando se cansa.
const AndroidNotificationChannel canalRecordatorios = AndroidNotificationChannel(
  'recordatorios_uso',
  'Recordatorios',
  description: 'Empujoncitos para anotar ventas, gastos y fiados del día.',
  // `defaultImportance` y no `high`: no suenan ni interrumpen. Un recordatorio
  // que vibra cuatro veces al día se desinstala.
  importance: Importance.defaultImportance,
);

/// Un empujón: qué dice y a qué función de la app está apuntando.
typedef Recordatorio = ({String titulo, String cuerpo});

/// Recordatorios locales que empujan a usar la app.
///
/// Se programan cuatro por día en franjas fijas ([_horas]) en vez de "cada 3-4
/// horas" a secas: un intervalo puro dispararía también de madrugada, que es
/// la forma más rápida de que desactiven las notificaciones y se pierdan
/// también las de tasa y stock. Las franjas cubren el día de una bodega —
/// apertura, mediodía, tarde y cierre — y quedan a 3-4 h una de otra.
///
/// Cada franja tiene su propio mensaje, atado al momento del día, y va
/// rotando por día del mes para que no sea siempre el mismo texto.
class RecordatoriosService {
  RecordatoriosService(this._locales, this._prefs);

  final FlutterLocalNotificationsPlugin _locales;
  final SharedPreferences _prefs;

  static const _claveActivos = 'recordatorios_uso_activos';

  /// IDs reservados para estas notificaciones. Fijos, para poder
  /// reprogramarlas y cancelarlas sin tocar las demás.
  static const _idBase = 9100;

  /// Las cuatro franjas del día de un negocio.
  static const _horas = [9, 13, 17, 20];

  /// Mensajes por franja. El índice externo es la franja; el interno rota por
  /// día para que no se repita el mismo texto a diario.
  static const _mensajes = <List<Recordatorio>>[
    // 9:00 — abrir el día.
    [
      (
        titulo: 'Buenos días 👋',
        cuerpo: 'Revisa la tasa del día antes de poner precios.',
      ),
      (
        titulo: '¿Ya abriste?',
        cuerpo: 'Anota tus ventas desde el principio y la cuenta te cuadra sola.',
      ),
      (
        titulo: 'Empieza parejo',
        cuerpo: 'Mira qué te quedó poco y apúntalo para reponer hoy.',
      ),
    ],
    // 13:00 — media jornada.
    [
      (
        titulo: 'Mitad del día',
        cuerpo: '¿Cuánto llevas vendido? Míralo en un toque.',
      ),
      (
        titulo: 'No lo dejes para después',
        cuerpo: 'Anota lo que fiaste esta mañana, antes de que se te olvide.',
      ),
      (
        titulo: '¿Compraste algo hoy?',
        cuerpo: 'Apunta el gasto y sabrás de verdad cuánto ganaste.',
      ),
    ],
    // 17:00 — empujar a vender.
    [
      (
        titulo: 'Muévete un poco más 📲',
        cuerpo: 'Manda tu lista de precios por WhatsApp y trae pedidos.',
      ),
      (
        titulo: 'Publica lo que tienes',
        cuerpo: 'Un Estado con tus precios de hoy toma menos de un minuto.',
      ),
      (
        titulo: '¿Te deben?',
        cuerpo: 'Revisa tus fiados y recuérdale a quien lleva tiempo.',
      ),
    ],
    // 20:00 — cerrar el día.
    [
      (
        titulo: 'Cierra tu día',
        cuerpo: 'Cuadra la caja y duerme tranquilo.',
      ),
      (
        titulo: '¿Cómo te fue hoy?',
        cuerpo: 'Mira tu resumen del día en un toque.',
      ),
      (
        titulo: 'Antes de cerrar',
        cuerpo: 'Anota lo que falte: ventas, gastos y fiados de hoy.',
      ),
    ],
  ];

  /// Los recordatorios están encendidos. Por defecto sí: son el motivo de que
  /// la app se use a diario, y el usuario puede apagarlos en Ajustes.
  bool get activos => _prefs.getBool(_claveActivos) ?? true;

  Future<void> cambiarActivos(bool valor) async {
    await _prefs.setBool(_claveActivos, valor);
    if (valor) {
      await programar();
    } else {
      await cancelar();
    }
  }

  /// Crea el canal. Se llama una vez al arrancar, junto con los otros.
  Future<void> iniciar() async {
    await _locales
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canalRecordatorios);
    tz.initializeTimeZones();
    if (activos) await programar();
  }

  /// (Re)programa las cuatro franjas. Cada una se repite a diario a su hora,
  /// vía [DateTimeComponents.time].
  Future<void> programar() async {
    await cancelar();

    // El texto rota por día del mes, no al azar: así dos franjas del mismo día
    // no repiten mensaje y el usuario no ve el mismo aviso dos días seguidos.
    final rotacion = DateTime.now().day;

    for (var i = 0; i < _horas.length; i++) {
      final opciones = _mensajes[i];
      final msg = opciones[(rotacion + i) % opciones.length];
      await _locales.zonedSchedule(
        _idBase + i,
        msg.titulo,
        msg.cuerpo,
        _proximaOcurrencia(_horas[i]),
        NotificationDetails(
          android: AndroidNotificationDetails(
            canalRecordatorios.id,
            canalRecordatorios.name,
            channelDescription: canalRecordatorios.description,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
        // `inexact` a propósito: la alarma exacta necesita un permiso especial
        // en Android 13+ que el sistema puede negar, y un recordatorio no
        // merece pedirlo. Que llegue unos minutos tarde da igual.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelar() async {
    for (var i = 0; i < _horas.length; i++) {
      await _locales.cancel(_idBase + i);
    }
  }

  /// La próxima vez que den las [hora]:00. Si ya pasaron hoy, mañana.
  tz.TZDateTime _proximaOcurrencia(int hora) {
    final ahora = tz.TZDateTime.now(tz.local);
    var cuando =
        tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day, hora);
    if (!cuando.isAfter(ahora)) {
      cuando = cuando.add(const Duration(days: 1));
    }
    return cuando;
  }
}

final recordatoriosServiceProvider = Provider<RecordatoriosService>((ref) {
  return RecordatoriosService(
    FlutterLocalNotificationsPlugin(),
    ref.watch(sharedPreferencesProvider),
  );
});
