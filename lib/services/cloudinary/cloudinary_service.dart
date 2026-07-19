import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Subida de imágenes a Cloudinary.
///
/// Se usa en lugar de Cloud Storage porque este requiere el plan Blaze de
/// Firebase (con tarjeta), y Cloudinary cubre de sobra el volumen de la app en
/// su capa gratuita.
///
/// La subida es **sin firma** (`unsigned`): la app solo conoce el nombre del
/// cloud y el preset, nunca la API Secret. El preset limita la carpeta de
/// destino, así que una filtración del preset no compromete el resto de la
/// cuenta.
class CloudinaryService {
  const CloudinaryService({this.cliente});

  /// Inyectable para poder falsearlo en tests.
  final http.Client? cliente;

  static const String cloudName = 'jwahaxid';
  static const String uploadPreset = 'cuenta_clara_productos';

  static Uri get _endpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Sube [archivo] y devuelve la URL https del recurso.
  ///
  /// [carpeta] permite separar productos de recibos o del logo del negocio.
  Future<String> subirImagen(File archivo, {String? carpeta}) async {
    final peticion = http.MultipartRequest('POST', _endpoint)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', archivo.path));

    if (carpeta != null) peticion.fields['folder'] = carpeta;

    final http.StreamedResponse respuesta;
    try {
      final c = cliente;
      respuesta = c == null
          ? await peticion.send()
          : await c.send(peticion);
    } on SocketException {
      throw const CloudinaryException('Sin conexión para subir la foto.');
    }

    final cuerpo = await respuesta.stream.bytesToString();

    if (respuesta.statusCode != 200) {
      // Cloudinary devuelve {"error":{"message":"..."}} en los fallos.
      String detalle = 'código ${respuesta.statusCode}';
      try {
        final json = jsonDecode(cuerpo) as Map<String, dynamic>;
        final error = json['error'] as Map<String, dynamic>?;
        if (error?['message'] is String) detalle = error!['message'] as String;
      } catch (_) {
        // Cuerpo no-JSON: nos quedamos con el código de estado.
      }
      throw CloudinaryException('No se pudo subir la foto ($detalle).');
    }

    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw const CloudinaryException('Cloudinary no devolvió la URL.');
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
  return const CloudinaryService();
});
