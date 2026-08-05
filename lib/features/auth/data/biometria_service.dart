import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/firebase_providers.dart';

/// Desbloqueo con huella o rostro (`Lote A · F7`).
///
/// **No es un método de autenticación**: no reemplaza al login de Firebase ni
/// crea sesión. Es un candado sobre la sesión que ya está persistida — el
/// dueño deja la app abierta y la huella evita que quien agarre el teléfono
/// vea las ventas del día. Por eso solo se ofrece cuando ya hay sesión.
class BiometriaService {
  BiometriaService(this._prefs, this._auth);

  static const _clave = 'biometria_activa';

  final SharedPreferences _prefs;
  final LocalAuthentication _auth;

  /// ¿El teléfono tiene huella/rostro configurado y utilizable?
  Future<bool> disponible() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return _auth.canCheckBiometrics;
    } on PlatformException {
      // Fabricantes que no implementan el API: se trata como "no hay".
      return false;
    }
  }

  bool get activa => _prefs.getBool(_clave) ?? false;

  Future<void> activar(bool valor) => _prefs.setBool(_clave, valor);

  /// Códigos con los que este teléfono, sencillamente, no puede identificar a
  /// nadie: no hay sensor, no hay huella registrada, no hay PIN de sistema.
  ///
  /// Solo ante estos se abre el candado sin preguntar. La regla sigue siendo
  /// que un candado roto no puede dejar al dueño fuera de su propio negocio,
  /// pero antes eso valía para **cualquier** `PlatformException`, y con eso se
  /// colaba también un fallo de programación como `no_fragment_activity`.
  static const _sinBiometriaPosible = {
    'NotAvailable',
    'NotEnrolled',
    'PasscodeNotSet',
    'OtherOperatingSystem',
  };

  /// Pide la huella. `true` si el usuario se identificó.
  ///
  /// Los errores se registran siempre. El silencio de antes escondió durante
  /// meses que `authenticate()` lanzaba `no_fragment_activity` en cada intento
  /// —la `MainActivity` no era una `FragmentActivity`—, así que el candado
  /// devolvía `true` sin preguntar nada y no protegía absolutamente nada.
  Future<bool> pedir({String motivo = 'Confirma que eres tú'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[biometria] authenticate → ${e.code}: ${e.message}');

      // El teléfono no puede: se abre, porque exigir algo imposible deja al
      // dueño fuera para siempre.
      if (_sinBiometriaPosible.contains(e.code)) return true;

      // Demasiados intentos fallidos, o un fallo que no sabemos leer: el
      // candado se queda puesto. Abrirlo aquí seria premiar el fallo.
      return false;
    }
  }
}

final biometriaServiceProvider = Provider<BiometriaService>((ref) {
  return BiometriaService(
    ref.watch(sharedPreferencesProvider),
    LocalAuthentication(),
  );
});

/// ¿Hay huella/rostro utilizable en este teléfono?
final biometriaDisponibleProvider = FutureProvider<bool>((ref) {
  return ref.watch(biometriaServiceProvider).disponible();
});
