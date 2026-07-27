import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/bcv/bcv_rate_service.dart';
import '../../services/binance/binance_p2p_service.dart';
import 'firebase_providers.dart';

/// Qué tasa de cambio usar para convertir USD → Bs: BCV o Binance P2P.
enum TipoTasa {
  bcv,
  binance;

  String get id => switch (this) {
        TipoTasa.bcv => 'bcv',
        TipoTasa.binance => 'binance',
      };

  static TipoTasa fromId(String? id) =>
      id == 'binance' ? TipoTasa.binance : TipoTasa.bcv;

  String get etiqueta => switch (this) {
        TipoTasa.bcv => 'tasa BCV',
        TipoTasa.binance => 'tasa Binance USDT',
      };
}

/// Tasa activa elegida por el negocio — **estado global**: se comparte entre
/// Cobrar, Reportes, Catálogo, etc. (ver `README` del handoff de diseño). Por
/// ahora solo Cobrar la consume; el resto se conecta en lotes futuros.
///
/// Se persiste con `SharedPreferences` (misma idea que `cc_rate` en el
/// prototipo), así que sobrevive a cerrar la app.
class TasaActivaNotifier extends StateNotifier<TipoTasa> {
  TasaActivaNotifier(this._prefs)
      : super(TipoTasa.fromId(_prefs.getString(_clave)));

  static const _clave = 'tasa_activa';
  final SharedPreferences _prefs;

  void elegir(TipoTasa tipo) {
    state = tipo;
    _prefs.setString(_clave, tipo.id);
  }
}

final tasaActivaProvider =
    StateNotifierProvider<TasaActivaNotifier, TipoTasa>((ref) {
  return TasaActivaNotifier(ref.watch(sharedPreferencesProvider));
});

/// Valor numérico de la tasa activa (USD → Bs), sea cual sea la elegida.
/// `null` mientras la tasa correspondiente no haya cargado.
final tasaActivaValorProvider = Provider<double?>((ref) {
  final tipo = ref.watch(tasaActivaProvider);
  return switch (tipo) {
    TipoTasa.bcv => ref.watch(bcvRateProvider).valueOrNull?.tasa,
    TipoTasa.binance => ref.watch(binanceP2PRateProvider).valueOrNull?.precio,
  };
});
