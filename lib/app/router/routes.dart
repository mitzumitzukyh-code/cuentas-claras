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

  /// Cobrar abierto directamente en el segmentado "Cotización".
  static const String cobrarCotizacion = '$cobrar?modo=cotizacion';

  /// Cobrar con el escáner de código de barras ya levantado.
  static const String cobrarEscanear = '$cobrar?escanear=1';
  static const String reportes = '/reportes';
  static const String perfil = '/perfil';
  static const String ajustes = '/perfil/ajustes';
  static const String gastos = '/gastos';
  static const String fiados = '/fiados';
  static const String arqueo = '/arqueo';
  static const String arqueoInventario = '/productos/contar';
  static const String insumos = '/productos/insumos';
  static const String sesionExpirada = '/sesion-expirada';
  static const String misNegocios = '/mis-negocios';
  static const String auditoria = '/perfil/auditoria';
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
  static const String detalleEmpleado = '/perfil/empleados/:membresiaId';
  static const String eliminarCuenta = '/perfil/eliminar-cuenta';
  static const String estadoWhatsApp = '/catalogo/estado';
  static const String sesionError = '/sesion-error';
  static const String unirseCodigo = '/perfil/unirse-codigo';

  /// Ruta para anotar un fiado o un abono.
  ///
  /// Sin cliente (un fiado nuevo, desde la lista) el segmento se rellena con
  /// `nuevo` en vez de dejarlo vacío: `replaceAll(':clienteId', '')` producía
  /// `/fiados//movimiento`, que no casa con ninguna ruta y mandaba al
  /// "Page Not Found" de GoRouter. Los botones "Nuevo fiado" y "Anotar un
  /// fiado" no funcionaban.
  ///
  /// El valor del segmento da igual —la pantalla recibe el cliente por
  /// `extra`, no por el path— pero tiene que existir para que la ruta case.
  /// `nuevo` no choca con [fiadoDetalle] porque esa tiene dos segmentos y
  /// esta tres.
  static String fiadoMovimientoDe([String? clienteId]) =>
      fiadoMovimiento.replaceAll(
        ':clienteId',
        (clienteId == null || clienteId.isEmpty) ? 'nuevo' : clienteId,
      );
}
