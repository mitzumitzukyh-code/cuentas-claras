import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Biblioteca de componentes neumórficos del diseño (`dise-o-de-app`).
///
/// El lenguaje visual tiene tres estados de relieve:
/// * **Levantado** ([NeuCard]) — superficies que sobresalen: tarjetas, píldoras.
/// * **Hundido** ([NeuInset]) — campos de entrada, barras de progreso.
/// * **Primario** ([NeuButton]) — verde de marca con sombra teñida.
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
// Hundido
// ---------------------------------------------------------------------------

/// Superficie hundida: dibuja sombra interior sobre el hijo.
///
/// `BoxDecoration` no soporta `inset` box-shadow, así que el efecto se pinta
/// con [_InnerShadowPainter] por encima del contenido.
class NeuInset extends StatelessWidget {
  const NeuInset({
    super.key,
    required this.child,
    this.radius = 18,
    this.color,
  });

  final Widget child;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final borde = BorderRadius.circular(radius);

    return DecoratedBox(
      decoration: BoxDecoration(color: color ?? t.surface, borderRadius: borde),
      child: CustomPaint(
        foregroundPainter: _InnerShadowPainter(
          radius: radius,
          oscura: t.insetDark,
          clara: t.insetLight,
        ),
        child: ClipRRect(borderRadius: borde, child: child),
      ),
    );
  }
}

/// Pinta las dos sombras interiores del token `shadowInset`.
class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter({
    required this.radius,
    required this.oscura,
    required this.clara,
  });

  final double radius;
  final Color oscura;
  final Color clara;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    _sombra(canvas, size, rrect, const Offset(4, 4), 9, oscura);
    _sombra(canvas, size, rrect, const Offset(-3, -3), 7, clara);
    canvas.restore();
  }

  /// Dibuja "todo menos el rectángulo desplazado", difuminado: al estar
  /// recortado al `rrect`, solo se ve el borde interior.
  void _sombra(
    Canvas canvas,
    Size size,
    RRect rrect,
    Offset offset,
    double blur,
    Color color,
  ) {
    final fuera = Path()
      ..addRect(Rect.fromLTWH(-60, -60, size.width + 120, size.height + 120));
    final dentro = Path()..addRRect(rrect.shift(offset));
    final anillo = Path.combine(PathOperation.difference, fuera, dentro);

    canvas.drawPath(
      anillo,
      Paint()
        ..color = color
        // CSS blur-radius ≈ 2σ.
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, blur / 2),
    );
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      old.radius != radius || old.oscura != oscura || old.clara != clara;
}

/// Campo de texto hundido — el input estándar del diseño.
class NeuInput extends StatelessWidget {
  const NeuInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.height = 50,
    this.radius = 18,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofillHints,
    this.textInputAction,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.fillWithPageBg = false,
  });

  final TextEditingController? controller;

  /// Etiqueta pequeña que el diseño coloca *encima* del campo, no dentro.
  final String? label;

  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;

  /// Widget al final del campo (ojo de contraseña, unidad…).
  final Widget? suffix;

  final double height;
  final double radius;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final List<String>? autofillHints;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final TextAlign textAlign;

  /// Campos anidados dentro de una tarjeta usan `pageBg` para contrastar.
  final bool fillWithPageBg;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    final campo = SizedBox(
      height: height,
      child: NeuInset(
        radius: radius,
        color: fillWithPageBg ? t.pageBg : t.surface,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                enabled: enabled,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                autofillHints: autofillHints,
                textInputAction: textInputAction,
                maxLength: maxLength,
                textAlign: textAlign,
                style: TextStyle(fontSize: 15, color: t.text),
                cursorColor: AppColors.marca,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(fontSize: 15, color: t.muted),
                  counterText: '',
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
            if (suffix != null)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: suffix,
              ),
          ],
        ),
      ),
    );

    if (label == null) return campo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: t.textSec,
            ),
          ),
        ),
        campo,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Primario
// ---------------------------------------------------------------------------

/// Botón principal verde con sombra teñida (`shadowBtn`).
class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.radius = 20,
    this.loading = false,
    this.color = AppColors.marca,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final bool loading;
  final Color color;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final activo = onPressed != null && !loading;

    return _Pressable(
      onTap: activo ? onPressed : null,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          // Deshabilitado pierde el verde y la sombra teñida (como el prototipo,
          // que cambia `npBg` a un gris apagado).
          color: activo ? color : t.muted,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: activo ? t.shadowBtn : t.shadowRaisedSm,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 10)],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Botón secundario: superficie levantada con texto normal.
class NeuSecondaryButton extends StatelessWidget {
  const NeuSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.radius = 20,
    this.icon,
    this.color,
    this.background,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final Widget? icon;

  /// Color del texto. Por defecto `tokens.text`.
  final Color? color;

  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuCard(
      onTap: onPressed,
      small: true,
      radius: radius,
      height: height,
      color: background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 8)],
          Text(
            label,
            style: TextStyle(
              color: color ?? t.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora seleccionable (rubro, categoría, método de pago, descuento).
class NeuChip extends StatelessWidget {
  const NeuChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 14,
          vertical: dense ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.marca : t.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.marca : t.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: dense ? 11.5 : 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : t.text,
          ),
        ),
      ),
    );
  }
}

/// Interruptor del diseño: pista de 44×26 con perilla blanca de 20.
class NeuToggle extends StatelessWidget {
  const NeuToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? AppColors.marca : t.border,
          borderRadius: BorderRadius.circular(100),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 1),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
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

/// Fila estándar dentro de una tarjeta de lista, con separador opcional.
class NeuListTile extends StatelessWidget {
  const NeuListTile({
    super.key,
    required this.child,
    this.onTap,
    this.divider = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool divider;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          border: divider
              ? Border(bottom: BorderSide(color: t.divider))
              : null,
        ),
        child: child,
      ),
    );
  }
}
