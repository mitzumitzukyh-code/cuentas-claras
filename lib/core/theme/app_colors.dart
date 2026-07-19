import 'package:flutter/material.dart';

/// Tokens de color de Cuenta Clara — diseño neumórfico (bundle `dise-o-de-app`).
///
/// El diseño define una paleta que cambia entre modo claro y oscuro. Los valores
/// crudos viven aquí; el acceso desde los widgets es siempre vía
/// `context.tokens` ([AppTokens]), nunca leyendo estas constantes directamente.
abstract final class AppColors {
  const AppColors._();

  /// Verde de marca. Es el único color que NO cambia entre claro y oscuro.
  static const Color marca = Color(0xFF0F6B5C);

  /// Rojo de acciones destructivas (eliminar, vaciar, anular).
  static const Color peligro = Color(0xFFC74A3A);

  /// Fondo suave para banners/botones destructivos.
  static const Color peligroSuave = Color(0xFFFDF0EE);

  /// Ámbar de avisos (stock bajo, ventas sin sincronizar).
  static const Color aviso = Color(0xFFC9852B);

  /// Fondo suave para banners de aviso.
  static const Color avisoSuave = Color(0xFFFBF1E3);

  /// Azul informativo (ventas en espera).
  static const Color info = Color(0xFF3D6CA8);

  /// Fondo suave para chips informativos.
  static const Color infoSuave = Color(0xFFEAF1FB);

  // --- Modo claro ---
  static const Color lPageBg = Color(0xFFF7F5F2);
  static const Color lSurface = Color(0xFFFFFFFF);
  static const Color lText = Color(0xFF1A2421);
  static const Color lTextSec = Color(0xFF6B7873);
  static const Color lBorder = Color(0xFFE0DDD7);
  static const Color lBorder2 = Color(0xFFECE9E3);
  static const Color lDivider = Color(0xFFF0EEE9);
  static const Color lChip = Color(0xFFF0EEE9);
  static const Color lTint = Color(0xFFE3F3EE);
  static const Color lMuted = Color(0xFFA39D90);
  static const Color lNavInactive = Color(0xFFC7C2B8);
  static const Color lDashedBg = Color(0xFFFDFCFA);
  static const Color lDashedBorder = Color(0xFFCFC9BF);

  // --- Modo oscuro ---
  static const Color dPageBg = Color(0xFF141917);
  static const Color dSurface = Color(0xFF1E2422);
  static const Color dText = Color(0xFFF2F4F2);
  static const Color dTextSec = Color(0xFF9AA39E);
  static const Color dBorder = Color(0xFF2C3432);
  static const Color dBorder2 = Color(0xFF2C3432);
  static const Color dDivider = Color(0xFF26302D);
  static const Color dChip = Color(0xFF26302D);
  static const Color dTint = Color(0xFF16332C);
  static const Color dMuted = Color(0xFF5C6864);
  static const Color dNavInactive = Color(0xFF4A5652);
  static const Color dDashedBg = Color(0xFF1A201D);
  static const Color dDashedBorder = Color(0xFF3A4340);
}
