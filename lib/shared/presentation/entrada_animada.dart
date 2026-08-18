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

  /// La curva se crea UNA vez, no en cada `build`.
  ///
  /// Un `CurvedAnimation` se suscribe a su controller al nacer, así que uno
  /// nuevo por fotograma deja detrás una cadena de oyentes que nadie
  /// desengancha — es una fuga, y el rastreo de fugas de Flutter la señala en
  /// debug. Por eso también se desecha en [dispose].
  late final CurvedAnimation _curva = CurvedAnimation(
    parent: _c,
    curve: widget.curva,
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
    _curva.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // El fundido va por `FadeTransition` y no por `Opacity`: escucha la
    // animación desde el render object y solo REPINTA, sin reconstruir el
    // widget en cada fotograma.
    //
    // El empuje sigue con `Transform.translate` dentro de un `AnimatedBuilder`
    // porque [desplazamiento] son píxeles fijos. `SlideTransition` mueve una
    // fracción del tamaño del hijo, y con eso una tarjeta alta saltaría
    // muchísimo más que una baja — que es justo lo que no se quiere en una
    // cascada de elementos de alturas distintas. El `child` va fuera del
    // `builder`, así que lo que se reconstruye por fotograma es el `Transform`
    // y nada de lo que hay debajo.
    return FadeTransition(
      opacity: _curva,
      child: AnimatedBuilder(
        animation: _curva,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, (1 - _curva.value) * widget.desplazamiento),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
