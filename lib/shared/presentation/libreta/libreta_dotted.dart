import 'package:flutter/material.dart';

import 'libreta_tokens.dart';

/// Caja con borde punteado real.
///
/// Flutter no trae bordes discontinuos (`BorderStyle` solo conoce `solid` y
/// `none`), así que el patrón se dibuja a mano. El sistema libreta los usa
/// para lo que es opcional o de mantenimiento —"Contar inventario real",
/// bloques de "solo dueño"— donde un borde sólido pesaría como si fuera una
/// acción principal.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({
    super.key,
    required this.child,
    this.color,
    this.radius = 13,
    this.trazo = 5,
    this.hueco = 4,
    this.grosor = 1.4,
    this.fondo,
  });

  final Widget child;

  /// Color del punteado; por defecto el borde suave del tema.
  final Color? color;
  final double radius;

  /// Largo de cada rayita y del hueco entre ellas.
  final double trazo;
  final double hueco;
  final double grosor;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.libreta.textoMuted.withValues(alpha: 0.55);
    return CustomPaint(
      painter: _DottedPainter(
        color: c,
        radius: radius,
        trazo: trazo,
        hueco: hueco,
        grosor: grosor,
        fondo: fondo,
      ),
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _DottedPainter extends CustomPainter {
  const _DottedPainter({
    required this.color,
    required this.radius,
    required this.trazo,
    required this.hueco,
    required this.grosor,
    required this.fondo,
  });

  final Color color;
  final double radius, trazo, hueco, grosor;
  final Color? fondo;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    if (fondo != null) {
      canvas.drawRRect(rrect, Paint()..color = fondo!);
    }

    final pincel = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;

    // Se recorre el contorno midiendo distancia, que es la única forma de
    // repartir el patrón de manera pareja también sobre las esquinas curvas.
    final camino = Path()..addRRect(rrect);
    for (final metrica in camino.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metrica.length) {
        final fin = (distancia + trazo).clamp(0.0, metrica.length);
        canvas.drawPath(metrica.extractPath(distancia, fin), pincel);
        distancia = fin + hueco;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.trazo != trazo ||
      old.hueco != hueco ||
      old.grosor != grosor ||
      old.fondo != fondo;
}
