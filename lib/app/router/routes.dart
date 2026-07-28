/// Rutas de la app (paths de go_router). Centralizadas para evitar strings
/// sueltos en las pantallas.
abstract final class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/';
  static const String productos = '/productos';
  static const String nuevoProducto = '/productos/nuevo';
  static const String cobrar = '/cobrar';
  static const String reportes = '/reportes';
  static const String perfil = '/perfil';
  static const String ajustes = '/perfil/ajustes';
  static const String gastos = '/gastos';
  static const String fiados = '/fiados';
  static const String arqueo = '/arqueo';
  static const String proveedores = '/proveedores';
  static const String empleados = '/perfil/empleados';
  static const String metodosPago = '/perfil/metodos-pago';
  static const String impresora = '/perfil/impresora';
  static const String planes = '/planes';
  static const String catalogo = '/catalogo';
  static const String miPerfil = '/perfil/mi-perfil';
  static const String ayuda = '/perfil/ayuda';
  static const String historialVentas = '/ventas/historial';
  static const String tutorial = '/tutorial';
  static const String ventasPendientes = '/ventas/pendientes';
  static const String nuevoGasto = '/gastos/nuevo';
  static const String fiadoDetalle = '/fiados/:clienteId';
  static const String fiadoMovimiento = '/fiados/:clienteId/movimiento';
  static const String ventaDetalle = '/ventas/detalle/:ventaId';
  static const String resumenDia = '/arqueo/resumen/:cierreId';
  static const String notificaciones = '/notificaciones';
  static const String importarInventario = '/productos/importar';
  static const String migrarOtraApp = '/productos/migrar';
  static const String proveedorDetalle = '/proveedores/:proveedorId';
  static const String proveedorMovimiento = '/proveedores/:proveedorId/movimiento';
  static const String legal = '/perfil/legal';
  static const String selectorBanco = '/perfil/selector-banco';
  static const String detalleEmpleado = '/perfil/empleados/:membresiaId';
  static const String eliminarCuenta = '/perfil/eliminar-cuenta';
  static const String estadoWhatsApp = '/catalogo/estado';
  static const String sesionError = '/sesion-error';
}
