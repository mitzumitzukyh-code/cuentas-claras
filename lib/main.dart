import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/providers/firebase_providers.dart';
import 'firebase_options.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: CuentaClaraApp(initError: initError),
    ),
  );
}
