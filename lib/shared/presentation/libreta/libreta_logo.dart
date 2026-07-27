import 'package:flutter/material.dart';

/// Logo de marca del sistema "libreta": cuaderno con anillos, lomo coral y
/// check verde. Réplica del SVG `viewBox="0 0 64 64"` del prototipo.
class LibretaLogo extends StatelessWidget {
  const LibretaLogo({super.key, this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LibretaLogoPainter()),
    );
  }
}

class _LibretaLogoPainter extends CustomPainter {
  const _LibretaLogoPainter();

  static const double _vb = 64;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _vb;
    canvas.save();
    canvas.scale(s, s);

    final tapa = Paint()..color = const Color(0xFFFAF8F3);
    final trazo = Paint()
      ..color = const Color(0xFF1E2A38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 8, 42, 48),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, tapa);
    canvas.drawRRect(rect, trazo);

    canvas.drawLine(
      const Offset(20, 10),
      const Offset(20, 54),
      Paint()
        ..color = const Color(0x99C1503A)
        ..strokeWidth = 2,
    );

    final anillo = Paint()
      ..color = const Color(0xFFFAF8F3)
      ..style = PaintingStyle.fill;
    final anilloTrazo = Paint()
      ..color = const Color(0xFF1E2A38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final cx in [20.0, 29.0, 38.0, 47.0]) {
      canvas.drawCircle(Offset(cx, 8), 2.6, anillo);
      canvas.drawCircle(Offset(cx, 8), 2.6, anilloTrazo);
    }

    final check = Path()
      ..moveTo(23, 35)
      ..lineTo(31, 43)
      ..lineTo(47, 23);
    canvas.drawPath(
      check,
      Paint()
        ..color = const Color(0xFF0E9F6E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LibretaLogoPainter oldDelegate) => false;
}
