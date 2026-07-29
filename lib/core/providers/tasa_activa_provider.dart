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
        TipoTasa.binance => 'tasa paralela',
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

/// Tasa escrita a mano por el dueño cuando la automática no llega o llegó
/// vieja (Lote P · "Escribir la tasa").
///
/// Solo vale el día en que se escribió: una tasa a mano de anteayer es tan
/// peligrosa como la vieja que venía a reemplazar, así que al día siguiente
/// se descarta sola y vuelve a mandar la automática.
class TasaManualNotifier extends StateNotifier<double?> {
  TasaManualNotifier(this._prefs) : super(null) {
    final dia = _prefs.getString(_claveDia);
    if (dia == _hoy()) state = _prefs.getDouble(_claveValor);
  }

  static const _claveValor = 'tasa_manual_valor';
  static const _claveDia = 'tasa_manual_dia';

  final SharedPreferences _prefs;

  static String _hoy() {
    final f = DateTime.now();
    return '${f.year}-${f.month}-${f.day}';
  }

  void escribir(double valor) {
    if (valor <= 0) return;
    state = valor;
    _prefs.setDouble(_claveValor, valor);
    _prefs.setString(_claveDia, _hoy());
  }

  void borrar() {
    state = null;
    _prefs.remove(_claveValor);
    _prefs.remove(_claveDia);
  }
}

final tasaManualProvider =
    StateNotifierProvider<TasaManualNotifier, double?>((ref) {
  return TasaManualNotifier(ref.watch(sharedPreferencesProvider));
});

/// Valor numérico de la tasa activa (USD → Bs), sea cual sea la elegida.
/// `null` mientras la tasa correspondiente no haya cargado.
///
/// La tasa escrita a mano manda sobre la automática: si el dueño se tomó el
/// trabajo de escribirla es porque la de la red no le sirve.
final tasaActivaValorProvider = Provider<double?>((ref) {
  final manual = ref.watch(tasaManualProvider);
  if (manual != null) return manual;

  final tipo = ref.watch(tasaActivaProvider);
  return switch (tipo) {
    TipoTasa.bcv => ref.watch(bcvRateProvider).valueOrNull?.tasa,
    TipoTasa.binance => ref.watch(binanceP2PRateProvider).valueOrNull?.precio,
  };
});
