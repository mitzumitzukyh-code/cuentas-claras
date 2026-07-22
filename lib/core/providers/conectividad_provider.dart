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
