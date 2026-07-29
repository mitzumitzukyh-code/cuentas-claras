import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_providers.dart';
import 'tasa_activa_provider.dart';

/// La tasa de un día, tal como la vio este teléfono.
class TasaDelDia {
  const TasaDelDia({required this.fecha, required this.valor});

  final DateTime fecha;
  final double valor;

  /// "2026-07-28" — también es la clave del mapa guardado, así que anotar dos
  /// veces el mismo día sobrescribe en vez de duplicar.
  static String claveDe(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  /// "Hoy, lunes 27" / "sábado 25".
  String get etiqueta {
    const dias = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
    ];
    final hoy = DateTime.now();
    final esHoy = fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day;
    final nombre = '${dias[fecha.weekday - 1]} ${fecha.day}';
    return esHoy ? 'Hoy, $nombre' : nombre;
  }
}

/// Guarda un valor por día de la tasa activa y devuelve los últimos días.
///
/// Vive en `SharedPreferences`, no en Firestore: es un dato de lectura para
/// que el dueño note si la tasa se movió mucho de un día a otro, no un
/// registro contable. Guardarlo en el servidor obligaría a decidir quién lo
/// escribe cuando hay varios vendedores y no aportaría nada a cambio.
///
/// Solo conserva [_maxDias] días — el mapa no crece sin límite.
class HistorialTasaNotifier extends StateNotifier<List<TasaDelDia>> {
  HistorialTasaNotifier(this._prefs) : super(const []) {
    _cargar();
  }

  static const _clave = 'historial_tasa';
  static const _maxDias = 7;

  final SharedPreferences _prefs;

  void _cargar() {
    final crudo = _prefs.getString(_clave);
    if (crudo == null) return;
    try {
      final mapa = (jsonDecode(crudo) as Map).cast<String, dynamic>();
      state = _ordenar(mapa);
    } catch (_) {
      // Formato viejo o corrupto: se descarta, no vale la pena reventar
      // Ajustes por un dato decorativo.
      _prefs.remove(_clave);
    }
  }

  List<TasaDelDia> _ordenar(Map<String, dynamic> mapa) {
    final lista = <TasaDelDia>[];
    for (final e in mapa.entries) {
      final fecha = DateTime.tryParse(e.key);
      final valor = (e.value as num?)?.toDouble();
      if (fecha == null || valor == null) continue;
      lista.add(TasaDelDia(fecha: fecha, valor: valor));
    }
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista.take(_maxDias).toList();
  }

  /// Anota la tasa de hoy. Idempotente: llamarlo varias veces en el mismo día
  /// solo actualiza el valor.
  void anotar(double valor) {
    if (valor <= 0) return;
    final hoy = DateTime.now();
    final mapa = <String, dynamic>{
      for (final d in state) TasaDelDia.claveDe(d.fecha): d.valor,
      TasaDelDia.claveDe(hoy): valor,
    };
    final ordenado = _ordenar(mapa);
    // Sin cambios reales: no reescribir el disco ni notificar a la UI.
    if (ordenado.length == state.length &&
        ordenado.isNotEmpty &&
        state.isNotEmpty &&
        ordenado.first.valor == state.first.valor &&
        TasaDelDia.claveDe(ordenado.first.fecha) ==
            TasaDelDia.claveDe(state.first.fecha)) {
      return;
    }
    state = ordenado;
    _prefs.setString(
      _clave,
      jsonEncode({
        for (final d in ordenado) TasaDelDia.claveDe(d.fecha): d.valor,
      }),
    );
  }
}

final historialTasaProvider =
    StateNotifierProvider<HistorialTasaNotifier, List<TasaDelDia>>((ref) {
  final notifier = HistorialTasaNotifier(ref.watch(sharedPreferencesProvider));

  // Cada vez que la tasa activa carga o cambia, se anota el valor del día.
  ref.listen<double?>(tasaActivaValorProvider, (_, valor) {
    if (valor != null) notifier.anotar(valor);
  }, fireImmediately: true);

  return notifier;
});

/// Hace cuántos días es el dato más reciente de la tasa activa. `null` si no
/// hay ninguno. Lo usa el Dashboard para avisar que la tasa está vencida.
final diasDesdeTasaProvider = Provider<int?>((ref) {
  final historial = ref.watch(historialTasaProvider);
  if (historial.isEmpty) return null;
  final hoy = DateTime.now();
  final ultima = historial.first.fecha;
  return DateTime(hoy.year, hoy.month, hoy.day)
      .difference(DateTime(ultima.year, ultima.month, ultima.day))
      .inDays;
});
