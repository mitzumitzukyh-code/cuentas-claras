import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Biblioteca de componentes neumórficos del diseño.
///
/// * **Levantado** ([NeuCard]) — superficies que sobresalen: tarjetas, píldoras.
///
/// Ningún widget de la app debería declarar `BoxShadow` propios: siempre tomar
/// las sombras de `context.tokens`.

// ---------------------------------------------------------------------------
// Levantado
// ---------------------------------------------------------------------------

/// Superficie levantada con sombra doble. Es el contenedor base del diseño.
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 22,
    this.color,
    this.onTap,
    this.small = false,
    this.width,
    this.height,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  /// Fondo. Por defecto `tokens.surface`.
  final Color? color;

  final VoidCallback? onTap;

  /// Usa la sombra reducida (`shadowRaisedSm`) en vez de la estándar.
  final bool small;

  final double? width;
  final double? height;

  /// Recorta el contenido al radio — necesario para listas con separadores.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borde = BorderRadius.circular(radius);

    Widget contenido = child;
    if (padding != null) {
      contenido = Padding(padding: padding!, child: contenido);
    }
    if (clip) {
      contenido = ClipRRect(borderRadius: borde, child: contenido);
    }

    return _Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? t.surface,
          borderRadius: borde,
          boxShadow: small ? t.shadowRaisedSm : t.shadowRaised,
        ),
        child: contenido,
      ),
    );
  }
}

/// Botón cuadrado pequeño de la barra superior (volver, importar, exportar).
class NeuIconBtn extends StatelessWidget {
  const NeuIconBtn({
    super.key,
    required this.onTap,
    this.icon,
    this.emoji,
    this.size = 36,
    this.radius = 14,
  }) : assert(icon != null || emoji != null, 'Se requiere icon o emoji');

  final VoidCallback? onTap;
  final IconData? icon;
  final String? emoji;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuCard(
      onTap: onTap,
      small: true,
      radius: radius,
      width: size,
      height: size,
      child: Center(
        child: icon != null
            ? Icon(icon, size: size * 0.45, color: t.text)
            : Text(emoji!, style: TextStyle(fontSize: size * 0.42)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Interacción
// ---------------------------------------------------------------------------

/// Reproduce el `:active { transform: scale(0.96) }` del prototipo.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) => setState(() => _presionado = false),
      onTapCancel: () => setState(() => _presionado = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _presionado ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}

