import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/sesion_provider.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/sesion_expirada_screen.dart';
import '../../features/cierre/presentation/arqueo_caja_screen.dart';
import '../../features/productos/presentation/arqueo_inventario_screen.dart';
import '../../features/productos/presentation/insumos_screen.dart';
import '../../shared/presentation/permiso_requerido.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/fiados/presentation/fiados_screen.dart';
import '../../features/gastos/presentation/gastos_screen.dart';
import '../../features/negocio/domain/membresia.dart';
import '../../features/negocio/presentation/detalle_empleado_screen.dart';
import '../../features/negocio/presentation/auditoria_screen.dart';
import '../../features/negocio/presentation/empleados_screen.dart';
import '../../features/negocio/presentation/mis_negocios_screen.dart';
import '../../features/negocio/presentation/impresora_screen.dart';
import '../../features/negocio/presentation/metodos_pago_screen.dart';
import '../../features/perfil/presentation/legal_screen.dart';
import '../../features/onboarding/presentation/rubro_selection_screen.dart';
import '../../features/onboarding/presentation/unirse_codigo_screen.dart';
import '../../features/perfil/presentation/ajustes_screen.dart';
import '../../features/perfil/presentation/centro_ayuda_screen.dart';
import '../../features/perfil/presentation/mi_perfil_screen.dart';
import '../../features/perfil/presentation/perfil_screen.dart';
import '../../features/planes/presentation/planes_screen.dart';
import '../../features/productos/presentation/nuevo_producto_screen.dart';
import '../../features/productos/presentation/productos_screen.dart';
import '../../features/proveedores/presentation/proveedores_screen.dart';
import '../../features/reportes/presentation/reportes_screen.dart';
import '../../features/ventas/presentation/cobrar_screen.dart';
import '../../features/ventas/presentation/historial_screen.dart';
import '../../features/catalogo/presentation/catalogo_screen.dart';
import '../../features/catalogo/presentation/estado_screen.dart';
import '../../features/cierre/domain/cierre_caja.dart';
import '../../features/cierre/presentation/resumen_dia_screen.dart';
import '../../features/fiados/domain/cliente_fiado.dart';
import '../../features/fiados/presentation/anotar_movimiento_screen.dart';
import '../../features/fiados/presentation/cliente_fiado_detalle_screen.dart';
import '../../features/gastos/presentation/registrar_gasto_screen.dart';
import '../../features/notificaciones/presentation/notificaciones_screen.dart';
import '../../features/onboarding/presentation/tutorial_screen.dart';
import '../../features/perfil/presentation/eliminar_cuenta_screen.dart';
import '../../features/productos/presentation/importar_inventario_screen.dart';
import '../../features/productos/presentation/migrar_otra_app_screen.dart';
import '../../features/proveedores/domain/proveedor.dart';
import '../../features/proveedores/presentation/anotar_movimiento_proveedor_screen.dart';
import '../../features/proveedores/presentation/proveedor_detalle_screen.dart';
import '../../features/ventas/presentation/venta_detalle_screen.dart';
import '../../features/ventas/presentation/ventas_pendientes_screen.dart';
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
          // Si la sesión guardada se cayó sola, se explica antes de mandar al
          // login (Lote F · P4): aterrizar ahí sin aviso parece pérdida de
          // datos. El botón de esa pantalla baja la bandera y sigue al login.
          if (ref.read(authRepositoryProvider).sesionExpirada) {
            return loc == Routes.sesionExpirada ? null : Routes.sesionExpirada;
          }
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
        pageBuilder: (_, s) => _pagina(s, const SplashScreen()),
      ),
      GoRoute(
        path: Routes.login,
        pageBuilder: (_, s) => _pagina(s, const LoginScreen()),
      ),
      GoRoute(
        path: Routes.sesionExpirada,
        pageBuilder: (_, s) => _pagina(s, const SesionExpiradaScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (_, s) => _pagina(s, const RubroSelectionScreen()),
      ),
      GoRoute(
        path: Routes.dashboard,
        pageBuilder: (_, s) => _pagina(s, const DashboardScreen()),
      ),
      GoRoute(
        path: Routes.productos,
        pageBuilder: (_, s) => _pagina(s, const ProductosScreen()),
      ),
      GoRoute(
        path: Routes.auditoria,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.gestionarEmpleados,
          titulo: 'La auditoría es del dueño',
          child: AuditoriaScreen(),
        )),
      ),
      GoRoute(
        path: Routes.misNegocios,
        pageBuilder: (_, s) => _pagina(s, const MisNegociosScreen()),
      ),
      GoRoute(
        path: Routes.arqueoInventario,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.editarInventario,
          titulo: 'Contar el inventario es del dueño',
          child: ArqueoInventarioScreen(),
        )),
      ),
      GoRoute(
        path: Routes.insumos,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.editarInventario,
          titulo: 'Los insumos los maneja el dueño',
          child: InsumosScreen(),
        )),
      ),
      GoRoute(
        path: Routes.nuevoProducto,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.editarInventario,
          titulo: 'Solo el dueño agrega productos',
          child: NuevoProductoScreen(),
        )),
      ),
      GoRoute(
        path: Routes.cobrar,
        pageBuilder: (_, s) => _pagina(s, const CobrarScreen()),
      ),
      GoRoute(
        path: Routes.reportes,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.verReportes,
          titulo: 'Los reportes son del dueño',
          detalle: 'Aquí se ven las ganancias y los costos del negocio. '
              'Pídele al dueño que te active «Ver reportes» si necesitas '
              'entrar.',
          child: ReportesScreen(),
        )),
      ),
      GoRoute(
        path: Routes.perfil,
        pageBuilder: (_, s) => _pagina(s, const PerfilScreen()),
      ),
      GoRoute(
        path: Routes.ajustes,
        pageBuilder: (_, s) => _pagina(s, const AjustesScreen()),
      ),
      GoRoute(
        path: Routes.gastos,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.registrarGastos,
          titulo: 'Los gastos son del dueño',
          child: GastosScreen(),
        )),
      ),
      GoRoute(
        path: Routes.fiados,
        pageBuilder: (_, s) => _pagina(s, const FiadosScreen()),
      ),
      GoRoute(
        path: Routes.arqueo,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.cerrarCaja,
          titulo: 'Cerrar la caja es del dueño',
          child: ArqueoCajaScreen(),
        )),
      ),
      GoRoute(
        path: Routes.proveedores,
        pageBuilder: (_, s) => _pagina(s, const ProveedoresScreen()),
      ),
      GoRoute(
        path: Routes.empleados,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.gestionarEmpleados,
          titulo: 'El equipo lo maneja el dueño',
          child: EmpleadosScreen(),
        )),
      ),
      GoRoute(
        path: Routes.metodosPago,
        pageBuilder: (_, s) => _pagina(s, const MetodosPagoScreen()),
      ),
      GoRoute(
        path: Routes.impresora,
        pageBuilder: (_, s) => _pagina(s, const ImpresoraScreen()),
      ),
      GoRoute(
        path: Routes.planes,
        pageBuilder: (_, s) => _pagina(s, const PlanesScreen()),
      ),
      GoRoute(
        path: Routes.catalogo,
        pageBuilder: (_, s) => _pagina(s, const CatalogoScreen()),
      ),
      GoRoute(
        path: Routes.miPerfil,
        pageBuilder: (_, s) => _pagina(s, const MiPerfilScreen()),
      ),
      GoRoute(
        path: Routes.ayuda,
        pageBuilder: (_, s) => _pagina(s, const CentroAyudaScreen()),
      ),
      GoRoute(
        path: Routes.historialVentas,
        pageBuilder: (_, s) => _pagina(s, const HistorialScreen()),
      ),
      GoRoute(
        path: Routes.tutorial,
        pageBuilder: (_, s) => _pagina(s, const TutorialScreen()),
      ),
      GoRoute(
        path: Routes.ventasPendientes,
        pageBuilder: (_, s) => _pagina(s, const VentasPendientesScreen()),
      ),
      GoRoute(
        path: Routes.nuevoGasto,
        pageBuilder: (_, s) => _pagina(s, const PermisoRequerido(
          permiso: Permisos.registrarGastos,
          titulo: 'Los gastos son del dueño',
          child: RegistrarGastoScreen(),
        )),
      ),
      GoRoute(
        path: Routes.fiadoDetalle,
        pageBuilder: (_, s) => _pagina(s, ClienteFiadoDetalleScreen(cliente: s.extra as ClienteFiado)),
      ),
      GoRoute(
        path: Routes.fiadoMovimiento,
        pageBuilder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return _pagina(
            s,
            AnotarMovimientoScreen(
              clientePreseleccionado: extra?['clientePreseleccionado'] as ClienteFiado?,
              tipoInicial: extra?['tipoInicial'] as TipoMovimientoFiado? ?? TipoMovimientoFiado.fiado,
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.ventaDetalle,
        pageBuilder: (_, s) => _pagina(s, VentaDetalleScreen(ventaId: s.pathParameters['ventaId'] ?? '')),
      ),
      GoRoute(
        path: Routes.resumenDia,
        pageBuilder: (_, s) => _pagina(s, ResumenDiaScreen(cierre: s.extra as CierreCaja)),
      ),
      GoRoute(
        path: Routes.notificaciones,
        pageBuilder: (_, s) => _pagina(s, const NotificacionesScreen()),
      ),
      GoRoute(
        path: Routes.importarInventario,
        pageBuilder: (_, s) => _pagina(s, const ImportarInventarioScreen()),
      ),
      GoRoute(
        path: Routes.migrarOtraApp,
        pageBuilder: (_, s) => _pagina(s, const MigrarOtraAppScreen()),
      ),
      GoRoute(
        path: Routes.proveedorDetalle,
        pageBuilder: (_, s) => _pagina(s, ProveedorDetalleScreen(proveedor: s.extra as Proveedor)),
      ),
      GoRoute(
        path: Routes.proveedorMovimiento,
        pageBuilder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return _pagina(
            s,
            AnotarMovimientoProveedorScreen(
              proveedorPreseleccionado: extra?['proveedorPreseleccionado'] as Proveedor?,
              tipoInicial: extra?['tipoInicial'] as TipoMovimientoProveedor? ?? TipoMovimientoProveedor.compra,
            ),
          );
        },
      ),
      GoRoute(
        path: Routes.eliminarCuenta,
        pageBuilder: (_, s) => _pagina(s, const EliminarCuentaScreen()),
      ),
      GoRoute(
        path: Routes.estadoWhatsApp,
        pageBuilder: (_, s) => _pagina(s, const EstadoScreen()),
      ),
      GoRoute(
        path: Routes.legal,
        pageBuilder: (_, s) => _pagina(s, const LegalScreen()),
      ),
      GoRoute(
        path: Routes.unirseCodigo,
        pageBuilder: (_, s) => _pagina(s, const UnirseCodigoScreen()),
      ),
      GoRoute(
        path: Routes.detalleEmpleado,
        pageBuilder: (_, s) => _pagina(
          s,
          DetalleEmpleadoScreen(membresia: s.extra as Membresia),
        ),
      ),
      GoRoute(
        path: Routes.sesionError,
        pageBuilder: (_, s) => _pagina(s, const SesionErrorScreen()),
      ),
    ],
  );
});

/// Transición de "hojeo": la página nueva entra con un giro 3D desde la
/// derecha, como si estuvieras pasando la hoja de una libreta. La página que
/// se va se desvanece y se corre ligeramente a la izquierda.
CustomTransitionPage<void> _pagina(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return _PageFlip(animation: animation, child: child);
    },
  );
}

/// Efecto visual de hojeo: rotación 3D con perspectiva + sombra de lomo.
class _PageFlip extends StatelessWidget {
  const _PageFlip({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(animation.value);

        // La página se levanta desde abajo (eje X), como pasando la hoja de
        // una libreta con espiral arriba.
        final angle = math.pi / 3 * (1 - value);
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateX(-angle);

        final sombraPliegue = (1 - value) * 0.18;
        final opacidad = 0.7 + 0.3 * value;

        return Stack(
          children: [
            Opacity(
              opacity: opacidad,
              child: Transform(
                transform: transform,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
            if (sombraPliegue > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: sombraPliegue),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }
}
