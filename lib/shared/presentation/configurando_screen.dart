import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'libreta/libreta.dart';

class ConfigurandoScreen extends ConsumerStatefulWidget {
  const ConfigurandoScreen({super.key});

  @override
  ConsumerState<ConfigurandoScreen> createState() => _ConfigurandoScreenState();
}

class _ConfigurandoScreenState extends ConsumerState<ConfigurandoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LibretaColors.papel,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final breath = 1 + 0.03 * math.sin(_ctrl.value * 2 * math.pi);
                    return Transform.scale(
                      scale: breath,
                      child: SizedBox(
                        width: 74,
                        height: 74,
                        child: CustomPaint(
                          size: const Size(74, 74),
                          painter: _NotebookPainter(checkProgress: _ctrl.value),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _DotsAnimados(ctrl: _ctrl),
              const SizedBox(height: 24),
              const Text(
                'Configurando tu cuenta…',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LibretaColors.textoFuerte,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const SizedBox(
                width: 260,
                child: Text(
                  'Preparando tu cuaderno. Esto toma solo unos segundos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: LibretaColors.textoMuted,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'casi listo',
                    style: GoogleFonts.caveat(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: LibretaColors.verde,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined,
                      size: 15, color: LibretaColors.verde),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notebook painter (with animated checkmark)
// ---------------------------------------------------------------------------
class _NotebookPainter extends CustomPainter {
  _NotebookPainter({required this.checkProgress});

  final double checkProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..color = LibretaColors.textoFuerte
      ..strokeCap = StrokeCap.round;

    // Notebook body
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(12 * s, 8 * s, 42 * s, 48 * s),
      topLeft: Radius.circular(6 * s),
      topRight: Radius.circular(6 * s),
      bottomLeft: Radius.circular(6 * s),
      bottomRight: Radius.circular(6 * s),
    );
    fill.color = Colors.white;
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, stroke);

    // Coral margin line
    final marginPaint = Paint()
      ..color = const Color.fromRGBO(193, 80, 58, 0.6)
      ..strokeWidth = 2 * s;
    canvas.drawLine(
      Offset(20 * s, 10 * s),
      Offset(20 * s, 54 * s),
      marginPaint,
    );

    // Spiral holes
    final holeStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..color = LibretaColors.textoFuerte;
    for (final x in [20 * s, 29 * s, 38 * s, 47 * s]) {
      canvas.drawCircle(Offset(x, 8 * s), 2.6 * s, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(x, 8 * s), 2.6 * s, holeStroke);
    }

    // Animated checkmark
    final checkPath = Path()
      ..moveTo(23 * s, 35 * s)
      ..lineTo(31 * s, 43 * s)
      ..lineTo(47 * s, 23 * s);

    final metrics = checkPath.computeMetrics();
    final totalLength = metrics.fold<double>(0, (s, m) => s + m.length);
    final drawLength = totalLength * checkProgress;

    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5 * s
      ..color = LibretaColors.verde
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    var accumulated = 0.0;
    for (final metric in metrics) {
      if (accumulated + metric.length >= drawLength) {
        final remaining = drawLength - accumulated;
        final pathPart = metric.extractPath(0, remaining);
        canvas.drawPath(pathPart, checkPaint);
        break;
      } else {
        canvas.drawPath(metric.extractPath(0, metric.length), checkPaint);
        accumulated += metric.length;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookPainter old) =>
      old.checkProgress != checkProgress;
}

// ---------------------------------------------------------------------------
// 3 bouncing dots
// ---------------------------------------------------------------------------
class _DotsAnimados extends StatelessWidget {
  const _DotsAnimados({required this.ctrl});

  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _Dot(delay: 0.0 + i * 0.2, ctrl: ctrl),
            ],
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.delay, required this.ctrl});

  final double delay;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    final progress = ((ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
    final t = (progress < 0.5) ? progress * 2 : (1 - progress) * 2;
    final scale = 0.75 + 0.25 * t;
    final opacity = 0.2 + 0.8 * t;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: LibretaColors.verde.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
