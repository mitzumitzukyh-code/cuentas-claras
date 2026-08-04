import 'package:flutter/material.dart';

/// Paleta del sistema de diseño "libreta".
///
/// Vive separada de [AppColors]/[AppTokens]: se aplica lote por lote a las
/// pantallas ya re-vestidas, mientras el resto de la app sigue con el
/// lenguaje neumórfico.
abstract final class LibretaColors {
  const LibretaColors._();

  /// Verde de marca — igual al neumórfico, es el único color que no cambia.
  static const Color verde = Color(0xFF0E9F6E);

  static const Color textoFuerte = Color(0xFF1E2A38);
  static const Color textoMuted = Color(0xFF8A9A96);

  /// Fondo "papel" y superficie de tarjetas.
  static const Color papel = Color(0xFFFAF8F3);
  static const Color superficie = Color(0xFFFFFFFF);

  /// Margen coral de la libreta (línea vertical a 38-54px del borde).
  static const Color margenCoral = Color(0x66C1503A);

  /// Degradado de marca — SOLO portada/auth, nunca en pantallas internas.
  static const List<Color> degradadoMarca = [
    Color(0xFF8C2F22),
    Color(0xFF5A3A28),
    Color(0xFF0E9F6E),
  ];

  static const List<Color> degradadoAuth = [
    Color(0xFF8C2F22),
    Color(0xFF5A3A28),
  ];

  static const Color crema = Color(0xFFFAF8F3);
  static const Color tagline = Color(0xFFF7E7C6);

  static const Color bordeSuave = Color(0x261E2A38); // rgba(30,42,56,.15)
  static const Color renglon = Color(0x1F1E2A38); // rgba(30,42,56,.12)

  /// Rojo destructivo (eliminar, vaciar) — igual al de `AppColors.peligro`.
  static const Color peligro = Color(0xFFC74A3A);

  /// Ámbar de aviso para **texto e iconos** (stock bajo, advertencias,
  /// vencimientos próximos). Es el tono oscuro, el que se lee sobre papel.
  static const Color aviso = Color(0xFFB07D1E);

  /// Ámbar de marca para **superficies**: halos, fondos de tarjeta de aviso,
  /// bordes. Es el brillante, y sobre papel no tiene contraste suficiente
  /// para texto — para eso está [aviso].
  ///
  /// Estaba escrito a mano 43 veces en 22 archivos, siempre como `#F2A93C`.
  /// El brief de marca dice `#F2A93B`: un dígito de diferencia que nadie
  /// decidió, y que aquí se resuelve a favor del brief. La diferencia es de
  /// 1/255 en el canal azul, o sea invisible.
  static const Color ambarSuperficie = Color(0xFFF2A93B);

  /// Fondo de las tarjetas "hero" oscuras (total por cobrar, total de
  /// fiados/proveedores…). Es un color fijo — NO el texto fuerte del tema:
  /// aunque comparte el mismo tono navy que `textoFuerte` en modo claro, no
  /// debe invertirse a crema en modo oscuro, porque ahí dejaría de leerse
  /// como una tarjeta "destacada" oscura.
  static const Color tarjetaOscura = Color(0xFF1E2A38);

  /// Borde de tarjeta hero en modo oscuro — cream tagline al 32% (#F7E7C6).
  /// Contraste de área ≥3:1 sobre `#1C1B18` (mide 3.26:1 según el diseño).
  static const Color bordeHeroOscuro = Color(0x52F7E7C6);
}
