import 'package:flutter/material.dart';

import 'libreta_colors.dart';
import 'libreta_tokens.dart';

/// Botón primario del sistema "libreta": verde sólido, esquinas 14,
/// sombra teñida — sin relieve neumórfico (el sistema es plano).
class LibretaButton extends StatelessWidget {
  const LibretaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 54,
    this.loading = false,
    this.icon,
    this.color = LibretaColors.verde,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool loading;
  final Widget? icon;

  /// Color de fondo — verde por defecto; navy para acciones secundarias
  /// destacadas ("Exportar reporte", `Lote N · Reportes y Más`).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !loading;

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: activo ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: .5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Botón secundario: superficie blanca con borde suave (Google, "usar
/// correo"…).
class LibretaSecondaryButton extends StatelessWidget {
  const LibretaSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 50,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: t.superficie,
          foregroundColor: t.textoFuerte,
          side: BorderSide(color: t.bordeSuave, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
