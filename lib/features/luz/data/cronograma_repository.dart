import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/cronograma_luz.dart';

const String _baseUrl = 'https://cuenta-clara-tasa.mitzumitzukyhs.workers.dev';

/// El cronograma de cortes: se baja del Worker y se guarda en el teléfono.
///
/// **Se guarda porque la luz se va.** Es el único dato de la app que hace
/// falta justo cuando lo más probable es que no haya internet: sin luz no hay
/// wifi, y a veces tampoco antena. Lo que se bajó ayer tiene que seguir
/// sirviendo hoy.
///
/// **Y se refresca sin sesión.** El endpoint es público: no lleva ni un dato
/// del negocio, y exigir sesión para leer un cronograma que Corpoelec pega en
/// la calle solo serviría para que a alguien le fallara el aviso.
class CronogramaRepository {
  CronogramaRepository(this._prefs, {http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _cliente;

  static const _claveJson = 'cronograma_luz_json';
  static const _claveBajado = 'cronograma_luz_bajado';
  static const _claveBloque = 'cronograma_luz_bloque';
  static const _claveActivo = 'cronograma_luz_activo';

  /// El bloque del dueño (`A`…`D`), o `null` si no lo ha elegido.
  String? get bloque => _prefs.getString(_claveBloque);

  /// Los avisos están encendidos. **Por defecto NO**, al revés que los
  /// recordatorios: esto solo sirve si vives en el estado del cronograma, y
  /// una notificación sobre cortes en Barinas a alguien de Maracaibo es ruido.
  bool get activo => (_prefs.getBool(_claveActivo) ?? false) && bloque != null;

  Future<void> guardarBloque(String? valor) async {
    if (valor == null) {
      await _prefs.remove(_claveBloque);
    } else {
      await _prefs.setString(_claveBloque, valor.toUpperCase());
    }
  }

  Future<void> guardarActivo(bool valor) =>
      _prefs.setBool(_claveActivo, valor);

  /// Lo que haya guardado, sin tocar la red.
  CronogramaLuz? enCache() {
    final crudo = _prefs.getString(_claveJson);
    if (crudo == null) return null;
    try {
      return CronogramaLuz.fromJson(
        jsonDecode(crudo) as Map<String, dynamic>,
      );
    } catch (_) {
      // Un JSON corrupto o de una versión vieja del formato no debe dejar la
      // app sin arrancar: se ignora y se vuelve a bajar.
      return null;
    }
  }

  /// Cuándo se bajó por última vez.
  DateTime? get bajadoEn {
    final v = _prefs.getString(_claveBajado);
    return v == null ? null : DateTime.tryParse(v);
  }

  /// El cronograma vigente, bajándolo si hace falta.
  ///
  /// Se refresca cuando no hay nada guardado, cuando lo guardado ya no cubre
  /// hoy —cambió el mes— o cuando pasó un día desde la última bajada. Un
  /// fallo de red nunca borra lo que ya había.
  Future<CronogramaLuz?> vigente({
    String estado = 'barinas',
    DateTime? ahora,
  }) async {
    final hoy = ahora ?? DateTime.now();
    final guardado = enCache();

    final vencido = bajadoEn == null ||
        hoy.difference(bajadoEn!).inHours >= 24 ||
        guardado == null ||
        !guardado.cubre(hoy);

    if (!vencido) return guardado;

    try {
      final fresco = await refrescar(estado: estado);
      return fresco ?? guardado;
    } catch (_) {
      return guardado;
    }
  }

  /// Baja el cronograma y lo guarda. Devuelve `null` si el Worker no tiene
  /// uno para ese estado (404), que es un «no hay», no un error.
  Future<CronogramaLuz?> refrescar({String estado = 'barinas'}) async {
    final resp = await _cliente
        .get(Uri.parse('$_baseUrl/cronograma-luz?estado=$estado'))
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw Exception('El cronograma respondió ${resp.statusCode}.');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final cronograma = CronogramaLuz.fromJson(json);
    await _prefs.setString(_claveJson, resp.body);
    await _prefs.setString(
      _claveBajado,
      DateTime.now().toIso8601String(),
    );
    return cronograma;
  }
}

final cronogramaRepositoryProvider = Provider<CronogramaRepository>((ref) {
  return CronogramaRepository(ref.watch(sharedPreferencesProvider));
});
