/// Rutas del paquete de marca (`assets/svg/`).
///
/// Generado por el paquete de identidad visual (ver
/// `herramientas/marca/README.md`). Si se regenera el paquete, se regenera
/// también esta lista — no se editan las rutas a mano.
///
/// Los tokens de color del paquete NO se copian aquí a propósito: la paleta de
/// la app vive en [AppColors] y [LibretaColors], y tener una tercera lista de
/// hex sería una fuente de verdad más que mantener sincronizada.
abstract final class AppAssets {
  const AppAssets._();

  static const _svg = 'assets/svg';

  // ── Marca ──────────────────────────────────────────────────────────────
  static const appIconAdaptiveBackground =
      '$_svg/marca/app-icon-adaptive-background.svg';
  static const appIconAdaptiveForeground =
      '$_svg/marca/app-icon-adaptive-foreground.svg';
  static const appIconCuadrado = '$_svg/marca/app-icon-cuadrado.svg';
  static const appIconMonochrome = '$_svg/marca/app-icon-monochrome.svg';
  static const appIcon = '$_svg/marca/app-icon.svg';
  static const isotipoMonoAzul = '$_svg/marca/isotipo-mono-azul.svg';
  static const isotipoMonoBlanco = '$_svg/marca/isotipo-mono-blanco.svg';
  static const isotipoReverse = '$_svg/marca/isotipo-reverse.svg';
  static const isotipo = '$_svg/marca/isotipo.svg';
  static const logoHorizontalReverse =
      '$_svg/marca/logo-horizontal-reverse.svg';
  static const logoHorizontalTagline =
      '$_svg/marca/logo-horizontal-tagline.svg';
  static const logoHorizontal = '$_svg/marca/logo-horizontal.svg';
  static const logoVerticalReverse = '$_svg/marca/logo-vertical-reverse.svg';
  static const logoVertical = '$_svg/marca/logo-vertical.svg';
  static const marcaSiluetaAzul = '$_svg/marca/marca-silueta-azul.svg';
  static const marcaSilueta = '$_svg/marca/marca-silueta.svg';
  static const planBasico = '$_svg/marca/plan-basico.svg';
  static const planPlus = '$_svg/marca/plan-plus.svg';
  static const playFeatureGraphic = '$_svg/marca/play-feature-graphic.svg';
  static const splash = '$_svg/marca/splash.svg';
  static const wordmarkReverse = '$_svg/marca/wordmark-reverse.svg';
  static const wordmark = '$_svg/marca/wordmark.svg';

  /// Isotipo blanco en PNG. Es el único bitmap del paquete que se empaqueta:
  /// la marca de agua del catálogo/estado se pinta dentro de un
  /// `RepaintBoundary` que se captura a imagen, y un SVG que todavía no
  /// terminó de decodificar saldría en blanco en la captura.
  static const isotipoMonoBlancoPng =
      'assets/png/2x/marca/isotipo-mono-blanco.png';

  // ── Íconos · navegación ────────────────────────────────────────────────
  static const navClientes = '$_svg/iconos/nav/clientes.svg';
  static const navInicio = '$_svg/iconos/nav/inicio.svg';
  static const navMas = '$_svg/iconos/nav/mas.svg';
  static const navProductos = '$_svg/iconos/nav/productos.svg';
  static const navReportes = '$_svg/iconos/nav/reportes.svg';
  static const navVentas = '$_svg/iconos/nav/ventas.svg';

  // ── Íconos · acciones ──────────────────────────────────────────────────
  static const accAgregar = '$_svg/iconos/acciones/agregar.svg';
  static const accAjustes = '$_svg/iconos/acciones/ajustes.svg';
  static const accAlerta = '$_svg/iconos/acciones/alerta.svg';
  static const accBuscar = '$_svg/iconos/acciones/buscar.svg';
  static const accCalendario = '$_svg/iconos/acciones/calendario.svg';
  static const accCamara = '$_svg/iconos/acciones/camara.svg';
  static const accCerrar = '$_svg/iconos/acciones/cerrar.svg';
  static const accCompartir = '$_svg/iconos/acciones/compartir.svg';
  static const accConfirmar = '$_svg/iconos/acciones/confirmar.svg';
  static const accEditar = '$_svg/iconos/acciones/editar.svg';
  static const accEfectivo = '$_svg/iconos/acciones/efectivo.svg';
  static const accEliminar = '$_svg/iconos/acciones/eliminar.svg';
  static const accEscanear = '$_svg/iconos/acciones/escanear.svg';
  static const accExportar = '$_svg/iconos/acciones/exportar.svg';
  static const accFiltrar = '$_svg/iconos/acciones/filtrar.svg';
  /// Cuadrícula con un "+" en la última celda. Ojo: no es un icono de
  /// mercancía — para producto/stock va [navProductos], el cubo, que es el
  /// mismo que la pestaña Mercancía y no se confunde con "agregar módulo".
  static const accInventario = '$_svg/iconos/acciones/inventario.svg';
  static const accMensaje = '$_svg/iconos/acciones/mensaje.svg';
  static const accPagoMovil = '$_svg/iconos/acciones/pago-movil.svg';
  static const accPendiente = '$_svg/iconos/acciones/pendiente.svg';

