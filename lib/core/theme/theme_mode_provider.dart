import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia de modo oscuro, persistida en `SharedPreferences`.
///
/// El diseño la expone como un interruptor en Ajustes → Preferencias
/// ("Modo oscuro 🌙"), así que es una elección explícita del usuario y no sigue
/// al sistema.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _cargar();
  }

  static const _clave = 'modo_oscuro';

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final oscuro = prefs.getBool(_clave) ?? false;
    state = oscuro ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> alternar() async {
    final oscuro = state != ThemeMode.dark;
    state = oscuro ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, oscuro);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
