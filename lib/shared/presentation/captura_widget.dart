import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Convierte un widget ya pintado en un PNG guardado en disco.
///
/// Se usa para el catálogo y el Estado: en vez de dibujar sobre un `canvas`
/// como el prototipo, se compone el diseño con widgets normales dentro de un
/// [RepaintBoundary] y se captura. Así la imagen y la vista previa comparten
/// exactamente el mismo código.
abstract final class CapturaWidget {
  const CapturaWidget._();

  /// Captura el contenido de [clave] y devuelve el archivo PNG.
  ///
  /// [escala] multiplica la resolución: 3 sobre un lienzo de 360×640 da una
  /// imagen de 1080×1920, la que pide WhatsApp para los estados.
  static Future<File> aPng(
    GlobalKey clave, {
    double escala = 3,
    String nombre = 'cuenta-clara',
  }) async {
    final limite =
        clave.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (limite == null) {
      throw StateError('El widget a capturar todavía no está en pantalla.');
    }

    final imagen = await limite.toImage(pixelRatio: escala);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    if (datos == null) throw StateError('No se pudo codificar la imagen.');

    final bytes = datos.buffer.asUint8List(
      datos.offsetInBytes,
      datos.lengthInBytes,
    );
    return _guardar(bytes, nombre);
  }

  static Future<File> _guardar(Uint8List bytes, String nombre) async {
    final dir = await getTemporaryDirectory();
    // La marca de tiempo evita que WhatsApp reutilice una imagen cacheada.
    final marca = DateTime.now().millisecondsSinceEpoch;
    final archivo = File('${dir.path}/$nombre-$marca.png');
    await archivo.writeAsBytes(bytes);
    return archivo;
  }
}
