/// Rutas y IDs de Firestore centralizados (ver modelo en `CLAUDE.md` §4).
///
/// Evita strings de colección repartidos por los repositorios.
abstract final class FirestorePaths {
  const FirestorePaths._();

  static const String negocios = 'negocios';
  static const String membresias = 'membresias';
  static const String invitaciones = 'invitaciones';

  // Subcolecciones de un negocio.
  static const String productos = 'productos';
  static const String insumos = 'insumos';
  static const String ventas = 'ventas';
  static const String gastos = 'gastos';
  static const String clientes = 'clientes';
  static const String proveedores = 'proveedores';
  static const String cierres = 'cierres';

  /// Subcolección de un cliente o proveedor.
  static const String movimientos = 'movimientos';

  /// Registro de quién hizo qué (Lote E · P3).
  static const String auditoria = 'auditoria';

  /// ID de membresía: `usuarioId_negocioId` (debe coincidir con las reglas).
  static String membresiaId(String usuarioId, String negocioId) =>
      '${usuarioId}_$negocioId';
}
