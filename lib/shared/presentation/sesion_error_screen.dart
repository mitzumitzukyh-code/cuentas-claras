import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/negocio/data/negocio_repository.dart';
import 'neu.dart';

/// Se muestra cuando no se pueden leer las membresías del usuario.
///
/// Casi siempre es un `permission-denied` de Firestore (reglas sin publicar) o
/// falta de conexión. Mandar al onboarding en ese caso crearía un negocio
/// duplicado, así que se corta aquí con opción de reintentar.
class SesionErrorScreen extends ConsumerWidget {
  const SesionErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final error = ref.watch(misMembresiasProvider).error;
    final sinPermiso = error.toString().contains('permission-denied');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppColors.avisoSuave,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('⚠️', style: TextStyle(fontSize: 30)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                sinPermiso
                    ? 'No tenemos permiso para leer tus datos'
                    : 'No pudimos cargar tu negocio',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sinPermiso
                    ? 'Firestore rechazó la consulta. Revisa que las reglas de '
                        'seguridad estén publicadas en el proyecto.'
                    : 'Revisa tu conexión a internet e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: t.textSec),
              ),
              const SizedBox(height: 24),
              NeuButton(
                label: 'Reintentar',
                onPressed: () => ref.invalidate(misMembresiasProvider),
              ),
              const SizedBox(height: 12),
              NeuSecondaryButton(
                label: 'Cerrar sesión',
                color: AppColors.peligro,
                onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
