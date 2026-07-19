import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// "Estamos configurando todo para ti" (bloque `isConfigurando` del diseño).
///
/// Cubre el hueco entre crear el negocio y que Firestore propague la membresía,
/// para que no parezca que la app se quedó pensando.
class ConfigurandoScreen extends StatelessWidget {
  const ConfigurandoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.marca,
                  backgroundColor: t.border2,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 260,
                child: Text(
                  'Estamos configurando todo para ti',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 260,
                child: Text(
                  'Preparando tu tienda, tasa BCV y métodos de pago…',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: t.textSec),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
