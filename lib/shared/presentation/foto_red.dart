import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de red con caché en disco, para fotos de productos y de perfil.
///
/// `Image.network` no guarda nada: al perder internet todas las fotos
/// desaparecían de la app. `CachedNetworkImage` las guarda en el teléfono la
/// primera vez que se ven, así que sin conexión se siguen mostrando desde el
/// caché. Solo si la foto nunca se llegó a descargar se muestra [alError].
class FotoRed extends StatelessWidget {
  const FotoRed(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.alError,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Qué mostrar si la imagen no está en caché y no se pudo descargar
  /// (típicamente la inicial del nombre o un emoji).
  final Widget alError;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: const Color(0x1E1E2A38),
      ),
      errorWidget: (_, __, ___) => Center(child: alError),
    );
  }
}
