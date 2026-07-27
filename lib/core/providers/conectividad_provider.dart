import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `true` mientras el teléfono tenga alguna red (WiFi, datos, etc.).
///
/// Ojo: "tener red" no garantiza internet real (un WiFi sin saldo cuenta como
/// conectado), pero cubre el caso común de quedarse sin señal en el local.
final hayConexionProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();

  bool conectado(List<ConnectivityResult> estados) =>
      estados.any((r) => r != ConnectivityResult.none);

  yield conectado(await connectivity.checkConnectivity());
  await for (final estados in connectivity.onConnectivityChanged) {
    yield conectado(estados);
  }
});

/// Helper para repositorios: chequeo único (no reactivo) de si hay red.
/// Evita duplicar la misma lógica en [GastoRepository], [ProductoRepository], etc.
Future<bool> sinSenal() async {
  final estado = await Connectivity().checkConnectivity();
  return estado.isEmpty ||
      estado.every((r) => r == ConnectivityResult.none);
}
