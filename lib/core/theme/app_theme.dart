import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';

/// Tema visual de Cuenta Clara — neumorfismo, modo claro y oscuro.
///
/// El relieve del diseño se logra con sombras dobles (una oscura abajo-derecha,
/// un brillo arriba-izquierda) que viven en [AppTokens], no en `elevation`. Por
/// eso todos los componentes Material se declaran con `elevation: 0`.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get light => _construir(Brightness.light, AppTokens.claro);

  static ThemeData get dark => _construir(Brightness.dark, AppTokens.oscuro);

  static ThemeData _construir(Brightness brillo, AppTokens t) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.marca,
      brightness: brillo,
    ).copyWith(
      primary: AppColors.marca,
      onPrimary: Colors.white,
      surface: t.surface,
      onSurface: t.text,
      error: AppColors.peligro,
      onError: Colors.white,
      outline: t.border,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      scaffoldBackgroundColor: t.pageBg,
      canvasColor: t.pageBg,
      extensions: [t],
      textTheme: AppTypography.textTheme(base.textTheme, t.text),
      appBarTheme: AppBarTheme(
        backgroundColor: t.pageBg,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.textTheme(base.textTheme, t.text)
            .titleLarge
            ?.copyWith(fontSize: 18),
      ),
      // Las tarjetas del diseño son contenedores con sombra propia; este tema
      // solo cubre los `Card` que Material crea internamente (diálogos, etc.).
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.marca,
          foregroundColor: Colors.white,
          disabledBackgroundColor: t.muted,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.marca,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // Los campos del diseño son "hundidos" (sombra interior) y se construyen
      // con `NeuInput`. Este tema es el respaldo para campos sueltos.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: t.muted),
        labelStyle: TextStyle(color: t.textSec),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.marca, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.peligro, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.peligro, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.divider, thickness: 1, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.marca : t.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.marca,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.lText,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
