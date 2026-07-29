import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/conectividad_provider.dart';
import 'libreta_colors.dart';
import 'libreta_tokens.dart';

/// Tira de "anillos" de espiral en el borde superior de una tarjeta de papel.
///
/// Réplica del `radial-gradient` repetido del prototipo: círculos vacíos
/// espaciados cada 26px. Se pinta con [CustomPainter] porque un
/// `BoxDecoration` con gradiente no puede repetir un patrón de este tipo.
class LibretaSpiralStrip extends StatelessWidget {
  const LibretaSpiralStrip({
    super.key,
    this.height = 16,
    this.color = const Color(0x481E2A38), // rgba(30,42,56,.28)
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SpiralPainter(color: color)),
    );
  }
}

class _SpiralPainter extends CustomPainter {
  const _SpiralPainter({required this.color});

  final Color color;
  static const double _paso = 26;
  static const double _radio = 4.25;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()..color = color;
    final n = (size.width / _paso).ceil() + 1;
    final inicioX = (size.width - (n - 1) * _paso) / 2;
    final cy = size.height / 2;
    for (var i = 0; i < n; i++) {
      final cx = inicioX + i * _paso;
      canvas.drawCircle(Offset(cx, cy), _radio, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _SpiralPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Flecha de retroceso translúcida sobre el degradado de marca (Registro,
/// Recuperar). Único patrón de "volver" del sistema — no usar `AppBar`.
class LibretaBackButton extends StatelessWidget {
  const LibretaBackButton({super.key, this.onTap, this.oscuro = false});

  final VoidCallback? onTap;

  /// `true` cuando se usa sobre fondo claro (papel) en vez del degradado.
  final bool oscuro;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: oscuro ? t.bordeSuave : const Color(0x24FFFFFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: oscuro ? t.textoFuerte : LibretaColors.papel,
        ),
      ),
    );
  }
}

/// Fondo estándar de una pantalla interna del sistema "libreta": papel y la
/// espiral asomando arriba. El contenido propio de cada pantalla deja
/// [padIzquierdo]px de sangrado lateral.
///
/// **Sin raya coral.** La línea vertical de margen se retiró de las pantallas
/// de producto (`system-diseno-libreta.md` § Sangrado): sobrevive solo en las
/// ilustraciones/iconos de libreta ([LibretaEstadoVacio]) y en las imágenes
/// exportadas a WhatsApp. Era además lo único que justificaba el sangrado de
/// 54px; sin ella, el sangrado es el de lectura ([padIzquierdo]).
class LibretaPageBackground extends StatelessWidget {
  /// Sangrado lateral estándar del sistema "libreta": 24px (decisión D1).
  /// Ver `Comparación sangrado.dc.html` col. B.
  static const double padIzquierdo = 24;
  const LibretaPageBackground({
    super.key,
    required this.child,
    this.spiral = true,
  });

  final Widget child;
  final bool spiral;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.papel),
      child: Stack(
        children: [
          if (spiral)
            Positioned(
              // Bajo la barra de estado, no debajo de ella: en el diseño la
              // espiral asoma en el borde de la hoja, y el marco del teléfono
              // empieza donde termina el reloj del sistema.
              top: MediaQuery.paddingOf(context).top + 6,
              left: 0,
              right: 0,
              child: LibretaSpiralStrip(
                height: 18,
                color: t.textoFuerte.withValues(alpha: 0.30),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Pastilla ámbar compacta "Sin conexión" que va bajo el título de las
/// pantallas internas. Solo visible cuando el teléfono pierde la red.
/// Alimentada por [hayConexionProvider].
class LibretaAvisoOfflineCompacto extends ConsumerWidget {
  const LibretaAvisoOfflineCompacto({super.key, this.copy});

  /// Texto alternativo para pantallas como Estado que necesitan copy distinto.
  final String? copy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectado = ref.watch(hayConexionProvider).valueOrNull ?? true;
    if (conectado) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x24F2A93C),
        border: Border.all(color: const Color(0x59F2A93C)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 13, color: Color(0xFFB07D1E)),
          const SizedBox(width: 7),
          Text(
            copy ?? 'Sin conexión — se guarda y sube solo',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB07D1E),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de "papel" con esquinas superiores redondeadas y la tira de
/// espiral asomando por encima — el contenedor estándar de las pantallas de
/// identidad (Login, Registro, Recuperar).
class LibretaPaperCard extends StatelessWidget {
  const LibretaPaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 26, 24, 24),
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: LibretaColors.papel,
          borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: const LibretaSpiralStrip(),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
