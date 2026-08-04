import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/conectividad_provider.dart';
import '../../core/theme/app_assets.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/negocio/data/negocio_repository.dart';
import '../utils/errores.dart';
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
    // Por el código de la excepción, no por lo que diga su `toString()`: ese
    // texto lo formatea Firebase y no es contrato de nada. Además, con `error`
    // en null la búsqueda se hacía sobre la cadena "null" y acertaba de pura
    // casualidad.
    final sinPermiso =
        error is FirebaseException && error.code == 'permission-denied';
    // Se llama siempre, aunque el caso de permisos use su propio texto: es lo
    // que manda el detalle técnico a la consola, y el de permisos —reglas de
    // Firestore sin publicar— es justo el que hace falta ver en desarrollo.
    final mensaje = mensajeDeError(error, accion: 'cargar tu negocio');

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
                  decoration: BoxDecoration(
                    // El halo va en el ámbar de superficie y el icono en el
                    // de texto: son dos tonos distintos a propósito, el
                    // brillante no tiene contraste para un icono sobre papel.
                    color: LibretaColors.ambarSuperficie.withValues(alpha: .13),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const LibretaIcono(AppAssets.accAlerta,
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
                // Antes, el caso de permisos le pintaba al usuario "Firestore
                // rechazó la consulta, revisa que las reglas de seguridad estén
                // publicadas en el proyecto" — una nota para quien compila,
                // dentro del APK de producción.
                sinPermiso
                    ? 'Tu usuario no tiene acceso a este negocio. Pídele al '
                        'dueño que te agregue al equipo.'
                    : mensaje,
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
                // `cerrarSesion` borra la sesión guardada y cierra en Google y
                // en Firebase: tres pasos que pueden fallar. Disparado sin
                // esperar ni capturar, un fallo dejaba al usuario encerrado en
                // la pantalla que existe para desatascarlo, sin nada en la
                // interfaz que se moviera.
                onPressed: () async {
                  try {
                    await ref.read(authRepositoryProvider).cerrarSesion();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          mensajeDeError(e, accion: 'cerrar sesión'),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
