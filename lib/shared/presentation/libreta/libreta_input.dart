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
