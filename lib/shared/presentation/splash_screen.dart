import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'libreta/libreta.dart';

/// Pantalla de carga mientras se resuelve el estado de sesión.
///
/// Réplica del bloque `P0 · SPLASH` de `Lote A · Identidad`: tapa de cuaderno
/// que se abre sobre un degradado vinotinto→verde, con el check dibujándose
/// a mano y el tagline en Caveat. La navegación real la decide el router
/// (según [sesionProvider]); esta pantalla es puramente decorativa mientras
/// tanto.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _loop;
  late final AnimationController _salida;
  bool _reducirMovimiento = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    );
    _salida = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    // Inicia la salida 600ms antes del redirect para fundir a negro suavemente
    Future.delayed(const Duration(milliseconds: 2900), () {
      if (mounted) _salida.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Solo se lee una vez: si el ajuste cambia a mitad de la animación no
    // vale la pena reconstruir el estado, la app se cierra y reabre.
    if (!_intro.isAnimating && _intro.value == 0) {
      _reducirMovimiento = MediaQuery.of(context).disableAnimations;
      if (_reducirMovimiento) {
        _intro.value = 1;
      } else {
        _intro.forward();
        _loop.repeat();
      }
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    _salida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _salida.drive(Tween(begin: 1, end: 0)),
        child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: LibretaColors.degradadoMarca,
            stops: [0, 0.46, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Renglones de cuaderno sobre el degradado, al 9%: es lo que hace
            // que la portada se lea como papel y no como un fondo de color.
            const Positioned.fill(
              child: CustomPaint(painter: _RenglonesPainter()),
            ),
            const Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: LibretaSpiralStrip(
                height: 16,
                color: Color(0x8CFFFFFF),
              ),
            ),
            if (!_reducirMovimiento)
              AnimatedBuilder(
                animation: _loop,
                builder: (context, _) => _Resplandor(t: _loop.value),
              )
            else
              const _Resplandor(t: 0.5),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Tapa(intro: _intro, loop: _loop, quieto: _reducirMovimiento),
                  const SizedBox(height: 26),
                  _Titulo(intro: _intro, quieto: _reducirMovimiento),
                  const SizedBox(height: 46),
                  _Cargando(intro: _intro, quieto: _reducirMovimiento),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Resplandor pulsante detrás de la tapa (`@keyframes glowPulse`).
class _Resplandor extends StatelessWidget {
  const _Resplandor({required this.t});

  /// 0..1 dentro del ciclo de 4.6s del prototipo.
  final double t;

  @override
  Widget build(BuildContext context) {
    final onda = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1 suave
    final escala = 0.92 + onda * 0.14;
    final opacidad = 0.45 + onda * 0.55;

    return Align(
      alignment: const Alignment(0, -0.24),
      child: Opacity(
        opacity: opacidad,
        child: Transform.scale(
          scale: escala,
          child: Container(
            width: 300,
            height: 300,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x73F7E7C6), Colors.transparent],
                stops: [0, 0.62],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tapa del cuaderno: se abre en perspectiva y luego flota suavemente.
class _Tapa extends StatelessWidget {
  const _Tapa({required this.intro, required this.loop, required this.quieto});

  final AnimationController intro;
  final AnimationController loop;
  final bool quieto;

  @override
  Widget build(BuildContext context) {
    final abrir = CurvedAnimation(
      parent: intro,
      curve: const Interval(0, 1, curve: Curves.easeOutCubic),
    );
    final check = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.55, 1, curve: Curves.easeInOutCubic),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([intro, loop]),
      builder: (context, _) {
        final bob = quieto
            ? 0.0
            : math.sin((loop.value + 0.22) * 2 * math.pi) * 4.5;
        final anguloBob = quieto
            ? 0.0
            : math.sin((loop.value + 0.22) * 2 * math.pi) * -0.028;
        final anguloApertura = (1 - abrir.value) * -1.25; // rad, ~-72°

        return Opacity(
          opacity: abrir.value,
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(anguloApertura)
              ..translate(0.0, bob)
              ..rotateZ(anguloBob),
            child: _CheckAnimado(progreso: check.value),
          ),
        );
      },
    );
  }
}

/// El logo de la libreta con el check dibujándose trazo a trazo.
class _CheckAnimado extends StatelessWidget {
  const _CheckAnimado({required this.progreso});

  final double progreso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(painter: _CheckAnimadoPainter(progreso: progreso)),
    );
  }
}

class _CheckAnimadoPainter extends CustomPainter {
  const _CheckAnimadoPainter({required this.progreso});

  final double progreso;
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
      ..strokeWidth = 2.5;
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

    final anillo = Paint()..color = const Color(0xFFFAF8F3);
    final anilloTrazo = Paint()
      ..color = const Color(0xFF1E2A38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final cx in [20.0, 29.0, 38.0, 47.0]) {
      canvas.drawCircle(Offset(cx, 8), 2.6, anillo);
      canvas.drawCircle(Offset(cx, 8), 2.6, anilloTrazo);
    }

    if (progreso > 0) {
      final path = Path()
        ..moveTo(23, 35)
        ..lineTo(31, 43)
        ..lineTo(47, 23);
      final metrica = path.computeMetrics().first;
      final parcial = metrica.extractPath(0, metrica.length * progreso);
      canvas.drawPath(
        parcial,
        Paint()
          ..color = const Color(0xFF0E9F6E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CheckAnimadoPainter oldDelegate) =>
      oldDelegate.progreso != progreso;
}

/// "Cuenta Clara" + tagline en Caveat con el subrayado dibujándose.
class _Titulo extends StatelessWidget {
  const _Titulo({required this.intro, required this.quieto});

  final AnimationController intro;
  final bool quieto;

  @override
  Widget build(BuildContext context) {
    final aparecer = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    final subrayado = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.75, 1, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: intro,
      builder: (context, _) {
        return Opacity(
          opacity: aparecer.value,
          child: Transform.translate(
            offset: Offset(0, (1 - aparecer.value) * 10),
            child: Column(
              children: [
                const Text(
                  'Cuenta Clara',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFAF8F3),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'tus cuentas, claras como el agua',
                  style: GoogleFonts.caveat(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.tagline,
                  ),
                ),
                SizedBox(
                  width: 220,
                  height: 9,
                  child: CustomPaint(
                    painter: _SubrayadoPainter(progreso: subrayado.value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Trazo ondulado bajo el tagline (`@keyframes drawUnderline`).
class _SubrayadoPainter extends CustomPainter {
  const _SubrayadoPainter({required this.progreso});

  final double progreso;

  @override
  void paint(Canvas canvas, Size size) {
    if (progreso <= 0) return;
    final path = Path()
      ..moveTo(4, 6)
      ..quadraticBezierTo(size.width * .32, 1, size.width * .55, 5)
      ..quadraticBezierTo(size.width * .78, 8, size.width - 4, 4);
    final metrica = path.computeMetrics().first;
    final parcial = metrica.extractPath(0, metrica.length * progreso);
    canvas.drawPath(
      parcial,
      Paint()
        ..color = LibretaColors.tagline.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SubrayadoPainter oldDelegate) =>
      oldDelegate.progreso != progreso;
}

/// Spinner + "abriendo tu libreta…" al pie de la pantalla.
class _Cargando extends StatelessWidget {
  const _Cargando({required this.intro, required this.quieto});

  final AnimationController intro;
  final bool quieto;

  @override
  Widget build(BuildContext context) {
    final aparecer = CurvedAnimation(
      parent: intro,
      curve: const Interval(0.7, 1, curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: intro,
      builder: (context, _) => Opacity(
        opacity: aparecer.value,
        child: Column(
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFFAF8F3),
                backgroundColor: Color(0x4DFFFFFF),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'abriendo tu libreta…',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                  color: Color(0xA6FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Renglones horizontales cada 33px, al 9% de blanco (`Lote A · P0`).
class _RenglonesPainter extends CustomPainter {
  const _RenglonesPainter();

  static const double _paso = 33;

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = const Color(0x17FFFFFF)
      ..strokeWidth = 1;
    for (var y = _paso; y < size.height; y += _paso) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _RenglonesPainter oldDelegate) => false;
}
