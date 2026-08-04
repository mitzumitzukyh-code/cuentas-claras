import 'package:flutter/material.dart';

import 'libreta_colors.dart';
import 'libreta_tokens.dart';

/// Campo de texto plano del sistema "libreta": tarjeta blanca con borde
/// suave, sin relieve (a diferencia de [NeuInput], que es hundido).
class LibretaInput extends StatelessWidget {
  const LibretaInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.leading,
    this.suffix,
    this.bordeVerde = false,
    this.height = 52,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofillHints,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? leading;
  final Widget? suffix;

  /// Borde verde fijo en vez del borde suave del tema — usado en buscadores
  /// (réplica de `P0 · BÚSQUEDA FUNCIONAL`, `Lote L · Búsqueda y Datos`).
  final bool bordeVerde;
  final double height;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final List<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextAlign textAlign;
  final int? maxLength;

  /// Mayúsculas automáticas del teclado. `characters` para los códigos, que se
  /// guardan y se enseñan siempre en mayúscula.
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final campo = SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: t.superficie,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: bordeVerde ? LibretaColors.verde : t.bordeSuave,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (leading != null)
              Padding(padding: const EdgeInsets.only(left: 14), child: leading),
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
                textAlign: textAlign,
                maxLength: maxLength,
                textCapitalization: textCapitalization,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: t.textoFuerte,
                ),
                cursorColor: LibretaColors.verde,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: t.textoMuted,
                  ),
                  counterText: '',
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.only(
                    left: leading != null ? 10 : 14,
                    right: 14,
                  ),
                ),
              ),
            ),
            if (suffix != null)
              Padding(padding: const EdgeInsets.only(right: 14), child: suffix),
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
              fontWeight: FontWeight.w700,
              color: t.textoMuted,
            ),
          ),
        ),
        campo,
      ],
    );
  }
}

/// Ojo de mostrar/ocultar contraseña, para el [LibretaInput.suffix].
///
/// El icono mide 20 px y acertarle era cuestión de puntería. La caja da los 48
/// hacia la izquierda y el `centerRight` deja el ojo exactamente donde estaba,
/// así que crece el área pulsable sin mover nada de sitio.
class LibretaOjoContrasena extends StatelessWidget {
  const LibretaOjoContrasena({
    super.key,
    required this.visible,
    required this.onTap,
  });

  /// `true` cuando la contraseña se está viendo en claro.
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Align(
            alignment: Alignment.centerRight,
            child: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: context.libreta.textoMuted,
            ),
          ),
        ),
      ),
    );
  }
}
