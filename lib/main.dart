import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers/firebase_providers.dart';
import 'firebase_options.dart';
import 'services/notificaciones/luz_service.dart';
import 'services/notificaciones/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferencias locales (caché de tasa BCV, config). Se inyecta como override.
  final prefs = await SharedPreferences.getInstance();

  // Inicializa Firebase. Con el `firebase_options.dart` placeholder esto puede
  // fallar hasta que se ejecute `flutterfire configure`; el error se muestra en
  // una pantalla amigable en vez de crashear.
  String? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    initError = e.toString();
  }

  // App Check: demuestra que quien llama a Firebase es esta app en un
  // dispositivo real, y no un script con la Web API Key —que es pública por
  // diseño y va dentro del APK—. Sin esto, cualquiera puede crear cuentas en
  // masa o gastarse la cuota de Gemini haciéndose pasar por la app.
  //
  // **Activarlo aquí no bloquea nada todavía.** La app empieza a mandar su
  // atestación y la consola de Firebase la va contando; la exigencia se
  // enciende por servicio desde la consola, y solo tiene sentido hacerlo
  // cuando las métricas digan que casi todo el tráfico ya viene atestado. Al
  // revés se deja fuera a quien no haya actualizado.
  //
  // En debug va el proveedor de depuración: Play Integrity exige una app
  // instalada desde Play, así que en un APK puesto por cable la atestación
  // real no pasa.
  if (initError == null) {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
        appleProvider:
            kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
      );
    } catch (e) {
      // Que falle la atestación no puede dejar sin app a nadie: mientras no
      // se exija en la consola, esto solo resta protección, no función.
      debugPrint('App Check no se pudo activar: $e');
    }
  }

  final contenedor = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Las notificaciones solo se preparan si Firebase arrancó: sin él, pedir el
  // canal o los topics lanzaría una excepción encima del error real.
  if (initError == null) {
    FirebaseMessaging.onBackgroundMessage(manejarPushEnSegundoPlano);
    final push = contenedor.read(pushServiceProvider);
    await push.iniciar();
    // Reconcilia al arrancar: el permiso pudo revocarse desde los ajustes del
    // sistema con la app cerrada, y las suscripciones deben reflejarlo.
    await push.sincronizarTopics(push.leerPreferencias());
  }

  // Los avisos de corte de luz son locales y no dependen de Firebase: se
  // preparan aunque él haya fallado, porque es justo el día sin luz —y sin
  // red— cuando más falta hacen. Sin `await`: reprogramar la semana implica
  // bajar el cronograma, y eso no puede retrasar la primera pantalla.
  unawaited(
    contenedor.read(luzServiceProvider).iniciar().catchError((Object e) {
      debugPrint('No se pudieron programar los avisos de luz: $e');
    }),
  );

  runApp(
    UncontrolledProviderScope(
      container: contenedor,
      child: CuentaClaraApp(initError: initError),
    ),
  );
}
