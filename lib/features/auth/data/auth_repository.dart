import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/firebase_providers.dart';

/// Acceso a Firebase Authentication.
///
/// Métodos: correo + contraseña (principal, según el diseño), Google Sign-In y
/// enlace de acceso por correo. El login por SMS se descartó por su costo.
class AuthRepository {
  AuthRepository(
    this._auth, {
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? almacenSeguro,
  }) : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
       _seguro = almacenSeguro ?? const FlutterSecureStorage();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Almacén cifrado (Keystore/EncryptedSharedPreferences) para poder
  /// re-autenticar al arrancar. Ver [restaurarSesion].
  final FlutterSecureStorage _seguro;

  static const _kTipo = 'sesion_tipo'; // 'correo' | 'google'
  static const _kCorreo = 'sesion_correo';
  static const _kClave = 'sesion_clave';

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> _guardarSesionCorreo(String correo, String contrasena) async {
    await _seguro.write(key: _kTipo, value: 'correo');
    await _seguro.write(key: _kCorreo, value: correo);
    await _seguro.write(key: _kClave, value: contrasena);
  }

  Future<void> _guardarSesionGoogle() async {
    await _seguro.write(key: _kTipo, value: 'google');
    await _seguro.delete(key: _kCorreo);
    await _seguro.delete(key: _kClave);
  }

  Future<void> _olvidarSesion() async {
    await _seguro.delete(key: _kTipo);
    await _seguro.delete(key: _kCorreo);
    await _seguro.delete(key: _kClave);
  }

  /// `true` cuando la sesión guardada se descartó sola porque las credenciales
  /// dejaron de servir (`Lote F · P4`).
  ///
  /// Distinto de "nunca hubo sesión": el dueño sí había entrado y de pronto se
  /// encuentra el login. Sin decírselo parece que la app perdió sus datos.
  bool sesionExpirada = false;

