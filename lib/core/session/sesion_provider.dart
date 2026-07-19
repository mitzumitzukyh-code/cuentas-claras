import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/negocio/data/negocio_repository.dart';

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
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return SesionEstado.cargando;

  final user = auth.value;
  if (user == null) return SesionEstado.sinSesion;

  final membresias = ref.watch(misMembresiasProvider);
  if (membresias.isLoading) return SesionEstado.cargando;

  // Sin esto, un fallo de lectura se confundiría con "no tiene negocios" y
  // mandaría al onboarding a alguien que ya tiene uno — creando un duplicado.
  if (membresias.hasError) return SesionEstado.error;

  final lista = membresias.valueOrNull ?? const [];
  return lista.isEmpty ? SesionEstado.sinNegocio : SesionEstado.listo;
});
