import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/sesion_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/onboarding/presentation/rubro_selection_screen.dart';
import '../../features/perfil/presentation/perfil_screen.dart';
import '../../features/productos/presentation/nuevo_producto_screen.dart';
import '../../features/productos/presentation/productos_screen.dart';
import '../../features/ventas/presentation/cobrar_screen.dart';
import '../../shared/presentation/sesion_error_screen.dart';
import '../../shared/presentation/splash_screen.dart';
import 'routes.dart';

/// Provee el [GoRouter] con guardas basadas en el estado de sesión.
///
/// El `redirect` central aplica el flujo del brief:
/// sin sesión → Login · con sesión sin negocio → Onboarding · listo → Dashboard.
final goRouterProvider = Provider<GoRouter>((ref) {
  // Reevalúa el redirect cuando cambia el estado de sesión. Se escucha el
  // provider DERIVADO (no sus fuentes por separado): escucharlo lo mantiene
  // activo, de modo que recalcula en cuanto cambia cualquiera de sus fuentes
  // — auth, membresías o el tiempo mínimo del splash. Escuchar las fuentes
  // dejaba a sesionProvider sin oyentes, y al vencer el timer del splash el
  // redirect podía leer un "cargando" viejo y la app se quedaba pegada en la
  // pantalla de carga para siempre.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sesionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final estado = ref.read(sesionProvider);
      final loc = state.matchedLocation;

      switch (estado) {
        case SesionEstado.cargando:
          return loc == Routes.splash ? null : Routes.splash;
        case SesionEstado.sinSesion:
          return loc == Routes.login ? null : Routes.login;
        case SesionEstado.sinNegocio:
          return loc == Routes.onboarding ? null : Routes.onboarding;
        case SesionEstado.error:
          return loc == Routes.sesionError ? null : Routes.sesionError;
        case SesionEstado.listo:
          const soloFueraDeSesion = {
            Routes.splash,
            Routes.login,
            Routes.onboarding,
            Routes.sesionError,
          };
          return soloFueraDeSesion.contains(loc) ? Routes.dashboard : null;
      }
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const RubroSelectionScreen(),
      ),
      GoRoute(
        path: Routes.dashboard,
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: Routes.productos,
        builder: (_, __) => const ProductosScreen(),
      ),
      GoRoute(
        path: Routes.nuevoProducto,
        builder: (_, __) => const NuevoProductoScreen(),
      ),
      GoRoute(
        path: Routes.cobrar,
        builder: (_, __) => const CobrarScreen(),
      ),
      GoRoute(
        path: Routes.perfil,
        builder: (_, __) => const PerfilScreen(),
      ),
      GoRoute(
        path: Routes.sesionError,
        builder: (_, __) => const SesionErrorScreen(),
      ),
    ],
  );
});
