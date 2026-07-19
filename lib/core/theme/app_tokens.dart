import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tokens de diseño dependientes del modo (claro/oscuro).
///
/// Réplica del objeto `t` que el prototipo HTML calcula en `theme()`. Se expone
/// como [ThemeExtension] para que cada widget lea `context.tokens` sin tener que
/// preguntar por el brillo del tema.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.pageBg,
    required this.surface,
    required this.text,
    required this.textSec,
    required this.border,
    required this.border2,
    required this.divider,
    required this.chip,
    required this.tint,
    required this.muted,
    required this.navInactive,
    required this.dashedBg,
    required this.dashedBorder,
    required this.shadowRaised,
    required this.shadowRaisedSm,
    required this.shadowBtn,
    required this.insetDark,
    required this.insetLight,
  });

  final Color pageBg;
  final Color surface;
  final Color text;
  final Color textSec;
  final Color border;
  final Color border2;
  final Color divider;
  final Color chip;
  final Color tint;
  final Color muted;
  final Color navInactive;
  final Color dashedBg;
  final Color dashedBorder;

  /// Relieve estándar de tarjetas grandes.
  final List<BoxShadow> shadowRaised;

  /// Relieve reducido de tarjetas pequeñas, píldoras e iconos.
  final List<BoxShadow> shadowRaisedSm;

  /// Relieve teñido de verde para botones primarios.
  final List<BoxShadow> shadowBtn;

  /// Color de la sombra interior superior-izquierda (campos hundidos).
  final Color insetDark;

  /// Color del brillo interior inferior-derecha (campos hundidos).
  final Color insetLight;

  static const AppTokens claro = AppTokens(
    pageBg: AppColors.lPageBg,
    surface: AppColors.lSurface,
    text: AppColors.lText,
    textSec: AppColors.lTextSec,
    border: AppColors.lBorder,
    border2: AppColors.lBorder2,
    divider: AppColors.lDivider,
    chip: AppColors.lChip,
    tint: AppColors.lTint,
    muted: AppColors.lMuted,
    navInactive: AppColors.lNavInactive,
    dashedBg: AppColors.lDashedBg,
    dashedBorder: AppColors.lDashedBorder,
    shadowRaised: [
      BoxShadow(
        color: Color(0x61A39D90),
        offset: Offset(8, 8),
        blurRadius: 18,
      ),
      BoxShadow(
        color: Color(0xE6FFFFFF),
        offset: Offset(-6, -6),
        blurRadius: 14,
      ),
    ],
    shadowRaisedSm: [
      BoxShadow(
        color: Color(0x52A39D90),
        offset: Offset(4, 4),
        blurRadius: 10,
      ),
      BoxShadow(
        color: Color(0xE6FFFFFF),
        offset: Offset(-3, -3),
        blurRadius: 8,
      ),
    ],
    shadowBtn: [
      BoxShadow(
        color: Color(0x590F6B5C),
        offset: Offset(6, 6),
        blurRadius: 14,
      ),
      BoxShadow(
        color: Color(0xB3FFFFFF),
        offset: Offset(-4, -4),
        blurRadius: 10,
      ),
    ],
    insetDark: Color(0x4DA39D90),
    insetLight: Color(0xE6FFFFFF),
  );

  static const AppTokens oscuro = AppTokens(
    pageBg: AppColors.dPageBg,
    surface: AppColors.dSurface,
    text: AppColors.dText,
    textSec: AppColors.dTextSec,
    border: AppColors.dBorder,
    border2: AppColors.dBorder2,
    divider: AppColors.dDivider,
    chip: AppColors.dChip,
    tint: AppColors.dTint,
    muted: AppColors.dMuted,
    navInactive: AppColors.dNavInactive,
    dashedBg: AppColors.dDashedBg,
    dashedBorder: AppColors.dDashedBorder,
    shadowRaised: [
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(8, 8),
        blurRadius: 18,
      ),
      BoxShadow(
        color: Color(0x0AFFFFFF),
        offset: Offset(-6, -6),
        blurRadius: 14,
      ),
    ],
    shadowRaisedSm: [
      BoxShadow(
        color: Color(0x73000000),
        offset: Offset(4, 4),
        blurRadius: 10,
      ),
      BoxShadow(
        color: Color(0x0AFFFFFF),
        offset: Offset(-3, -3),
        blurRadius: 8,
      ),
    ],
    shadowBtn: [
      BoxShadow(
        color: Color(0x80000000),
        offset: Offset(6, 6),
        blurRadius: 14,
      ),
      BoxShadow(
        color: Color(0x0AFFFFFF),
        offset: Offset(-4, -4),
        blurRadius: 10,
      ),
    ],
    insetDark: Color(0x80000000),
    insetLight: Color(0x08FFFFFF),
  );

  @override
  AppTokens copyWith({
    Color? pageBg,
    Color? surface,
    Color? text,
    Color? textSec,
    Color? border,
    Color? border2,
    Color? divider,
    Color? chip,
    Color? tint,
    Color? muted,
    Color? navInactive,
    Color? dashedBg,
    Color? dashedBorder,
    List<BoxShadow>? shadowRaised,
    List<BoxShadow>? shadowRaisedSm,
    List<BoxShadow>? shadowBtn,
    Color? insetDark,
    Color? insetLight,
  }) {
    return AppTokens(
      pageBg: pageBg ?? this.pageBg,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textSec: textSec ?? this.textSec,
      border: border ?? this.border,
      border2: border2 ?? this.border2,
      divider: divider ?? this.divider,
      chip: chip ?? this.chip,
      tint: tint ?? this.tint,
      muted: muted ?? this.muted,
      navInactive: navInactive ?? this.navInactive,
      dashedBg: dashedBg ?? this.dashedBg,
      dashedBorder: dashedBorder ?? this.dashedBorder,
      shadowRaised: shadowRaised ?? this.shadowRaised,
      shadowRaisedSm: shadowRaisedSm ?? this.shadowRaisedSm,
      shadowBtn: shadowBtn ?? this.shadowBtn,
      insetDark: insetDark ?? this.insetDark,
      insetLight: insetLight ?? this.insetLight,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSec: Color.lerp(textSec, other.textSec, t)!,
      border: Color.lerp(border, other.border, t)!,
      border2: Color.lerp(border2, other.border2, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
      tint: Color.lerp(tint, other.tint, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      dashedBg: Color.lerp(dashedBg, other.dashedBg, t)!,
      dashedBorder: Color.lerp(dashedBorder, other.dashedBorder, t)!,
      shadowRaised: BoxShadow.lerpList(shadowRaised, other.shadowRaised, t)!,
      shadowRaisedSm:
          BoxShadow.lerpList(shadowRaisedSm, other.shadowRaisedSm, t)!,
      shadowBtn: BoxShadow.lerpList(shadowBtn, other.shadowBtn, t)!,
      insetDark: Color.lerp(insetDark, other.insetDark, t)!,
      insetLight: Color.lerp(insetLight, other.insetLight, t)!,
    );
  }
}

/// Azúcar sintáctico: `context.tokens.surface`.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}
