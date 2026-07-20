import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers/firebase_providers.dart';
import 'firebase_options.dart';
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
    final preferencias = push.leerPreferencias();
    await push.sincronizarTopics(
      preferencias,
      topicsPrevios: preferencias.topicsDeseados,
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: contenedor,
      child: CuentaClaraApp(initError: initError),
    ),
  );
}