  /// Restaura la sesión al arrancar cuando Firebase no lo hace por su cuenta.
  ///
  /// En release, sobre el ROM del teléfono de pruebas (Z2464N), Firebase Auth
  /// NO restauraba la sesión guardada tras cerrar y reabrir la app: aunque el
  /// login fuera correcto y el archivo cifrado del usuario quedara en disco,
  /// `currentUser` amanecía en `null` (verificado con un sondeo en el splash:
  /// `NULL` a los 3,5 s, 9,5 s y 14 s). En debug sí restauraba — por eso el
  /// bug era invisible en desarrollo. Esto obligaba a re-loguearse en cada
  /// arranque.
  ///
  /// La solución no depende de la persistencia nativa: si al abrir ya hay
  /// sesión, no hace nada; si no la hay pero se guardó cómo se entró, la
  /// rehace. Con Google es silencioso (usa la sesión de Google Play, sin
  /// contraseña); con correo re-autentica con las credenciales cifradas.
  /// Necesita internet — sin señal se cae al login, igual que un login normal.
  ///
  /// Nunca lanza: una credencial inválida (contraseña cambiada) o una red
  /// caída no deben tumbar el arranque; en ese caso se queda sin sesión y el
  /// usuario entra a mano.
  Future<void> restaurarSesion() async {
    if (_auth.currentUser != null) return; // Firebase ya la tenía.
    try {
      final tipo = await _seguro.read(key: _kTipo);
      if (tipo == 'google') {
        final cuenta = await _googleSignIn.signInSilently();
        if (cuenta == null) return;
        final a = await cuenta.authentication;
        await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: a.accessToken,
            idToken: a.idToken,
          ),
        );
      } else if (tipo == 'correo') {
        final correo = await _seguro.read(key: _kCorreo);
        final clave = await _seguro.read(key: _kClave);
        if (correo == null || clave == null) return;
        await _auth.signInWithEmailAndPassword(
          email: correo,
          password: clave,
        );
      }
    } on FirebaseAuthException catch (e) {
      // La contraseña ya no sirve (el usuario la cambió en otro lado): se
      // olvida para no reintentar en vano en cada arranque. Un fallo de red
      // NO invalida las credenciales, así que esas se conservan.
      const invalidas = {
        'wrong-password',
        'invalid-credential',
        'user-not-found',
        'user-disabled',
      };
      if (invalidas.contains(e.code)) {
        sesionExpirada = true;
        await _olvidarSesion();
      }
    } catch (_) {
      // Red u otro fallo transitorio: se reintenta en el próximo arranque.
    }
  }

  /// Inicia sesión con correo y contraseña.
  ///
  /// Requiere el proveedor "Correo electrónico/contraseña" habilitado en
  /// Firebase Auth → Sign-in method.
  Future<UserCredential> iniciarSesionConCorreo(
    String correo,
    String contrasena,
  ) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
    await _guardarSesionCorreo(correo.trim(), contrasena);
    return cred;
  }

  /// Crea una cuenta con correo y contraseña (paso 1 del onboarding).
  Future<UserCredential> registrarConCorreo(
    String correo,
    String contrasena,
  ) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
    await _guardarSesionCorreo(correo.trim(), contrasena);
    return cred;
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
    final cred = await _auth.signInWithCredential(credential);
    await _guardarSesionGoogle();
    return cred;
  }

  /// Cierra sesión tanto en Google como en Firebase.
  Future<void> cerrarSesion() async {
    await _olvidarSesion();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// `true` si la sesión actual se inició con Google (no con correo y
  /// contraseña) — determina qué le pide `eliminarCuenta` para reautenticar.
  bool get sesionEsGoogle =>
      _auth.currentUser?.providerData.any(
        (p) => p.providerId == GoogleAuthProvider.PROVIDER_ID,
      ) ??
      false;

  /// Borra la cuenta de acceso de Firebase (requisito de borrado de cuenta
  /// de Google Play). Los datos del negocio se borran aparte, en
  /// [NegocioRepository], ANTES de llamar a esto.
  ///
  /// Borrar la cuenta es una operación "sensible": Firebase exige un login
  /// reciente y si no lo hay, `user.delete()` falla con
  /// `requires-recent-login`. Para no depender de que la sesión sea reciente
  /// (el dueño pudo entrar hace días), siempre se reautentica primero — con
  /// Google, sin que el usuario tenga que escribir nada; con correo,
  /// [contrasenaActual] es obligatoria.
  Future<void> eliminarCuenta({String? contrasenaActual}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (sesionEsGoogle) {
      final cuenta = await _googleSignIn.signIn();
      if (cuenta == null) {
        throw FirebaseAuthException(
          code: 'reautenticacion-cancelada',
          message: 'Cancelaste la confirmación con Google.',
        );
      }
      final autenticacion = await cuenta.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: autenticacion.accessToken,
        idToken: autenticacion.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else {
      if (contrasenaActual == null || contrasenaActual.isEmpty) {
        throw FirebaseAuthException(
          code: 'falta-contrasena',
          message: 'Escribe tu contraseña para confirmar.',
        );
      }
      final credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: contrasenaActual,
      );
      await user.reauthenticateWithCredential(credential);
    }

    await user.delete();
    await _olvidarSesion();
    await _googleSignIn.signOut();
  }
}

// --- Providers ---

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});

/// Estado de autenticación en tiempo real. Fuente de verdad para el router.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  // Firebase restaura la sesión guardada de forma síncrona durante
  // `initializeApp`, así que `currentUser` ya está disponible aquí. Se emite
  // primero para que el estado de sesión NUNCA pase por un "sin usuario"
  // transitorio: sin esto, en release `authStateChanges()` podía tardar un
  // instante (o emitir `null` antes de cargar la sesión) y la app rebotaba a
  // la pantalla de login a alguien que sí tenía sesión — el clásico "tengo que
  // volver a iniciar sesión cada vez que abro la app".
  yield repo.currentUser;
  yield* repo.authStateChanges();
});

/// Rehace la sesión al arrancar si Firebase no la restauró por su cuenta
/// (ver [AuthRepository.restaurarSesion]). Se ejecuta una sola vez por arranque;
/// el estado de sesión espera a que termine antes de decidir mandar al login,
/// para no mostrar el login un instante y saltar solo al dashboard. Con
/// timeout: sin señal, la re-autenticación puede colgarse, y es preferible
/// caer al login a dejar la app congelada en el splash.
final restaurarSesionProvider = FutureProvider<void>((ref) async {
  final repo = ref.read(authRepositoryProvider);
  try {
    await repo.restaurarSesion().timeout(const Duration(seconds: 12));
  } catch (_) {
    // Timeout u otro fallo: se sigue; el usuario entra a mano si hace falta.
  }
});
