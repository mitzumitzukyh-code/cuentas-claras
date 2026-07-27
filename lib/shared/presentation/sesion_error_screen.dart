import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/conectividad_provider.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/negocio/data/negocio_repository.dart';
import 'conexion_error_screen.dart';
import 'libreta/libreta.dart';

/// Se muestra cuando no se pueden leer las membresías del usuario (réplica
/// visual de `P4 · SESIÓN`, `Lote F · Onboarding y Sistema`).
///
/// Casi siempre es un `permission-denied` de Firestore (reglas sin publicar) o
/// falta de conexión. Mandar al onboarding en ese caso crearía un negocio
/// duplicado, así que se corta aquí con opción de reintentar.
///
/// Si el teléfono no tiene señal en absoluto, se delega en
/// [ConexionErrorScreen] (réplica de `P5 · CONEXIÓN` / `P4 · SIN CONEXIÓN`)
/// en vez de mostrar el mensaje genérico de aquí abajo — SOLO en este punto
/// de arranque, nunca a mitad de uso: ahí sigue el banner de
/// [AvisoConexion], que no bloquea la app (offline-first).
class SesionErrorScreen extends ConsumerWidget {
  const SesionErrorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sinSenal = ref.watch(hayConexionProvider).valueOrNull == false;
    if (sinSenal) {
      return ConexionErrorScreen(
        onReintentar: () => ref.invalidate(misMembresiasProvider),
      );
    }

    final error = ref.watch(misMembresiasProvider).error;
    final sinPermiso = error.toString().contains('permission-denied');

    return Scaffold(
      backgroundColor: context.libreta.papel,
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
                  decoration: const BoxDecoration(
                    color: Color(0x21F2A93C),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: LibretaColors.aviso,
                  ),
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
                  color: context.libreta.textoFuerte,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sinPermiso
                    ? 'Firestore rechazó la consulta. Revisa que las reglas de '
                        'seguridad estén publicadas en el proyecto.'
                    : 'Revisa tu conexión a internet e intenta de nuevo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.libreta.textoMuted),
              ),
              const SizedBox(height: 24),
              LibretaButton(
                label: 'Reintentar',
                onPressed: () => ref.invalidate(misMembresiasProvider),
              ),
              const SizedBox(height: 12),
              LibretaSecondaryButton(
                label: 'Cerrar sesión',
                onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
