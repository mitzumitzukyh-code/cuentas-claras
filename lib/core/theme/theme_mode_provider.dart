import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/firebase_providers.dart';

/// Preferencia de modo oscuro, persistida en `SharedPreferences`.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._prefs) : super(_inicial(_prefs));

  final SharedPreferences _prefs;
  static const _clave = 'modo_oscuro';

  static ThemeMode _inicial(SharedPreferences prefs) {
    return prefs.getBool(_clave) ?? false ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> alternar() async {
    final oscuro = state != ThemeMode.dark;
    state = oscuro ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(_clave, oscuro);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return ThemeModeNotifier(prefs);
});
