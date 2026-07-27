import 'package:flutter/material.dart';

import '../../../../shared/presentation/libreta/libreta.dart';

/// Punto del gráfico (etiqueta del día/mes y el valor total de ventas).
class PuntoGrafico {
  const PuntoGrafico(this.etiqueta, this.total);

  final String etiqueta;
  final double total;
}

/// Gráfica de trazo con animación de revelado.
class GraficoLinea extends StatefulWidget {
  const GraficoLinea({super.key, required this.puntos});

  final List<PuntoGrafico> puntos;

  @override
  State<GraficoLinea> createState() => _GraficoLineaState();
}

class _GraficoLineaState extends State<GraficoLinea>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _controlador.forward();
  }

  @override
  void didUpdateWidget(covariant GraficoLinea old) {
    super.didUpdateWidget(old);
    if (old.puntos != widget.puntos) _controlador.forward(from: 0);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 120,
          child: AnimatedBuilder(
            animation: _controlador,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _LineaPainter(
                puntos: widget.puntos,
                progreso: _controlador.value,
                colorLinea: LibretaColors.verde,
                colorRelleno: const Color(0x1F0E9F6E),
                colorGrid: t.bordeSuave,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final p in widget.puntos)
              Expanded(
                child: Center(
                  child: Text(
                    p.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.textoMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _LineaPainter extends CustomPainter {
  const _LineaPainter({
    required this.puntos,
    required this.progreso,
    required this.colorLinea,
    required this.colorRelleno,
    required this.colorGrid,
  });

  final List<PuntoGrafico> puntos;
  final double progreso;
  final Color colorLinea;
  final Color colorRelleno;
  final Color colorGrid;

  Offset _puntoEn(int i, Size size, double maximo) {
    final n = puntos.length;
    final dx = n > 1 ? size.width / (n - 1) : 0.0;
    final x = n > 1 ? dx * i : size.width / 2;
    final alturaUtil = size.height - 8;
    final frac = maximo == 0 ? 0.0 : puntos[i].total / maximo;
    final y = alturaUtil - alturaUtil * frac + 4;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.isEmpty) return;
    final maximo = puntos.fold<double>(0, (m, p) => p.total > m ? p.total : m);

    final gridPaint = Paint()
      ..color = colorGrid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = (size.height - 8) - (size.height - 8) * f + 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (puntos.length < 2) return;

    final linea = Path();
    for (var i = 0; i < puntos.length; i++) {
      final p = _puntoEn(i, size, maximo);
      if (i == 0) {
        linea.moveTo(p.dx, p.dy);
      } else {
        linea.lineTo(p.dx, p.dy);
      }
    }

    final relleno = Path()
      ..addPath(linea, Offset.zero)
      ..lineTo(_puntoEn(puntos.length - 1, size, maximo).dx, size.height)
      ..lineTo(_puntoEn(0, size, maximo).dx, size.height)
      ..close();
    canvas.drawPath(relleno, Paint()..color = colorRelleno);

    final metrica = linea.computeMetrics().first;
    final trazoParcial = metrica.extractPath(0, metrica.length * progreso);
    canvas.drawPath(
      trazoParcial,
      Paint()
        ..color = colorLinea
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (progreso > 0.98) {
      canvas.drawCircle(
        _puntoEn(puntos.length - 1, size, maximo),
        4,
        Paint()..color = colorLinea,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineaPainter old) =>
      old.puntos != puntos || old.progreso != progreso || old.colorLinea != colorLinea;
}
