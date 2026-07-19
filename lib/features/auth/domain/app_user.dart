import 'package:firebase_auth/firebase_auth.dart';

/// Usuario autenticado (envoltura ligera sobre el `User` de Firebase).
///
/// Los datos provienen del proveedor principal (Google): nombre, correo y foto
/// de perfil.
class AppUser {
  const AppUser({
    required this.uid,
    this.nombre,
    this.email,
    this.fotoUrl,
  });

  final String uid;
  final String? nombre;
  final String? email;
  final String? fotoUrl;

  factory AppUser.fromFirebase(User user) => AppUser(
        uid: user.uid,
        nombre: user.displayName,
        email: user.email,
        fotoUrl: user.photoURL,
      );

  /// Etiqueta a mostrar (nombre o, en su defecto, el correo).
  String get displayName =>
      nombre?.trim().isNotEmpty == true ? nombre! : (email ?? 'Usuario');

  /// Iniciales para el avatar cuando no hay foto (ej: "MC").
  String get iniciales {
    final base = displayName.trim();
    if (base.isEmpty) return '?';
    final partes = base.split(RegExp(r'\s+'));
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes.first.substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }
}
