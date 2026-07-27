import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/firebase_providers.dart';

/// Tasa Binance P2P (USDT/VES) usada como alternativa a la tasa BCV.
///
/// **Fuente no oficial:** consume el endpoint interno que usa la propia
/// página web de Binance P2P (`p2p.binance.com`), no una API pública
/// documentada. Mitzuky aceptó el riesgo explícitamente (2026-07-24): puede
/// dejar de responder, cambiar de forma o bloquear por rate-limit sin aviso.
/// Por eso siempre se degrada a la última tasa en caché en vez de tumbar la
/// pantalla de Cobrar.
class BinanceP2PRate {
  const BinanceP2PRate({required this.precio, required this.obtenidaEn});

  /// Precio promedio de VES por 1 USDT.
  final double precio;
  final DateTime obtenidaEn;

  factory BinanceP2PRate.fromCache(Map<String, dynamic> json) =>
      BinanceP2PRate(
        precio: (json['precio'] as num).toDouble(),
        obtenidaEn: DateTime.parse(json['obtenidaEn'] as String),
      );

  Map<String, dynamic> toCache() => {
        'precio': precio,
        'obtenidaEn': obtenidaEn.toIso8601String(),
      };
}

/// Obtiene y cachea la tasa Binance P2P. A diferencia de BCV (que se refresca
/// una vez al día por venir de una API oficial), esta se considera vigente
/// por [_validezCache] porque el mercado P2P se mueve varias veces al día.
class BinanceP2PService {
  BinanceP2PService(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  static const _endpoint =
      'https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search';
  static const _cacheKey = 'binance_p2p_rate_cache';
  static const _validezCache = Duration(minutes: 20);

  final SharedPreferences _prefs;
  final http.Client _client;

  Future<BinanceP2PRate> obtenerTasa({bool forzar = false}) async {
    if (!forzar) {
      final cache = _leerCache();
      if (cache != null &&
          DateTime.now().difference(cache.obtenidaEn) < _validezCache) {
        return cache;
      }
    }
    try {
      final rate = await _descargar();
      await _prefs.setString(_cacheKey, jsonEncode(rate.toCache()));
      return rate;
    } catch (e) {
      final cache = _leerCache();
      if (cache != null) return cache;
      rethrow;
    }
  }

  Future<BinanceP2PRate> _descargar() async {
    final resp = await _client
        .post(
          Uri.parse(_endpoint),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(const {
            'asset': 'USDT',
            'fiat': 'VES',
            'tradeType': 'SELL',
            'page': 1,
            'rows': 10,
            'payTypes': <String>[],
            'publisherType': null,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('Binance P2P respondió ${resp.statusCode}');
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final anuncios = (json['data'] as List?) ?? const [];
    final precios = anuncios
        .whereType<Map<String, dynamic>>()
        .map((a) => a['adv'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((adv) => double.tryParse('${adv['price']}'))
        .whereType<double>()
        .take(5)
        .toList();
    if (precios.isEmpty) {
      throw Exception('Binance P2P no devolvió anuncios usables');
    }
    final promedio = precios.reduce((a, b) => a + b) / precios.length;
    return BinanceP2PRate(precio: promedio, obtenidaEn: DateTime.now());
  }

  BinanceP2PRate? _leerCache() {
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return BinanceP2PRate.fromCache(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}

// --- Providers ---

final binanceP2PServiceProvider = Provider<BinanceP2PService>((ref) {
  return BinanceP2PService(ref.watch(sharedPreferencesProvider));
});

final binanceP2PRateProvider = FutureProvider<BinanceP2PRate>((ref) {
  return ref.watch(binanceP2PServiceProvider).obtenerTasa();
});