  // ── Íconos · categorías (rubro del negocio) ────────────────────────────
  static const catBelleza = '$_svg/iconos/categorias/belleza.svg';
  static const catBodega = '$_svg/iconos/categorias/bodega.svg';
  static const catComida = '$_svg/iconos/categorias/comida.svg';
  static const catFarmacia = '$_svg/iconos/categorias/farmacia.svg';
  static const catFerreteria = '$_svg/iconos/categorias/ferreteria.svg';
  static const catLicoreria = '$_svg/iconos/categorias/licoreria.svg';
  static const catOtros = '$_svg/iconos/categorias/otros.svg';
  static const catPanaderia = '$_svg/iconos/categorias/panaderia.svg';
  static const catRopa = '$_svg/iconos/categorias/ropa.svg';
  static const catServicios = '$_svg/iconos/categorias/servicios.svg';
  static const catTecnologia = '$_svg/iconos/categorias/tecnologia.svg';

  // ── Texturas ───────────────────────────────────────────────────────────
  static const texEspiralHorizontal = '$_svg/texturas/espiral-horizontal.svg';
  static const texHojaLibreta = '$_svg/texturas/hoja-libreta.svg';
  static const texLineasRayadas = '$_svg/texturas/lineas-rayadas.svg';
  static const texMargenCoral = '$_svg/texturas/margen-coral.svg';
  static const texPatronPuntos = '$_svg/texturas/patron-puntos.svg';

  // ── Ilustraciones (modo claro) ─────────────────────────────────────────
  static const ilusGuardadoOffline =
      '$_svg/ilustraciones/guardado-offline.svg';
  static const ilusListo = '$_svg/ilustraciones/listo.svg';
  static const ilusOnbBotWhatsapp =
      '$_svg/ilustraciones/onb-bot-whatsapp.svg';
  static const ilusOnbFiados = '$_svg/ilustraciones/onb-fiados.svg';
  static const ilusOnbInventario = '$_svg/ilustraciones/onb-inventario.svg';
  static const ilusOnbRegistrarVenta =
      '$_svg/ilustraciones/onb-registrar-venta.svg';
  static const ilusSinClientes = '$_svg/ilustraciones/sin-clientes.svg';
  static const ilusSinConexion = '$_svg/ilustraciones/sin-conexion.svg';
  static const ilusSinFiados = '$_svg/ilustraciones/sin-fiados.svg';
  static const ilusSinProductos = '$_svg/ilustraciones/sin-productos.svg';
  static const ilusSinReportes = '$_svg/ilustraciones/sin-reportes.svg';
  static const ilusSinResultados = '$_svg/ilustraciones/sin-resultados.svg';
  static const ilusSinVentas = '$_svg/ilustraciones/sin-ventas.svg';

  // ── Ilustraciones (modo oscuro) ────────────────────────────────────────
  static const ilusDarkGuardadoOffline =
      '$_svg/ilustraciones-dark/guardado-offline.svg';
  static const ilusDarkListo = '$_svg/ilustraciones-dark/listo.svg';
  static const ilusDarkOnbBotWhatsapp =
      '$_svg/ilustraciones-dark/onb-bot-whatsapp.svg';
  static const ilusDarkOnbFiados = '$_svg/ilustraciones-dark/onb-fiados.svg';
  static const ilusDarkOnbInventario =
      '$_svg/ilustraciones-dark/onb-inventario.svg';
  static const ilusDarkOnbRegistrarVenta =
      '$_svg/ilustraciones-dark/onb-registrar-venta.svg';
  static const ilusDarkSinClientes =
      '$_svg/ilustraciones-dark/sin-clientes.svg';
  static const ilusDarkSinConexion =
      '$_svg/ilustraciones-dark/sin-conexion.svg';
  static const ilusDarkSinFiados = '$_svg/ilustraciones-dark/sin-fiados.svg';
  static const ilusDarkSinProductos =
      '$_svg/ilustraciones-dark/sin-productos.svg';
  static const ilusDarkSinReportes =
      '$_svg/ilustraciones-dark/sin-reportes.svg';
  static const ilusDarkSinResultados =
      '$_svg/ilustraciones-dark/sin-resultados.svg';
  static const ilusDarkSinVentas = '$_svg/ilustraciones-dark/sin-ventas.svg';
}
