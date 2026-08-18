import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Los avisos de corte se programan con `tz.TZDateTime(tz.local, …, hora)`.
/// Si esa conversión se corre unos minutos, TODOS los avisos de la app salen
/// corridos, y es de las cosas que no se ven mirando la pantalla: hay que
/// mirar el reloj del sistema.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Caracas'));
  });

  test('las 6:00 pm de Caracas son las 10:00 pm UTC, sin minutos sueltos', () {
    final seisDeLaTarde = tz.TZDateTime(tz.local, 2026, 8, 14, 18);
    expect(seisDeLaTarde.hour, 18);
    expect(seisDeLaTarde.minute, 0, reason: 'la hora no puede salir corrida');
    expect(seisDeLaTarde.second, 0);
    expect(seisDeLaTarde.toUtc().hour, 22);
  });

  test('media hora antes de la 1:00 pm son las 12:30 pm en punto', () {
    final aviso = tz.TZDateTime(tz.local, 2026, 8, 14, 13)
        .subtract(const Duration(minutes: 30));
    expect(aviso.hour, 12);
    expect(aviso.minute, 30);
    expect(aviso.second, 0);
  });

  test('el desfase de Venezuela es de 4 horas exactas', () {
    final agosto = tz.TZDateTime(tz.local, 2026, 8, 14, 12);
    expect(agosto.timeZoneOffset, const Duration(hours: -4));
  });
}
