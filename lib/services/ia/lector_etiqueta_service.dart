import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/firebase_providers.dart';

const String _endpoint =
    'https://cuenta-clara-tasa.mitzumitzukyhs.workers.dev/leer-etiqueta';

/// Sugerencia de nombre que la IA extrajo de la foto de un producto.
class SugerenciaEtiqueta {
  const SugerenciaEtiqueta({required this.nombre, required this.confianza});

  final String nombre;

  /// `alta` | `media` | `baja`. Se usa para avisar cuando conviene revisar
  /// bien antes de aceptar la sugerencia, nunca para bloquearla.
  final String confianza;
}

/// No se reconoció ningún producto en la foto (borrosa, no es un producto).
class SinReconocer implements Exception {}

/// Lee la foto de un producto y sugiere un nombre para el inventario.
///
/// La sugerencia NUNCA se guarda sola: solo rellena el campo de nombre para
/// que el dueño la revise y confirme al guardar, igual que si la hubiera
/// tecleado él mismo. Un modelo de visión se equivoca con etiquetas
/// borrosas, en mal ángulo o en productos poco comunes, y un inventario con
/// nombres inventados es peor que uno vacío.
class LectorEtiquetaService {
  LectorEtiquetaService(this._auth, {http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _cliente;

  Future<SugerenciaEtiqueta> leer(File foto) async {
    final usuario = _auth.currentUser;
    if (usuario == null) {
      throw StateError('Sin sesión: no se puede pedir la lectura con IA.');
    }
    final idToken = await usuario.getIdToken();

    final bytes = await foto.readAsBytes();
    final extension = foto.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final respuesta = await _cliente
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'imagenBase64': base64Encode(bytes),
            'mimeType': mimeType,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo leer la etiqueta (código ${respuesta.statusCode}).',
      );
    }

    final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
    if (datos['reconocido'] != true) throw SinReconocer();

    return SugerenciaEtiqueta(
      nombre: datos['nombreSugerido'] as String,
      confianza: datos['confianza'] as String? ?? 'media',
    );
  }
}

final lectorEtiquetaServiceProvider = Provider<LectorEtiquetaService>((ref) {
  return LectorEtiquetaService(ref.watch(firebaseAuthProvider));
});
