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

  /// Pide la huella. `true` si el usuario se identificó.
  ///
  /// Un error de plataforma devuelve `true` a propósito: si el candado se
  /// rompe, el dueño se queda fuera de su propio negocio. La huella protege
  /// de un vistazo indiscreto, no de un atacante — no vale dejar la app
  /// inutilizable por defender de más.
  Future<bool> pedir({String motivo = 'Confirma que eres tú'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return true;
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
