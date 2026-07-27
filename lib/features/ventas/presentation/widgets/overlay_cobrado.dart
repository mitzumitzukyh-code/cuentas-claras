import 'package:flutter/material.dart';

import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/presentation/libreta/libreta.dart';

/// Overlay animado que muestra "¡Cobrado!" con un check verde después de
/// registrar una venta.
class OverlayCobrado extends StatefulWidget {
  const OverlayCobrado({super.key, required this.monto, required this.onTap});

  final double monto;
  final VoidCallback onTap;

  @override
  State<OverlayCobrado> createState() => _OverlayCobradoState();
}

class _OverlayCobradoState extends State<OverlayCobrado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        color: t.papel.withValues(alpha: 0.95),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) => SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _CheckPainter(progreso: _c.value),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '¡Cobrado!',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: LibretaColors.verde,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${MoneyFormatter.usd(widget.monto)} registrado',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.textoMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progreso});

  final double progreso;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.width / 2 - 6;

    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..color = const Color(0x380E9F6E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (progreso <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.7)
      ..lineTo(size.width * 0.76, size.height * 0.32);
    final metrica = path.computeMetrics().first;
    final t = (progreso.clamp(0.2, 1.0) - 0.2) / 0.8;
    final parcial = metrica.extractPath(0, metrica.length * t.clamp(0, 1));
    canvas.drawPath(
      parcial,
      Paint()
        ..color = LibretaColors.verde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progreso != progreso;
}
