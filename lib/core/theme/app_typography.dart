import 'package:flutter/material.dart';

/// Tipografía de Cuenta Clara: **Plus Jakarta Sans**, la fuente del bundle de
/// diseño (`dise-o-de-app`). Pesos usados: 400/500/600/700/800.
///
/// Se empaqueta (`assets/fonts/`, declarada en `pubspec.yaml`) para evitar la
/// descarga en runtime de `google_fonts`, que sin red caía a Roboto.
abstract final class AppTypography {
  const AppTypography._();

  /// Nombre de la familia empaquetada (ver `pubspec.yaml`).
  static const String familia = 'PlusJakartaSans';

  /// Números de ancho fijo — imprescindible para columnas de montos.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  /// Construye el [TextTheme] de la app, tintado con el color de texto del modo.
  static TextTheme textTheme(TextTheme base, Color texto) {
    final fuente = base.apply(fontFamily: familia);
    return fuente.apply(bodyColor: texto, displayColor: texto).copyWith(
          // El diseño usa 800 para todos los títulos y 700 para subtítulos.
          headlineSmall: fuente.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: texto,
          ),
          titleLarge: fuente.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: texto,
          ),
          titleMedium: fuente.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: texto,
          ),
          bodyMedium: fuente.bodyMedium?.copyWith(color: texto),
          labelLarge: fuente.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        );
  }

  /// Estilo para montos (dashboard, total del carrito, precios).
  static TextStyle money({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w800,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: familia,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.5,
      fontFeatures: tabular,
    );
  }
}
