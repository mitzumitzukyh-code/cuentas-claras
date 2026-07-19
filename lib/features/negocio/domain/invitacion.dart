import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'membresia.dart';

/// Código para sumar a alguien a un negocio (CLAUDE.md §4: `invitaciones/{codigo}`).
///
/// Caduca a las 24 h y es de un solo uso, para que un código filtrado no sirva
/// de puerta abierta al inventario.
class Invitacion {
  const Invitacion({
    required this.codigo,
    required this.negocioId,
    required this.negocioNombre,
    required this.rol,
    required this.expiraEn,
    this.usado = false,
  });

  final String codigo;
  final String negocioId;

  /// Se guarda para poder mostrar "Te unes a X" antes de aceptar: quien recibe
  /// la invitación todavía no tiene permiso de leer el negocio.
  final String negocioNombre;

  final RolMembresia rol;
  final DateTime expiraEn;
  final bool usado;

  bool get vencida => DateTime.now().isAfter(expiraEn);

  bool get valida => !usado && !vencida;

  static const Duration duracion = Duration(hours: 24);

  /// Genera un código de 6 caracteres legible en voz alta.
  ///
  /// Sin `O`, `0`, `I` ni `1`: se confunden al dictarlos por teléfono.
  static String generarCodigo() {
    const alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => alfabeto[r.nextInt(alfabeto.length)]).join();
  }

  factory Invitacion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Invitacion(
      codigo: doc.id,
      negocioId: (data['negocioId'] as String?) ?? '',
      negocioNombre: (data['negocioNombre'] as String?) ?? 'el negocio',
      rol: RolMembresia.fromId(data['rol'] as String?),
      expiraEn:
          (data['expiraEn'] as Timestamp?)?.toDate() ?? DateTime(2000),
      usado: (data['usado'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'negocioId': negocioId,
        'negocioNombre': negocioNombre,
        'rol': rol.id,
        'expiraEn': Timestamp.fromDate(expiraEn),
        'usado': usado,
      };
}
