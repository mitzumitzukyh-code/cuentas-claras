import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'libreta_colors.dart';
import 'libreta_icono.dart';
import 'libreta_tokens.dart';

/// Estado vacío estándar del sistema "libreta" (réplica de `Lote I ·
/// Estados vacíos`): hoja de cuaderno flotando suavemente, título, detalle,
/// tagline en Caveat y un botón de acción opcional.
///
/// [ilustracion] es la hoja dibujada del paquete de marca. Cuando no se pasa
/// ninguna se cae a la hoja pintada a mano de este archivo, donde [busqueda]
/// elige el garabato: una palomita para "no hay nada todavía" o una lupa
/// tachada para "no hay resultados de tu búsqueda".
class LibretaEstadoVacio extends StatefulWidget {
  const LibretaEstadoVacio({
    super.key,
    required this.titulo,
    required this.detalle,
    this.tagline,
    this.boton,
    this.busqueda = false,
    this.ilustracion,
  });

  final String titulo;
  final String detalle;

  /// Frase corta en Caveat, ej. "tu primera venta te espera".
  final String? tagline;

  final Widget? boton;
  final bool busqueda;

  /// Ilustración del paquete de marca. Entra y flota con la misma animación
  /// que la hoja pintada, así que cambiar una por otra no altera el ritmo de
  /// la pantalla.
  final Ilustracion? ilustracion;

  @override
  State<LibretaEstadoVacio> createState() => _LibretaEstadoVacioState();
}

class _LibretaEstadoVacioState extends State<LibretaEstadoVacio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controlador.isAnimating && !MediaQuery.of(context).disableAnimations) {
      _controlador.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HojaAnimated(
            controlador: _controlador,
            busqueda: widget.busqueda,
            ilustracion: widget.ilustracion,
            superficie: t.superficie,
            textoFuerte: t.textoFuerte,
            textoMuted: t.textoMuted,
            margenCoral: t.margenCoral,
            bordeSuave: t.bordeSuave,
          ),
          const SizedBox(height: 8),
          _TextoEscalonado(
            inicio: const Duration(milliseconds: 500),
            child: Text(
              widget.titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _TextoEscalonado(
            inicio: const Duration(milliseconds: 700),
            child: SizedBox(
              width: 260,
              child: Text(
                widget.detalle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: t.textoMuted,
                ),
              ),
            ),
          ),
          if (widget.tagline != null) ...[
            const SizedBox(height: 4),
            _TextoEscalonado(
              inicio: const Duration(milliseconds: 900),
              child: Text(
                widget.tagline!,
                style: GoogleFonts.caveat(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: widget.busqueda ? t.textoMuted : LibretaColors.verde,
                ),
              ),
            ),
          ],
          if (widget.boton != null) ...[
            const SizedBox(height: 16),
            _TextoEscalonado(
              inicio: const Duration(milliseconds: 1100),
              child: widget.boton!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Hoja de cuaderno que entra con rebote elástico desde abajo y flota suave.
class _HojaAnimated extends StatefulWidget {
  const _HojaAnimated({
    required this.controlador,
    required this.busqueda,
    required this.ilustracion,
    required this.superficie,
    required this.textoFuerte,
    required this.textoMuted,
    required this.margenCoral,
    required this.bordeSuave,
  });

  final AnimationController controlador;
  final bool busqueda;
  final Ilustracion? ilustracion;
  final Color superficie, textoFuerte, textoMuted, margenCoral, bordeSuave;

  @override
  State<_HojaAnimated> createState() => _HojaAnimatedState();
}

class _HojaAnimatedState extends State<_HojaAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada;

  @override
  void initState() {
    super.initState();
    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entrada.forward();
  }

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controlador, _entrada]),
      builder: (context, child) {
        final floatY = -8 * Curves.easeInOut.transform(widget.controlador.value);
        final entradaY = (1 - Curves.elasticOut.transform(_entrada.value)) * 80;
        final opacidad = _entrada.value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, floatY + entradaY),
          child: Opacity(opacity: opacidad, child: child),
        );
      },
      child: SizedBox(
        width: 130,
        height: 130,
        child: widget.ilustracion != null
            ? LibretaIlustracion(widget.ilustracion!, size: 130)
            : CustomPaint(
                painter: _HojaPainter(
                  busqueda: widget.busqueda,
                  colorPagina: widget.superficie,
                  colorTexto: widget.textoFuerte,
                  colorMuted: widget.textoMuted,
                  colorMargen: widget.margenCoral,
                  colorRenglon: widget.bordeSuave,
                ),
              ),
      ),
    );
  }
}

/// Texto que aparece con fade + deslizamiento hacia arriba, escalonado.
class _TextoEscalonado extends StatefulWidget {
  const _TextoEscalonado({required this.inicio, required this.child});

  final Duration inicio;
  final Widget child;

  @override
  State<_TextoEscalonado> createState() => _TextoEscalonadoState();
}

