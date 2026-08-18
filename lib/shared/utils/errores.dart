import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Traduce cualquier excepción a una frase que un bodeguero entienda.
///
/// El detalle técnico va a la consola y **nunca** a la pantalla. Un dueño que
/// lee «ClientException with SocketException: Failed host lookup:
/// 'cuenta-clara-tasa.mitzumitzukyhs.workers.dev'» no aprende nada de eso:
/// aprende que la app se rompió, y cierra.
///
/// [accion] es lo que se estaba intentando, en infinitivo y sin mayúscula
/// inicial: 'guardar', 'cargar tus gastos', 'subir la foto'. Se usa para
/// abrir la frase.
String mensajeDeError(Object? e, {String accion = 'completar la acción'}) {
  debugPrint('[error] $accion → $e');

  final detalle = e.toString().toLowerCase();

  // --- Tardó demasiado ---
  //
  // Separado de "sin red" porque no es lo mismo, y confundirlos se vio en
  // dispositivo: una lectura con IA que se pasó del límite mostraba «revisa tu
  // internet» con el wifi perfecto, y el dueño se puso a reiniciar el router.
  // Un tiempo agotado casi siempre es que la otra punta va lenta.
  if (e is TimeoutException) {
    return 'Tardamos demasiado al $accion. Intenta de nuevo en un momento.';
  }

  // --- Sin internet, DNS caído, servidor inalcanzable ---
  final sinRed = e is SocketException ||
      detalle.contains('socketexception') ||
      detalle.contains('failed host lookup') ||
      detalle.contains('connection closed') ||
      detalle.contains('network') ||
      (e is FirebaseException && e.code == 'unavailable');
  if (sinRed) {
    return 'No pudimos conectar para $accion. Revisa tu internet e intenta '
        'de nuevo.';
  }

  // --- Permisos: no es un fallo, es que no le toca ---
  if (e is FirebaseException && e.code == 'permission-denied') {
    return 'No tienes permiso para $accion. Pídeselo al dueño del negocio.';
  }

  return 'No pudimos $accion. Intenta de nuevo.';
}

/// Reintenta una operación de red con esperas crecientes.
///
/// Tres intentos por defecto (1 s, 2 s, 4 s): en una conexión venezolana un
/// fallo suele ser un bache de segundos, no una caída, y hacer que el dueño
/// vuelva a tomar la foto por eso es perderle el trabajo.
///
/// Solo reintenta lo que puede mejorar esperando. Un permiso denegado o un
/// archivo inválido fallan igual las tres veces, así que se propagan de una.
Future<T> conReintentos<T>(
  Future<T> Function() operacion, {
  int intentos = 3,
  Duration esperaInicial = const Duration(seconds: 1),
}) async {
  var espera = esperaInicial;
  for (var i = 1; ; i++) {
    try {
      return await operacion();
    } catch (e) {
      final ultimo = i >= intentos;
      if (ultimo || !_valeReintentar(e)) rethrow;
      debugPrint('[error] intento $i falló ($e); reintento en ${espera.inSeconds}s');
      await Future<void>.delayed(espera);
      espera *= 2;
    }
  }
}

bool _valeReintentar(Object e) {
  if (e is SocketException || e is TimeoutException) return true;
  if (e is FirebaseException) return e.code == 'unavailable';
  final d = e.toString().toLowerCase();
  return d.contains('socketexception') ||
      d.contains('failed host lookup') ||
      d.contains('connection closed') ||
      d.contains('clientexception');
}
