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
  static const String perfil = '/perfil';
  static const String sesionError = '/sesion-error';
}
