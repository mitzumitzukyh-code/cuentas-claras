import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/firebase_providers.dart';

const String _baseUrl = 'https://cuenta-clara-tasa.mitzumitzukyhs.workers.dev';

/// Subida de fotos (productos y recibos) a Cloudinary, vía el Worker.
///
/// Antes la app subía directo a Cloudinary con un preset "sin firma": el
/// nombre del cloud y el preset van embebidos en el APK como texto plano, así
/// que cualquiera que le hiciera ingeniería inversa podía mandar fotos a esa
/// cuenta sin tener sesión en Cuenta Clara siquiera. Ahora la subida pasa por
/// el mismo Worker que ya protege la clave de Gemini: exige sesión de
/// Firebase y firma cada subida con la API Secret de Cloudinary, que nunca
/// sale del servidor.
class CloudinaryService {
  CloudinaryService(this._auth, {http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _cliente;

  /// Sube [archivo] y devuelve la URL https del recurso.
  ///
  /// [carpeta] debe ser `cuenta-clara/{negocioId}/productos` o
  /// `.../recibos` — el Worker rechaza cualquier otra.
  Future<String> subirImagen(File archivo, {required String carpeta}) async {
    final usuario = _auth.currentUser;
    if (usuario == null) {
      throw const CloudinaryException('Sin sesión: no se puede subir la foto.');
    }
    final idToken = await usuario.getIdToken();

    final bytes = await archivo.readAsBytes();
    final extension = archivo.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final http.Response respuesta;
    try {
      respuesta = await _cliente
          .post(
            Uri.parse('$_baseUrl/subir-foto'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'imagenBase64': base64Encode(bytes),
              'mimeType': mimeType,
              'carpeta': carpeta,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const CloudinaryException('Sin conexión para subir la foto.');
    }

    if (respuesta.statusCode != 200) {
      throw CloudinaryException(
        'No se pudo subir la foto (código ${respuesta.statusCode}).',
      );
    }

    final json = jsonDecode(respuesta.body) as Map<String, dynamic>;
    final url = json['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const CloudinaryException('El servidor no devolvió la URL.');
    }
    return url;
  }
}

/// Fallo al subir una imagen, con un mensaje ya legible para el usuario.
class CloudinaryException implements Exception {
  const CloudinaryException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService(ref.watch(firebaseAuthProvider));
});
