import 'package:flutter/material.dart';

/// Entrada "emocional" reutilizable: el hijo aparece con un fundido suave y un
/// pequeño empuje hacia arriba, una sola vez al montarse.
///
/// Pensado para dar vida a las pantallas sin tocar su lógica: se envuelve el
/// contenido y listo. Para un efecto escalonado (cascada), se le pasa un
/// [retardo] creciente a cada elemento.
///
/// Respeta la accesibilidad: si el sistema pide reducir el movimiento
/// (`MediaQuery.disableAnimations`), el hijo aparece de una vez, sin animación.
class EntradaAnimada extends StatefulWidget {
  const EntradaAnimada({
    super.key,
    required this.child,
    this.retardo = Duration.zero,
    this.duracion = const Duration(milliseconds: 460),
    this.desplazamiento = 14,
    this.curva = Curves.easeOutCubic,
  });

  final Widget child;

  /// Espera antes de arrancar. Se usa para escalonar varios elementos.
  final Duration retardo;

  final Duration duracion;

  /// Cuántos píxeles sube el hijo mientras aparece.
  final double desplazamiento;

  final Curve curva;

  @override
  State<EntradaAnimada> createState() => _EntradaAnimadaState();
}

class _EntradaAnimadaState extends State<EntradaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duracion,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Con "reducir movimiento" activo, aparece de una vez.
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
        return;
      }
      if (widget.retardo == Duration.zero) {
        _c.forward();
      } else {
        Future<void>.delayed(widget.retardo, () {
          if (mounted) _c.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curva = CurvedAnimation(parent: _c, curve: widget.curva);
    return AnimatedBuilder(
      animation: curva,
      builder: (context, child) {
        return Opacity(
          opacity: curva.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curva.value) * widget.desplazamiento),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
