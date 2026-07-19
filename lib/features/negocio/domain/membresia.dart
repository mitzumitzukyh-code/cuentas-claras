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
        RolMembresia.dueno => 'Dueño',
        RolMembresia.empleado => 'Vendedor',
      };
}

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
  });

  final String id;
  final String usuarioId;
  final String negocioId;
  final RolMembresia rol;

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
    );
  }

  Map<String, dynamic> toMap() => {
        'usuarioId': usuarioId,
        'negocioId': negocioId,
        'rol': rol.id,
        'nombre': nombre,
        'correo': correo,
        // Se omite si no hay código: las reglas distinguen "sin código" (=
        // fundador) de "código presente", y un null explícito no es ninguno
        // de los dos.
        if (codigoInvitacion != null) 'codigoInvitacion': codigoInvitacion,
      };
}
