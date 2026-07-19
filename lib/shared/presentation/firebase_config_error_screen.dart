import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Se muestra si Firebase no pudo inicializarse (típicamente porque aún no se
/// ejecutó `flutterfire configure`). Ver `README_SETUP.md`.
class FirebaseConfigErrorScreen extends StatelessWidget {
  const FirebaseConfigErrorScreen({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: AppColors.aviso),
              const SizedBox(height: 16),
              Text(
                'Firebase no está configurado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ejecuta `flutterfire configure` para generar '
                'firebase_options.dart y conectar el proyecto.\n'
                'Consulta README_SETUP.md.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSec),
              ),
              const SizedBox(height: 20),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textSec),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
