import 'package:flutter/material.dart';

import 'libreta_colors.dart';

/// Texto pulsable con el área táctil que pide Material.
///
/// Una línea de texto mide 16-17 px de alto, y con un `GestureDetector` pelado
/// eso era todo lo que aceptaba el toque: fallar el enlace era lo normal, no
/// la excepción. La caja de 48 no cambia cómo se ve el texto, solo lo que se
/// puede pulsar.
///
/// `MergeSemantics` hace que el rol de botón, la etiqueta del texto y la
/// acción de toque salgan como un solo nodo. Sueltos, el lector de pantalla
/// anunciaba un botón sin nombre y, aparte, un texto que no se podía pulsar.
class LibretaEnlace extends StatelessWidget {
  const LibretaEnlace({
    super.key,
    required this.texto,
    required this.onTap,
    this.tamano = 14,
    this.grosor = FontWeight.w800,
    this.color,
  });

  final String texto;
  final VoidCallback onTap;
  final double tamano;
  final FontWeight grosor;

  /// Verde por defecto. Se cambia en los enlaces que el diseño quiere
  /// discretos — "¿Lo recordaste? Volver a entrar" va en gris, para no competir
  /// con el botón principal de su pantalla.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 48,
            child: Center(
              widthFactor: 1,
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: tamano,
                  color: color ?? LibretaColors.verde,
                  fontWeight: grosor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
