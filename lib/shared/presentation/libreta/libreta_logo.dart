import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_assets.dart';

/// Isotipo de marca: la libreta con el margen coral, la línea de tendencia
/// verde y el punto ámbar en la cima.
///
/// Es el SVG del paquete de identidad, no un `CustomPainter`: el logo es el
/// único dibujo de la app que también sale en la tienda, en el ícono y en el
/// gráfico de portada, y tenerlo repintado a mano garantizaba que tarde o
/// temprano se separaran.
///
/// La portada (`SplashScreen`) sigue con su propio painter porque ahí el
/// check se dibuja trazo a trazo, y eso un SVG estático no lo hace.
class LibretaLogo extends StatelessWidget {
  const LibretaLogo({super.key, this.size = 52, this.sobreOscuro = false});

  final double size;

  /// Sobre fondo oscuro el trazo del cuaderno va en crema y no en azul noche,
  /// que ahí se pierde contra el fondo.
  final bool sobreOscuro;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      sobreOscuro ? AppAssets.isotipoReverse : AppAssets.isotipo,
      width: size,
      height: size,
    );
  }
}
