import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/firebase_providers.dart';

/// Tasa oficial del dólar (BCV) devuelta por ve.dolarapi.com (CLAUDE.md §2).
class BcvRate {
  const BcvRate({
    required this.compra,
    required this.venta,
    required this.promedio,
    required this.fechaActualizacion,
  });

  final double compra;
  final double venta;
  final double promedio;
  final DateTime fechaActualizacion;

  /// Valor a usar para convertir precios USD → Bs.
  double get tasa => promedio;

  factory BcvRate.fromJson(Map<String, dynamic> json) {
    return BcvRate(
      compra: (json['compra'] as num?)?.toDouble() ?? 0,
      venta: (json['venta'] as num?)?.toDouble() ?? 0,
      promedio: (json['promedio'] as num?)?.toDouble() ??
          (json['venta'] as num?)?.toDouble() ??
          0,
      fechaActualizacion:
          DateTime.tryParse(json['fechaActualizacion']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toCache() => {
        'compra': compra,
        'venta': venta,
        'promedio': promedio,
        'fechaActualizacion': fechaActualizacion.toIso8601String(),
      };
}

/// Obtiene y cachea la tasa BCV. El brief pide refrescar 1 vez al día
/// (CLAUDE.md §6): se guarda en `SharedPreferences` con la fecha de descarga.
class BcvRateService {
  BcvRateService(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  static const _endpoint = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const _cacheKey = 'bcv_rate_cache';
  static const _cacheDateKey = 'bcv_rate_cache_date';

  final SharedPreferences _prefs;
  final http.Client _client;

  /// Devuelve la tasa. Usa caché si ya se descargó hoy, salvo [forzar].
  Future<BcvRate> obtenerTasa({bool forzar = false}) async {
    if (!forzar && _cacheEsDeHoy()) {
      final cache = _leerCache();
      if (cache != null) return cache;
    }
    try {
      final rate = await _descargar();
      await _guardarCache(rate);
      return rate;
    } catch (e) {
      // Sin red: degradar a la última tasa conocida si existe.
      final cache = _leerCache();
      if (cache != null) return cache;
      rethrow;
    }
  }

  Future<BcvRate> _descargar() async {
    final resp = await _client
        .get(Uri.parse(_endpoint))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('BCV API respondió ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    return BcvRate.fromJson(json);
  }

  bool _cacheEsDeHoy() {
    final iso = _prefs.getString(_cacheDateKey);
    if (iso == null) return false;
    final fecha = DateTime.tryParse(iso);
    if (fecha == null) return false;
    final ahora = DateTime.now();
    return fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;
  }

  BcvRate? _leerCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return BcvRate.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarCache(BcvRate rate) async {
    await _prefs.setString(_cacheKey, jsonEncode(rate.toCache()));
    await _prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
  }
}

// --- Providers ---

final bcvRateServiceProvider = Provider<BcvRateService>((ref) {
  return BcvRateService(ref.watch(sharedPreferencesProvider));
});

/// Tasa BCV para la UI (dashboard, cálculo de Bs). Se refresca al invalidar.
final bcvRateProvider = FutureProvider<BcvRate>((ref) {
  return ref.watch(bcvRateServiceProvider).obtenerTasa();
});
