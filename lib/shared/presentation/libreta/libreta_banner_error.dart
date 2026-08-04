import 'package:flutter/material.dart';

import 'libreta_colors.dart';

/// Aviso rojo suave para el error de un formulario.
///
/// `liveRegion`: el aviso aparece sin que nadie mueva el foco, así que el
/// lector de pantalla no lo leería solo. Sin esto, quien no ve la pantalla
/// pulsa el botón y no se entera de por qué no pasó nada.
///
/// El texto que reciba tiene que estar ya traducido a algo legible — ver
/// `mensajeDeError` en `shared/utils/errores.dart`. Aquí no llega un
/// `toString()` de excepción.
class LibretaBannerError extends StatelessWidget {
  const LibretaBannerError({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: LibretaColors.peligro.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          mensaje,
          style: const TextStyle(
            color: LibretaColors.peligro,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