class _TextoEscalonadoState extends State<_TextoEscalonado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    Future.delayed(widget.inicio, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final dy = (1 - Curves.easeOutCubic.transform(_ctrl.value)) * 24;
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(opacity: _ctrl.value, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Hoja de cuaderno realista: espirales que atraviesan agujeros, margen coral,
/// renglones parejos y un garabato — palomita para "vacío" o lupa tachada para
/// "sin resultados".
class _HojaPainter extends CustomPainter {
  const _HojaPainter({
    required this.busqueda,
    required this.colorPagina,
    required this.colorTexto,
    required this.colorMuted,
    required this.colorMargen,
    required this.colorRenglon,
  });

  final bool busqueda;
  final Color colorPagina;
  final Color colorTexto;
  final Color colorMuted;
  final Color colorMargen;
  final Color colorRenglon;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.save();
    canvas.scale(s, s);

    // ───── Sombra difuminada debajo de la hoja ─────
    final sombra = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 26, 84, 88),
        const Radius.circular(9),
      ),
      sombra,
    );

    // ───── Cuerpo de la página ─────
    final pagina = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 24, 84, 88),
      const Radius.circular(5),
    );
    canvas.drawRRect(pagina, Paint()..color = colorPagina);
    canvas.drawRRect(
      pagina,
      Paint()
        ..color = colorTexto.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ───── Margen coral (raya vertical) ─────
    canvas.drawLine(
      const Offset(33, 30),
      const Offset(33, 108),
      Paint()
        ..color = colorMargen
        ..strokeWidth = 1.5,
    );

    // ───── Renglones (líneas de guía horizontales) ─────
    final pincelRenglon = Paint()
      ..color = colorRenglon.withValues(alpha: 0.4)
      ..strokeWidth = 0.7;
    for (double y = 48; y <= 100; y += 10) {
      canvas.drawLine(
        Offset(37, y),
        Offset(94, y),
        pincelRenglon,
      );
    }

    // ───── Agujeros de la espiral ─────
    final colorHueco = colorPagina;
    final bordeHueco = Paint()
      ..color = colorTexto.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rellenoHueco = Paint()..color = colorHueco;
    final posAgujeros = [24.0, 35.0, 46.0, 57.0, 68.0, 79.0, 90.0];

    for (final cx in posAgujeros) {
      // Círculo del agujero (perforación en el papel)
      canvas.drawCircle(Offset(cx, 30), 3.4, rellenoHueco);
      canvas.drawCircle(Offset(cx, 30), 3.4, bordeHueco);

      // Espiral metálica: arco superior + arco inferior
      final espiral = Paint()
        ..color = colorTexto.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, 30), width: 8, height: 12),
        0,
        pi,
        false,
        espiral,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, 30), width: 8, height: 12),
        pi,
        pi,
        false,
        espiral,
      );
    }

    // ───── Garabato central (palomita o lupa) ─────
    if (busqueda) {
      final lupa = Paint()
        ..color = colorMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(const Offset(54, 67), 14, lupa);
      canvas.drawLine(const Offset(64, 75), const Offset(76, 87), lupa);
      final marca = Paint()
        ..color = colorRenglon.withValues(alpha: 0.6)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(49, 67), const Offset(59, 67), marca);
      canvas.drawLine(const Offset(54, 62), const Offset(54, 72), marca);
    } else {
      // Palomita (checkmark) trazada con un lápiz al lado
      final trazo = Path()
        ..moveTo(40, 78)
        ..quadraticBezierTo(50, 70, 58, 78)
        ..quadraticBezierTo(66, 86, 76, 78);
      canvas.drawPath(
        trazo,
        Paint()
          ..color = LibretaColors.verde
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round,
      );

      // Lápiz amarillo inclinado
      canvas.save();
      canvas.translate(82, 82);
      canvas.rotate(38 * 3.14159 / 180);
      final lapiz = Paint()..color = const Color(0xFFF2A93C);
      final lapizTrazo = Paint()
        ..color = colorTexto
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      final cuerpo = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-4, -28, 8, 32),
        const Radius.circular(2),
      );
      canvas.drawRRect(cuerpo, lapiz);
      canvas.drawRRect(cuerpo, lapizTrazo);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -6, 8, 2.5),
        Paint()..color = colorTexto,
      );
      final punta = Path()
        ..moveTo(-4, 2)
        ..lineTo(0, 10)
        ..lineTo(4, 2)
        ..close();
      canvas.drawPath(punta, Paint()..color = colorTexto);
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HojaPainter oldDelegate) =>
      oldDelegate.busqueda != busqueda ||
      oldDelegate.colorPagina != colorPagina ||
      oldDelegate.colorTexto != colorTexto ||
      oldDelegate.colorMuted != colorMuted ||
      oldDelegate.colorMargen != colorMargen ||
      oldDelegate.colorRenglon != colorRenglon;
}
