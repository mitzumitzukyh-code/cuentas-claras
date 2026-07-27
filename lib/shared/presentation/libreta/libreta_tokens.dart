import 'package:flutter/material.dart';

import 'libreta_colors.dart';

/// Tokens del sistema "libreta" que sí cambian entre claro y oscuro.
///
/// Verde, rojo destructivo, ámbar de aviso y los degradados de marca se
/// quedan en [LibretaColors] tal cual (invariantes): la diferencia real
/// entre `#0E9F6E` y `#16A97A` es sutil y no vale la pena arrastrar esa
/// distinción por más de 500 referencias. Lo que sí cambia de verdad —fondo,
/// superficie, texto, bordes— vive aquí, como [ThemeExtension], igual que
/// `AppTokens` en el sistema neumórfico.
@immutable
class LibretaTokens extends ThemeExtension<LibretaTokens> {
  const LibretaTokens({
    required this.textoFuerte,
    required this.textoMuted,
    required this.papel,
    required this.superficie,
    required this.bordeSuave,
    required this.renglon,
    required this.margenCoral,
  });

  final Color textoFuerte;
  final Color textoMuted;
  final Color papel;
  final Color superficie;
  final Color bordeSuave;
  final Color renglon;
  final Color margenCoral;

  static const LibretaTokens claro = LibretaTokens(
    textoFuerte: LibretaColors.textoFuerte,
    textoMuted: LibretaColors.textoMuted,
    papel: LibretaColors.papel,
    superficie: LibretaColors.superficie,
    bordeSuave: LibretaColors.bordeSuave,
    renglon: LibretaColors.renglon,
    margenCoral: LibretaColors.margenCoral,
  );

  /// Fondo "papel" cálido oscuro (`#1C1B18`, nunca negro puro — Lote J), con
  /// espiral, renglón y margen visibles a contraste AA.
  static const LibretaTokens oscuro = LibretaTokens(
    textoFuerte: Color(0xFFF2ECE0),
    textoMuted: Color(0xFFA79E90),
    papel: Color(0xFF1C1B18),
    superficie: Color(0xFF262420),
    bordeSuave: Color(0x1FF2ECE0), // rgba(242,236,224,.12)
    renglon: Color(0x17F2ECE0), // rgba(242,236,224,.09)
    margenCoral: Color(0x8CC1503A), // rgba(193,80,58,.55)
  );

  @override
  LibretaTokens copyWith({
    Color? textoFuerte,
    Color? textoMuted,
    Color? papel,
    Color? superficie,
    Color? bordeSuave,
    Color? renglon,
    Color? margenCoral,
  }) {
    return LibretaTokens(
      textoFuerte: textoFuerte ?? this.textoFuerte,
      textoMuted: textoMuted ?? this.textoMuted,
      papel: papel ?? this.papel,
      superficie: superficie ?? this.superficie,
      bordeSuave: bordeSuave ?? this.bordeSuave,
      renglon: renglon ?? this.renglon,
      margenCoral: margenCoral ?? this.margenCoral,
    );
  }

  @override
  LibretaTokens lerp(ThemeExtension<LibretaTokens>? other, double t) {
    if (other is! LibretaTokens) return this;
    return LibretaTokens(
      textoFuerte: Color.lerp(textoFuerte, other.textoFuerte, t)!,
      textoMuted: Color.lerp(textoMuted, other.textoMuted, t)!,
      papel: Color.lerp(papel, other.papel, t)!,
      superficie: Color.lerp(superficie, other.superficie, t)!,
      bordeSuave: Color.lerp(bordeSuave, other.bordeSuave, t)!,
      renglon: Color.lerp(renglon, other.renglon, t)!,
      margenCoral: Color.lerp(margenCoral, other.margenCoral, t)!,
    );
  }
}

/// Azúcar sintáctico: `context.libreta.textoFuerte`.
extension LibretaTokensX on BuildContext {
  LibretaTokens get libreta =>
      Theme.of(this).extension<LibretaTokens>() ?? LibretaTokens.claro;
}
