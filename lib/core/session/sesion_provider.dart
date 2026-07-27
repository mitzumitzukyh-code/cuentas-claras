import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/negocio/data/negocio_repository.dart';

/// Tiempo mínimo del splash en pantalla.
///
/// Con sesión ya guardada, auth resuelve en milisegundos y el splash
/// parpadeaba tan rápido que ni se veía el logo. Este future retiene el
/// estado `cargando` un momento para que la marca se aprecie; solo corre una
/// vez por arranque de la app.
final splashMinimoProvider = FutureProvider<void>(
  (ref) => Future<void>.delayed(const Duration(milliseconds: 3500)),
);

/// Estado global de sesión que decide el destino de navegación (ver router).
enum SesionEstado {
  /// Aún resolviendo auth o membresías.
  cargando,

  /// No hay usuario autenticado.
  sinSesion,

  /// Autenticado pero sin ningún negocio (necesita onboarding).
  sinNegocio,

  /// Autenticado y con al menos un negocio.
  listo,

  /// No se pudieron leer las membresías (permisos, red).
  error,
}

/// Combina el estado de autenticación con las membresías del usuario.
final sesionProvider = Provider<SesionEstado>((ref) {
  // Auth se observa ANTES de consultar el timer del splash: así Firebase va
  // resolviendo la sesión guardada en paralelo mientras corre la animación,
  // en vez de empezar de cero cuando el timer vence.
  final auth = ref.watch(authStateProvider);
  if (ref.watch(splashMinimoProvider).isLoading) return SesionEstado.cargando;
  if (auth.isLoading) return SesionEstado.cargando;

  final user = auth.value;
  if (user == null) {
    // Antes de rendirse y mandar al login: si Firebase no restauró la sesión
    // (pasa en release, ver [restaurarSesionProvider]), esperar a que la app
    // intente rehacerla ella misma. Solo si ese intento ya terminó y seguimos
    // sin usuario, es de verdad "sin sesión".
    if (ref.watch(restaurarSesionProvider).isLoading) {
      return SesionEstado.cargando;
    }
    return SesionEstado.sinSesion;
  }

  final membresias = ref.watch(misMembresiasProvider);
  if (membresias.isLoading) return SesionEstado.cargando;

  // Sin esto, un fallo de lectura se confundiría con "no tiene negocios" y
  // mandaría al onboarding a alguien que ya tiene uno — creando un duplicado.
  if (membresias.hasError) return SesionEstado.error;

  final lista = membresias.valueOrNull ?? const [];
  return lista.isEmpty ? SesionEstado.sinNegocio : SesionEstado.listo;
});
