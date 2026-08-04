import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/negocio/data/negocio_repository.dart';

/// Cuánto se queda el splash en pantalla como mínimo.
///
/// Con sesión ya guardada, auth resuelve en milisegundos y el splash
/// parpadeaba tan rápido que ni se veía el logo. Este mínimo retiene el estado
/// `cargando` para que la marca se aprecie.
///
/// Con las animaciones desactivadas no hay nada que apreciar —la intro salta a
/// su estado final— y el mínimo se vuelve tiempo muerto mirando una imagen
/// fija, así que se recorta a un latido. Pasa de verdad: en el Z2464N el
/// sistema reporta `disableAnimations`.
///
/// La pantalla lee esto para calcular su fundido de salida: es el único sitio
/// donde vive la duración.
Duration splashMinimo() =>
    WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 3500);

/// Retiene el estado `cargando` durante [splashMinimo]. Solo corre una vez por
/// arranque de la app.
final splashMinimoProvider = FutureProvider<void>(
  (ref) => Future<void>.delayed(splashMinimo()),
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

/// Combina el estado de autenticación con las membresías del usuario, **sin**
/// el retardo mínimo del splash.
///
/// Separado de [sesionProvider] para que el splash pueda distinguir "ya está
/// todo listo, solo falta que se cumpla el mínimo en pantalla" de "todavía se
/// está resolviendo": lo primero se puede anticipar con un fundido, lo segundo
/// obliga a seguir mostrando algo.
final sesionResueltaProvider = Provider<SesionEstado>((ref) {
  final auth = ref.watch(authStateProvider);
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

/// Estado de sesión que decide el destino de navegación (ver router).
final sesionProvider = Provider<SesionEstado>((ref) {
  // El estado real se observa ANTES de consultar el timer del splash: así
  // Firebase va resolviendo la sesión guardada en paralelo mientras corre la
  // animación, en vez de empezar de cero cuando el timer vence.
  final resuelta = ref.watch(sesionResueltaProvider);
  if (ref.watch(splashMinimoProvider).isLoading) return SesionEstado.cargando;
  return resuelta;
});
