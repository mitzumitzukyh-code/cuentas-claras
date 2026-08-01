import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_assets.dart';
import 'libreta_tokens.dart';

/// Ícono del paquete de marca (`assets/svg/iconos/**`).
///
/// Los SVG del paquete traen `stroke="currentColor"`, que `flutter_svg` no
/// interpreta: sin un `ColorFilter` salen en negro. Este widget aplica el
/// filtro siempre, con el mismo criterio que un [Icon] de Material — hereda
/// el color del [IconTheme] cuando no se le pasa uno.
///
/// Es intercambiable con [Icon] en la práctica: mismo tamaño por defecto y
/// mismo comportamiento de color, así que sustituir uno por otro en una fila
/// no mueve el layout.
class LibretaIcono extends StatelessWidget {
  const LibretaIcono(this.asset, {super.key, this.size = 24, this.color});

  /// Ruta del SVG — siempre una constante de `AppAssets`.
  final String asset;

  final double size;

  /// Si es nulo se toma del [IconTheme] y, en última instancia, del texto
  /// fuerte del tema.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? context.libreta.textoFuerte;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

/// Ilustraciones del paquete de marca, con su par claro/oscuro resuelto.
///
/// Existe como enum y no como dos rutas sueltas para que ninguna pantalla
/// pueda quedarse a medias — con la versión clara puesta y la oscura no.
enum Ilustracion {
  sinVentas(AppAssets.ilusSinVentas, AppAssets.ilusDarkSinVentas),
  sinProductos(AppAssets.ilusSinProductos, AppAssets.ilusDarkSinProductos),
  sinClientes(AppAssets.ilusSinClientes, AppAssets.ilusDarkSinClientes),
  sinFiados(AppAssets.ilusSinFiados, AppAssets.ilusDarkSinFiados),
  sinReportes(AppAssets.ilusSinReportes, AppAssets.ilusDarkSinReportes),
  sinResultados(AppAssets.ilusSinResultados, AppAssets.ilusDarkSinResultados),
  sinConexion(AppAssets.ilusSinConexion, AppAssets.ilusDarkSinConexion),
  guardadoOffline(
    AppAssets.ilusGuardadoOffline,
    AppAssets.ilusDarkGuardadoOffline,
  ),
  listo(AppAssets.ilusListo, AppAssets.ilusDarkListo),
  onbRegistrarVenta(
    AppAssets.ilusOnbRegistrarVenta,
    AppAssets.ilusDarkOnbRegistrarVenta,
  ),
  onbInventario(AppAssets.ilusOnbInventario, AppAssets.ilusDarkOnbInventario),
  onbFiados(AppAssets.ilusOnbFiados, AppAssets.ilusDarkOnbFiados),
  onbBotWhatsapp(
    AppAssets.ilusOnbBotWhatsapp,
    AppAssets.ilusDarkOnbBotWhatsapp,
  );

  const Ilustracion(this.claro, this.oscuro);

  final String claro;
  final String oscuro;
}

/// Ilustración del paquete de marca (`assets/svg/ilustraciones/**`).
///
/// A diferencia de [LibretaIcono] va a color fijo, sin filtro. Elige sola la
/// variante clara u oscura según el brillo del tema: las dos versiones del
/// mismo dibujo existen justamente porque el papel crema del modo claro
/// desaparece sobre el fondo oscuro.
class LibretaIlustracion extends StatelessWidget {
  const LibretaIlustracion(this.ilustracion, {super.key, this.size = 150});

  final Ilustracion ilustracion;
  final double size;

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      esOscuro ? ilustracion.oscuro : ilustracion.claro,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
