import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/firebase_providers.dart';

/// Acceso a Firebase Authentication.
///
/// Métodos: correo + contraseña (principal, según el diseño), Google Sign-In y
/// enlace de acceso por correo. El login por SMS se descartó por su costo.
class AuthRepository {
  AuthRepository(this._auth, {GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Inicia sesión con correo y contraseña.
  ///
  /// Requiere el proveedor "Correo electrónico/contraseña" habilitado en
  /// Firebase Auth → Sign-in method.
  Future<UserCredential> iniciarSesionConCorreo(
    String correo,
    String contrasena,
  ) {
    return _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  /// Crea una cuenta con correo y contraseña (paso 1 del onboarding).
  Future<UserCredential> registrarConCorreo(String correo, String contrasena) {
    return _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  /// Envía el correo de restablecimiento de contraseña.
  Future<void> enviarRecuperacion(String correo) {
    return _auth.sendPasswordResetEmail(email: correo.trim());
  }

  /// Inicia sesión con Google. Devuelve `null` si el usuario cancela el
  /// selector de cuentas (no es un error).
  Future<UserCredential?> iniciarSesionConGoogle() async {
    final cuenta = await _googleSignIn.signIn();
    if (cuenta == null) return null; // cancelado por el usuario

    final autenticacion = await cuenta.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: autenticacion.accessToken,
      idToken: autenticacion.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Envía un enlace de acceso al correo (magic link).
  ///
  /// Usa un dominio de Firebase Hosting del proyecto (autorizado por defecto).
  /// TODO(setup): habilitar "Email link (passwordless sign-in)" en Firebase
  /// Auth y configurar App Links / dominio para que el enlace abra la app.
  Future<void> enviarEnlaceCorreo(String correo) {
    final settings = ActionCodeSettings(
      url: 'https://cuenta-clara-5002c.firebaseapp.com/finishSignIn',
      handleCodeInApp: true,
      androidPackageName: 'com.mitzukyhsdev.cuentaclara',
      iOSBundleId: 'com.mitzukyhsdev.cuentaclara',
      androidInstallApp: true,
    );
    return _auth.sendSignInLinkToEmail(
      email: correo,
      actionCodeSettings: settings,
    );
  }

  /// Cierra sesión tanto en Google como en Firebase.
  Future<void> cerrarSesion() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

// --- Providers ---

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

/// Estado de autenticación en tiempo real. Fuente de verdad para el router.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
