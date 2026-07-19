import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Marca de Cuenta Clara: cuadrado redondeado verde con relieve.
///
/// El diseño lo dibuja como una insignia "CC" (login 64 px, splash 72 px). Se
/// intenta primero el ícono de `assets/icon/`; si falta, cae al monograma.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radio = BorderRadius.circular(size * 0.34);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.marca,
        borderRadius: radio,
        boxShadow: t.shadowBtn,
      ),
      child: ClipRRect(
        borderRadius: radio,
        child: Image.asset(
          'assets/icon/cuenta_clara_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              'CC',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
