import 'package:flutter/material.dart';

import 'libreta_colors.dart';
import 'libreta_tokens.dart';

/// Píldora seleccionable del sistema "libreta" (categoría, subcategoría,
/// método de pago…). Plana, sin relieve — a diferencia de `NeuChip`.
class LibretaChip extends StatelessWidget {
  const LibretaChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
    this.colorSeleccionado = LibretaColors.verde,
    this.alerta = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  /// Color de fondo/borde cuando está seleccionado. Verde por defecto; grupos
  /// distintos de chips (ej. método de pago vs. período) pueden usar otro
  /// color para no verse todos idénticos al elegir uno de cada grupo.
  final Color colorSeleccionado;

  /// `true` marca la opción como algo a lo que prestar atención (ej.
  /// "Anuladas"): se ve en ámbar aunque no esté seleccionada.
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final color = alerta ? LibretaColors.aviso : colorSeleccionado;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 14,
          vertical: dense ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: selected ? color : t.superficie,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? color
                : (alerta ? color.withValues(alpha: 0.5) : t.bordeSuave),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: dense ? 11.5 : 13,
            fontWeight: FontWeight.w700,
            color: selected
                ? (alerta ? LibretaColors.tarjetaOscura : Colors.white)
                : (alerta ? color : t.textoFuerte),
          ),
        ),
      ),
    );
  }
}

/// Interruptor plano: pista verde/gris de 44×26 con perilla blanca.
class LibretaToggle extends StatelessWidget {
  const LibretaToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? LibretaColors.verde : t.bordeSuave,
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

/// Botón cuadrado pequeño con ícono, sin relieve (volver, importar…).
class LibretaIconButton extends StatelessWidget {
  const LibretaIconButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.size = 40,
    this.radius = 12,
  });

  final VoidCallback? onTap;
  final IconData icon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: t.superficie,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: t.bordeSuave),
        ),
        child: Icon(icon, size: size * 0.46, color: t.textoFuerte),
      ),
    );
  }
}
