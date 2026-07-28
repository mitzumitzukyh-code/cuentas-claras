import 'package:cloud_firestore/cloud_firestore.dart';

/// Rol del usuario dentro de un negocio (CLAUDE.md §6).
enum RolMembresia {
  dueno,
  empleado;

  String get id => name;

  static RolMembresia fromId(String? id) => RolMembresia.values.firstWhere(
    (r) => r.id == id,
    orElse: () => RolMembresia.empleado,
  );

  bool get esDueno => this == RolMembresia.dueno;

  String get etiqueta => switch (this) {
    RolMembresia.dueno => 'Administrador',
    RolMembresia.empleado => 'Vendedor',
  };
}

/// Permisos granularizados para un miembro del negocio.
/// Dueño tiene todos `true` y no editables.
const permisosDueno = {
  'cobrar': true,
  'verReportes': true,
  'editarInventario': true,
  'registrarGastos': true,
  'cerrarCaja': true,
  'gestionarEmpleados': true,
};

const permisosEmpleadoBase = {
  'cobrar': true,
  'verReportes': false,
  'editarInventario': false,
  'registrarGastos': false,
  'cerrarCaja': false,
  'gestionarEmpleados': false,
};

/// Relación usuario ↔ negocio (CLAUDE.md §4: `membresias/{usuarioId}_{negocioId}`).
class Membresia {
  const Membresia({
    required this.id,
    required this.usuarioId,
    required this.negocioId,
    required this.rol,
    this.nombre,
    this.correo,
    this.codigoInvitacion,
    this.pushToken,
    this.permisos,
  });

  final String id;
  final String usuarioId;
  final String negocioId;
  final RolMembresia rol;

  /// Mapa granular de permisos. Si es `null`, se deriva del [rol].
  /// Claves: cobrar, verReportes, editarInventario, registrarGastos,
  /// cerrarCaja, gestionarEmpleados.
  final Map<String, bool>? permisos;

  /// Permisos efectivos: si el dueño tiene todos `true`; si es empleado
  /// sin permisos definidos, usa la base.
  Map<String, bool> get permisosEfectivos => permisos ?? _permisosPorRol;

  Map<String, bool> get _permisosPorRol => switch (rol) {
    RolMembresia.dueno => Map.from(permisosDueno),
    RolMembresia.empleado => Map.from(permisosEmpleadoBase),
  };

  /// Helper: `puede('cobrar') → true/false`.
  bool puede(String permiso) => permisosEfectivos[permiso] ?? false;

  /// Token FCM del dispositivo de este miembro. Solo se usa si es dueño: el
  /// Worker lo lee para mandarle el resumen de ventas del día directo a su
  /// teléfono — a diferencia de los avisos de tasa BCV (que van por topics
  /// compartidos), esto sí es personal por negocio.
  final String? pushToken;

  /// Código de invitación con el que se creó esta membresía, o `null` si quien
  /// la tiene fundó el negocio.
  ///
  /// Las reglas de Firestore lo exigen para dar de alta a un miembro que no es
  /// el fundador: sin un código vivo, sin usar y del mismo negocio y rol, la
  /// escritura se rechaza. Es lo que impide colarse en un negocio ajeno.
  final String? codigoInvitacion;

  /// Nombre visible del miembro. Se copia al crear la membresía porque
  /// Firestore no puede leer la tabla de usuarios de Firebase Auth.
  final String? nombre;

  final String? correo;

  /// Lo que se muestra en la lista de empleados.
  String get nombreVisible {
    if (nombre != null && nombre!.trim().isNotEmpty) return nombre!;
    if (correo != null && correo!.isNotEmpty) return correo!;
    return 'Usuario ${usuarioId.substring(0, usuarioId.length.clamp(0, 6))}';
  }

  /// Iniciales para el avatar, máximo dos letras.
  String get iniciales {
    final base = nombreVisible.trim();
    if (base.isEmpty) return '?';
    final partes = base.split(RegExp(r'[\s@._]+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return base[0].toUpperCase();
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.elementAt(1)[0]).toUpperCase();
  }

  factory Membresia.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Membresia(
      id: doc.id,
      usuarioId: (data['usuarioId'] as String?) ?? '',
      negocioId: (data['negocioId'] as String?) ?? '',
      rol: RolMembresia.fromId(data['rol'] as String?),
      nombre: data['nombre'] as String?,
      correo: data['correo'] as String?,
      codigoInvitacion: data['codigoInvitacion'] as String?,
      pushToken: data['pushToken'] as String?,
      permisos: (data['permisos'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as bool)),
    );
  }

  Map<String, dynamic> toMap() => {
    'usuarioId': usuarioId,
    'negocioId': negocioId,
    'rol': rol.id,
    'nombre': nombre,
    'correo': correo,
    if (permisos != null) 'permisos': permisos,
    // Se omite si no hay código: las reglas distinguen "sin código" (=
    // fundador) de "código presente", y un null explícito no es ninguno
    // de los dos.
    if (codigoInvitacion != null) 'codigoInvitacion': codigoInvitacion,
  };
}
