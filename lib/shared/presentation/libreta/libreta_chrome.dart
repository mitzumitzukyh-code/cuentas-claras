import 'package:flutter/material.dart';

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

/// Margen vertical coral a 38px del borde izquierdo — el renglón de libreta
/// de las pantallas internas (Cobrar, Historial, Detalle, Pendientes…).
class LibretaCoralMargin extends StatelessWidget {
  const LibretaCoralMargin({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 38,
      width: 2,
      child: ColoredBox(color: context.libreta.margenCoral),
    );
  }
}

/// Fondo estándar de una pantalla interna del sistema "libreta": papel,
/// espiral asomando arriba y margen coral a la izquierda. El contenido
/// propio de cada pantalla debe dejar ~54px de margen izquierdo para no
/// pisar la línea.
class LibretaPageBackground extends StatelessWidget {
  const LibretaPageBackground({
    super.key,
    required this.child,
    this.spiral = true,
    this.coralMargin = true,
  });

  final Widget child;
  final bool spiral;
  final bool coralMargin;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return DecoratedBox(
      decoration: BoxDecoration(color: t.papel),
      child: Stack(
        children: [
          if (spiral)
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: LibretaSpiralStrip(
                height: 18,
                color: t.textoFuerte.withValues(alpha: 0.30),
              ),
            ),
          if (coralMargin) const LibretaCoralMargin(),
          child,
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
