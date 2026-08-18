import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/captura_widget.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/estado_carga.dart';
import '../../../shared/utils/errores.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../planes/data/plan_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../../ventas/domain/venta.dart';
import '../domain/seleccion_catalogo.dart';

/// Catálogo: la ventana desde la que se arma lo que se manda por WhatsApp.
///
/// **No es una vitrina, es una ventana de redacción.** Nadie abre esta
/// pantalla a contemplar su catálogo: la abre para mandarlo. Por eso todo se
/// ordena alrededor de lo que va a salir — se eligen productos y el pie dice
/// en todo momento qué se va a compartir («11 productos · $1,20 a $8,00»),
/// con un único botón. Antes había dos botones compitiendo abajo, y obligaban
/// a decidir el formato antes que el contenido; el formato se pregunta ahora
/// al final, en una hoja: texto, imagen o Estado.
///
/// **La imagen se puede ver antes de mandarla.** El lienzo se pinta fuera de
/// la pantalla porque hay que tenerlo montado para capturarlo, y durante un
/// tiempo eso significó que el dueño compartía a ciegas algo que nunca había
/// visto. «Vista previa» enseña exactamente el PNG que va a salir, con su
/// marca de agua si el plan la lleva (CLAUDE.md §6).
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  final Set<String> _elegidos = {};
  final _lienzo = GlobalKey();
  final _buscador = TextEditingController();

  String? _categoria;
  String _busqueda = '';

  /// Rango de precio elegido, o `null` si no se ha filtrado. Los extremos
  /// salen del propio catálogo (ver [_rangoDe]): un filtro de $0 a $1.000 en
  /// una bodega donde nada pasa de $8 no filtra nada.
  RangeValues? _rangoPrecio;

  bool _generando = false;
  bool _sembrado = false;

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  bool _pasaFiltros(Producto p) => pasaFiltros(
        p,
        categoria: _categoria,
        busqueda: _busqueda,
        rango: _rangoPrecio,
      );

  /// Al entrar, todo viene marcado: es lo que casi siempre se quiere compartir.
  void _sembrar(List<Producto> productos) {
    if (_sembrado) return;
    _sembrado = true;
    _elegidos.addAll(productos.map((p) => p.id));
  }

  List<Producto> _seleccionados(List<Producto> todos) =>
      todos.where((p) => _elegidos.contains(p.id)).toList();

  Future<void> _compartirTexto(
    List<Producto> productos,
    Negocio negocio,
    double? tasa,
  ) async {
    final elegidos = _seleccionados(productos);
    if (elegidos.isEmpty) {
      _mostrar('Elige al menos un producto.');
      return;
    }

    final lineas = elegidos.map((p) {
      final bs = tasa == null
          ? ''
          : ' (${MoneyFormatter.usdComoBs(p.precio!, tasa)})';
      return '• ${p.nombre} — ${MoneyFormatter.usd(p.precio!)}$bs';
    }).join('\n');

    final metodos = negocio.metodosActivos.map((m) => m.resumen).join('\n');

    final texto = StringBuffer()
      ..writeln('*${negocio.nombre}*')
      ..writeln()
      ..writeln(lineas);
    if (metodos.isNotEmpty) {
      texto
        ..writeln()
        ..writeln('*Formas de pago:*')
        ..writeln(metodos);
    }
    if (tasa != null) {
      texto
        ..writeln()
        ..writeln('Tasa BCV: ${MoneyFormatter.bs(tasa)}');
    }
    texto
      ..writeln()
      ..writeln('Hecho con Cuenta Clara');

    await Share.share(texto.toString(), subject: 'Catálogo ${negocio.nombre}');
  }

  Future<void> _compartirImagen(String nombreNegocio, List<Producto> elegidos) async {
    setState(() => _generando = true);
    try {
      // Sin esto, si una foto todavía no había terminado de descargarse
      // cuando se tocó "Compartir", la captura la congelaba a medio cargar
      // (el ícono genérico en vez de la foto real).
      await Future.wait([
        for (final p in elegidos)
          if (p.fotoUrl != null && p.fotoUrl!.isNotEmpty)
            precacheImage(CachedNetworkImageProvider(p.fotoUrl!), context),
      ]);
      if (!mounted) return;

      final archivo = await CapturaWidget.aPng(
        _lienzo,
        escala: 2.5,
        nombre: 'catalogo',
      );
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: 'Catálogo de $nombreNegocio\nHecho con Cuenta Clara',
      );
    } catch (e) {
      _mostrar(mensajeDeError(e, accion: 'generar la imagen'));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  /// Pregunta el FORMATO, ya con el contenido decidido.
  ///
  /// Es el orden correcto de las dos decisiones: qué mando primero, y por
  /// dónde después. Con dos botones fijos abajo, la pantalla obligaba a
  /// elegir el canal antes de haber terminado de marcar productos.
  Future<void> _abrirHojaCompartir(
    List<Producto> productos,
    Negocio negocio,
    double? tasa,
  ) async {
    final elegidos = _seleccionados(productos);
    if (elegidos.isEmpty) return;

    final forma = await showModalBottomSheet<_FormaCompartir>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaCompartir(cuantos: elegidos.length),
    );
    if (forma == null || !mounted) return;

    switch (forma) {
      case _FormaCompartir.texto:
        await _compartirTexto(productos, negocio, tasa);
      case _FormaCompartir.imagen:
        await _compartirImagen(negocio.nombre, elegidos);
      case _FormaCompartir.estado:
        if (mounted) context.push(Routes.estadoWhatsApp);
    }
  }

  /// Filtro de precio, con los topes sacados del propio catálogo.
  Future<void> _abrirFiltroPrecio(List<Producto> productos) async {
    final topes = rangoDePrecios(productos);
    final (min, max) = topes;
    final elegido = await showModalBottomSheet<RangeValues?>(
      context: context,
      backgroundColor: Colors.transparent,
      // `isDismissible` deja salir sin tocar nada; quien sale sin elegir no
      // quiere borrar el filtro que ya tenía, así que eso lo distingue el
      // `null` de la hoja del `RangeValues` vacío que manda "quitar".
      builder: (_) => _HojaPrecio(
        min: min,
        max: max,
        inicial: _rangoPrecio ?? RangeValues(min, max),
      ),
    );
    if (elegido == null || !mounted) return;
    setState(() {
      _rangoPrecio = filtraAlgo(elegido, topes) ? elegido : null;
    });
  }

  /// Enseña el PNG que se va a compartir, tal cual va a salir.
  void _abrirVistaPrevia(Negocio negocio, List<Producto> elegidos, double? tasa) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VistaPrevia(
        negocio: negocio,
        productos: elegidos,
        tasa: tasa,
        conMarcaDeAgua: ref.read(planDelNegocioProvider).marcaDeAgua,
      ),
    );
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    // Sin precio no entra al catálogo: una lista de precios con renglones sin
    // cifra no sirve para lo que se manda, y el cliente pregunta igual.
    final productos = (ref.watch(productosProvider).valueOrNull ?? const [])
        .where((p) => p.sePuedeVender)
        .toList();
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    if (negocio == null) {
      // Antes era un spinner sin fin: con un fallo de carga el negocio nunca
      // llega, y la pantalla giraba para siempre sin error ni salida.
      final negocioAsync = ref.watch(negocioActivoProvider);
      return Scaffold(
        backgroundColor: context.libreta.papel,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: negocioAsync.hasError
                  ? LibretaErrorCarga(
                      mensaje: mensajeDeError(
                        negocioAsync.error,
                        accion: 'cargar tu negocio',
                      ),
                      detalleTecnico: negocioAsync.error,
                      onReintentar: () =>
                          ref.invalidate(negocioActivoProvider),
                    )
                  : const LibretaCargando(),
            ),
          ),
        ),
      );
    }
    _sembrar(productos);

    final categorias = <String>{
      for (final p in productos)
        if (p.categoria.isNotEmpty) p.categoria,
    }.toList()
      ..sort();
    final visibles = productos.where(_pasaFiltros).toList();

    final elegidos = _seleccionados(productos);
    final todosMarcados =
        productos.isNotEmpty && _elegidos.length == productos.length;

    return Scaffold(
      backgroundColor: context.libreta.superficie,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: LibretaColors.degradadoAuth,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              negocio.nombre.isEmpty
                                  ? '?'
                                  : negocio.nombre[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  negocio.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: context.libreta.textoFuerte,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Catálogo · ${productos.length} productos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: context.libreta.textoMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          LibretaBackButton(
                            oscuro: true,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (productos.isNotEmpty)
                        LibretaInput(
                          controller: _buscador,
                          hint: 'Buscar producto',
                          height: 44,
                          leading: Icon(
                            Icons.search,
                            size: 19,
                            color: context.libreta.textoMuted,
                          ),
                          suffix: _busqueda.isEmpty
                              ? null
                              : GestureDetector(
                                  onTap: () {
                                    _buscador.clear();
                                    setState(() => _busqueda = '');
                                  },
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: context.libreta.textoMuted,
                                  ),
                                ),
                          onChanged: (v) => setState(() => _busqueda = v),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${elegidos.length} de ${productos.length} '
                              'marcados',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() {
                              if (todosMarcados) {
                                _elegidos.clear();
                              } else {
                                _elegidos.addAll(productos.map((p) => p.id));
                              }
                            }),
                            child: Text(
                              todosMarcados ? 'Quitar todos' : 'Marcar todos',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: LibretaColors.verde,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (productos.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        // La cuenta va en el propio chip: con el catálogo
                        // filtrado, saber cuántos hay detrás de cada categoría
                        // evita tocarlas una por una para descubrir que están
                        // vacías.
                        LibretaChip(
                          label: 'Todos ${productos.length}',
                          selected: _categoria == null,
                          onTap: () => setState(() => _categoria = null),
                        ),
                        for (final c in categorias)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: LibretaChip(
                              label: '$c '
                                  '${productos.where((p) => p.categoria == c).length}',
                              selected: _categoria == c,
                              onTap: () => setState(() => _categoria = c),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: LibretaChip(
                            label: _rangoPrecio == null
                                ? 'Precio'
                                : '${MoneyFormatter.usd(_rangoPrecio!.start)}'
                                    ' – ${MoneyFormatter.usd(_rangoPrecio!.end)}',
                            selected: _rangoPrecio != null,
                            onTap: () => _abrirFiltroPrecio(productos),
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(height: 1, color: context.libreta.renglon),
                Expanded(
                  child: productos.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                          child: LibretaEstadoVacio(
                            ilustracion: Ilustracion.sinProductos,
                            titulo: 'Todavía no hay nada que mostrar',
                            detalle:
                                'Agrega productos a tu inventario para armar '
                                'un catálogo y compartirlo.',
                            tagline: 'tu vitrina está esperando',
                            boton: LibretaButton(
                              label: 'Agregar producto',
                              icon: const Icon(
                                Icons.add,
                                size: 19,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  context.push(Routes.nuevoProducto),
                            ),
                          ),
                        )
                      : visibles.isEmpty
                          ? _SinResultados(
                              onQuitarFiltros: () => setState(() {
                                _categoria = null;
                                _rangoPrecio = null;
                                _busqueda = '';
                                _buscador.clear();
                              }),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.80,
                              ),
                              itemCount: visibles.length,
                              itemBuilder: (_, i) => _TarjetaCatalogo(
                                producto: visibles[i],
                                marcado: _elegidos.contains(visibles[i].id),
                                onTap: () => setState(() {
                                  if (!_elegidos.remove(visibles[i].id)) {
                                    _elegidos.add(visibles[i].id);
                                  }
                                }),
                              ),
                            ),
                ),
                if (productos.isNotEmpty)
                  _BarraEnvio(
                    elegidos: elegidos,
                    generando: _generando,
                    onVistaPrevia: elegidos.isEmpty
                        ? null
                        : () => _abrirVistaPrevia(negocio, elegidos, tasa),
                    onCompartir: elegidos.isEmpty || _generando
                        ? null
                        : () => _abrirHojaCompartir(productos, negocio, tasa),
                  ),
              ],
            ),
          ),

          // El lienzo se pinta fuera de la pantalla: hay que tenerlo montado
          // para poder capturarlo, pero no debe verse.
          Positioned(
            left: -2000,
            child: RepaintBoundary(
              key: _lienzo,
              child: _LienzoCatalogo(
                negocio: negocio,
                productos: elegidos,
                tasa: tasa,
                conMarcaDeAgua: ref.watch(planDelNegocioProvider).marcaDeAgua,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de producto de la grilla: foto, casilla, nombre, existencias y
/// precio.
///
/// Tres decisiones que se ven aquí:
///
/// - **La casilla es un cuadrado arriba a la IZQUIERDA.** Un círculo verde
///   arriba a la derecha se lee como una insignia de «nuevo» o de oferta, no
///   como algo que se puede desmarcar. El cuadrado a la izquierda es la
///   convención de selección de cualquier galería de fotos.
/// - **Lo no marcado se atenúa**, además de perder el check. Con doce
///   productos y sol de mediodía, la ausencia de un check no se ve; la
///   diferencia de luminosidad sí.
/// - **El precio lo pinta [LibretaMonto]**, que respeta la moneda que el
///   negocio eligió en el onboarding y la tasa activa. Escribir «$ arriba, Bs
///   debajo» a mano le imponía dólares a una bodega que trabaja en bolívares.
class _TarjetaCatalogo extends StatelessWidget {
  const _TarjetaCatalogo({
    required this.producto,
    required this.marcado,
    required this.onTap,
  });

  final Producto producto;
  final bool marcado;
  final VoidCallback onTap;

  static const _degradados = [
    [Color(0xFFF4EFE4), Color(0xFFE7DCC6)],
    [Color(0xFFE6F0EC), Color(0xFFCFE3DA)],
    [Color(0xFFF4ECDC), Color(0xFFECD9B3)],
    [Color(0xFFEFEAF2), Color(0xFFDDD0E6)],
    [Color(0xFFF3ECE6), Color(0xFFE3D0C2)],
  ];

  @override
  Widget build(BuildContext context) {
    final colores = _degradados[producto.nombre.hashCode.abs() % _degradados.length];
    final t = context.libreta;

    return Semantics(
      button: true,
      selected: marcado,
      label: '${producto.nombre}, ${MoneyFormatter.usd(producto.precio!)}',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: marcado ? 1 : 0.55,
        child: Container(
        decoration: BoxDecoration(
          color: context.libreta.superficie,
          border: Border.all(
            color: marcado ? LibretaColors.verde : const Color(0x141E2A38),
            width: marcado ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty
                        ? FotoRed(
                            producto.fotoUrl!,
                            alError: const LibretaIcono(AppAssets.navProductos,
                              color: Color(0x66000000),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: colores,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const LibretaIcono(AppAssets.navProductos,
                              size: 30,
                              color: Color(0x66000000),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: marcado ? LibretaColors.verde : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: marcado ? LibretaColors.verde : context.libreta.bordeSuave,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: marcado
                          ? const LibretaIcono(AppAssets.accConfirmar, size: 15, color: Colors.white)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: t.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LibretaMonto(
                    usd: producto.precio!,
                    maxLines: 1,
                    estiloPrincipal: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                    ),
                    estiloSecundario: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: t.textoMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Ofrecer lo que ya no tienes es peor que no ofrecerlo: el
                  // cliente lo pide y hay que decirle que no.
                  Text(
                    'quedan ${producto.cantidadLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: producto.stockBajo
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: producto.stockBajo
                          ? LibretaColors.aviso
                          : t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );
  }
}

/// Cómo se comparte lo que se eligió.
enum _FormaCompartir { texto, imagen, estado }

/// Barra oscura del pie: qué se va a mandar, y un solo botón.
///
/// El resumen no es un contador de casillas —«12 seleccionados» no dice
/// nada—, es la descripción del mensaje: cuántos productos y entre qué
/// precios. Es lo último que el dueño lee antes de mandarle algo a un
/// cliente.
class _BarraEnvio extends StatelessWidget {
  const _BarraEnvio({
    required this.elegidos,
    required this.generando,
    required this.onVistaPrevia,
    required this.onCompartir,
  });

  final List<Producto> elegidos;
  final bool generando;
  final VoidCallback? onVistaPrevia;
  final VoidCallback? onCompartir;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LibretaColors.tarjetaOscura,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  resumenSeleccion(elegidos),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onVistaPrevia != null)
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: onVistaPrevia,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'Vista previa',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9FE1CB),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LibretaButton(
            label: generando ? 'Generando…' : 'Compartir',
            loading: generando,
            icon: generando
                ? null
                : const Icon(Icons.ios_share, size: 18, color: Colors.white),
            onPressed: onCompartir,
          ),
        ],
      ),
    );
  }
}

/// Hoja donde se elige el formato, ya con el contenido decidido.
class _HojaCompartir extends StatelessWidget {
  const _HojaCompartir({required this.cuantos});

  final int cuantos;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                'Compartir $cuantos ${cuantos == 1 ? "producto" : "productos"}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.textoFuerte,
                ),
              ),
            ),
            _OpcionCompartir(
              icono: Icons.chat_outlined,
              titulo: 'Como texto',
              detalle: 'Lista de precios y formas de pago',
              onTap: () => Navigator.of(context).pop(_FormaCompartir.texto),
            ),
            _OpcionCompartir(
              icono: Icons.image_outlined,
              titulo: 'Como imagen',
              detalle: 'Una tarjeta con hasta 6 productos',
              onTap: () => Navigator.of(context).pop(_FormaCompartir.imagen),
            ),
            _OpcionCompartir(
              icono: Icons.auto_stories_outlined,
              titulo: 'Publicar en Estado',
              detalle: 'Formato vertical para WhatsApp',
              onTap: () => Navigator.of(context).pop(_FormaCompartir.estado),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionCompartir extends StatelessWidget {
  const _OpcionCompartir({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: LibretaColors.verde.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(icono, size: 20, color: LibretaColors.verde),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: t.textoFuerte,
        ),
      ),
      subtitle: Text(
        detalle,
        style: TextStyle(fontSize: 12.5, color: t.textoMuted),
      ),
      onTap: onTap,
    );
  }
}

/// Filtro de precio. Los topes salen del catálogo, no de una escala inventada.
class _HojaPrecio extends StatefulWidget {
  const _HojaPrecio({
    required this.min,
    required this.max,
    required this.inicial,
  });

  final double min;
  final double max;
  final RangeValues inicial;

  @override
  State<_HojaPrecio> createState() => _HojaPrecioState();
}

class _HojaPrecioState extends State<_HojaPrecio> {
  late RangeValues _valores = widget.inicial;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mostrar productos entre',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${MoneyFormatter.usd(_valores.start)} y '
              '${MoneyFormatter.usd(_valores.end)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: LibretaColors.verde,
              ),
            ),
            RangeSlider(
              values: _valores,
              min: widget.min,
              max: widget.max,
              activeColor: LibretaColors.verde,
              labels: RangeLabels(
                MoneyFormatter.usd(_valores.start),
                MoneyFormatter.usd(_valores.end),
              ),
              onChanged: (v) => setState(() => _valores = v),
            ),
            Row(
              children: [
                Expanded(
                  child: LibretaSecondaryButton(
                    label: 'Quitar filtro',
                    onPressed: () => Navigator.of(context).pop(
                      RangeValues(widget.min, widget.max),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LibretaButton(
                    label: 'Aplicar',
                    onPressed: () => Navigator.of(context).pop(_valores),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// La imagen que se va a compartir, a tamaño de pantalla.
///
/// Es el mismo widget que se captura a PNG, no una aproximación: lo que se ve
/// aquí es lo que le llega al cliente, marca de agua incluida.
class _VistaPrevia extends StatelessWidget {
  const _VistaPrevia({
    required this.negocio,
    required this.productos,
    required this.tasa,
    required this.conMarcaDeAgua,
  });

  final Negocio negocio;
  final List<Producto> productos;
  final double? tasa;
  final bool conMarcaDeAgua;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final sobran = productos.length - _LienzoCatalogo._destacados;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Así lo verá tu cliente',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20),
                  ),
                ),
              ],
            ),
            if (sobran > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'La imagen muestra 6 productos; los otros $sobran van '
                  'nombrados al pie.',
                  style: TextStyle(fontSize: 12.5, color: t.textoMuted),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Center(
                  child: _LienzoCatalogo(
                    negocio: negocio,
                    productos: productos,
                    tasa: tasa,
                    conMarcaDeAgua: conMarcaDeAgua,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuando los filtros no dejan nada a la vista.
///
/// Distinto del catálogo vacío de verdad: aquí sí hay productos, y lo que hace
/// falta es una salida, no una invitación a crear el primero.
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.onQuitarFiltros});

  final VoidCallback onQuitarFiltros;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 34, color: t.textoMuted),
            const SizedBox(height: 12),
            Text(
              'Ningún producto encaja con lo que buscas',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 12),
            LibretaSecondaryButton(
              label: 'Quitar filtros',
              onPressed: onQuitarFiltros,
            ),
          ],
        ),
      ),
    );
  }
}

/// Diseño de la imagen que se comparte. Formato apaisado tipo folleto.
/// La imagen que se comparte por WhatsApp — réplica exacta de la tarjeta que
/// muestra `P3 · CATÁLOGO EN WHATSAPP`: header verde, grilla de 2 columnas,
/// formas de pago activas y pie con la marca (CLAUDE.md §6: con marca de
/// agua en el plan gratis).
class _LienzoCatalogo extends StatelessWidget {
  const _LienzoCatalogo({
    required this.negocio,
    required this.productos,
    required this.tasa,
    required this.conMarcaDeAgua,
  });

  final Negocio negocio;
  final List<Producto> productos;
  final double? tasa;

  /// Si el pie con «Hecho con Cuenta Clara» va en la imagen. Lo decide el plan
  /// del dueño del negocio (CLAUDE.md §6): en gratis va, en Plan Plus no.
  final bool conMarcaDeAgua;

  static const _destacados = 6;

  @override
  Widget build(BuildContext context) {
    final visibles = productos.take(_destacados).toList();
    final metodos = negocio.metodosActivos;

    // Se pinta en claro siempre: una imagen oscura queda mal en WhatsApp.
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Header verde ---
          Container(
            color: AppColors.marca,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    negocio.nombre.isEmpty ? '?' : negocio.nombre[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '${negocio.nombre} · precios de hoy',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Grilla de productos ---
          Padding(
            padding: const EdgeInsets.all(10),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
              childAspectRatio: 1.35,
              children: [
                for (final p in visibles)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF8F3),
                      border: Border.all(color: const Color(0x121E2A38)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            color: const Color(0xFFF0EAD9),
                            alignment: Alignment.center,
                            child: p.fotoUrl != null && p.fotoUrl!.isNotEmpty
                                ? FotoRed(
                                    p.fotoUrl!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    alError: const LibretaIcono(AppAssets.navProductos,
                                      size: 22,
                                      color: Color(0x66000000),
                                    ),
                                  )
                                : const LibretaIcono(AppAssets.navProductos,
                                    size: 22,
                                    color: Color(0x66000000),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(7, 5, 7, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E2A38),
                                ),
                              ),
                              LibretaMonto(
                                usd: p.precio!,
                                estiloPrincipal: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.marca,
                                ),
                                estiloSecundario: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: LibretaColors.textoMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (productos.length > _destacados)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Text(
                'y ${productos.length - _destacados} productos más · '
                'precios en Bs a la tasa del día',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF54656F),
                ),
              ),
            ),

          if (metodos.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0x171E2A38)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FORMAS DE PAGO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Color(0xFF8A9A96),
                    ),
                  ),
                  const SizedBox(height: 7),
                  for (final m in metodos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0x1F0E9F6E),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _iconoMetodo(m.metodo),
                              size: 14,
                              color: AppColors.marca,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              m.resumen,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E2A38),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // --- Pie con la marca (CLAUDE.md §6: marca de agua en gratis) ---
          if (conMarcaDeAgua)
          Container(
            color: LibretaColors.tarjetaOscura,
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Isotipo monocromo en PNG, no el SVG: esta fila se pinta
                // dentro de un RepaintBoundary que se captura a imagen para
                // compartir, y un SVG a medio decodificar saldría en blanco.
                Image.asset(
                  AppAssets.isotipoMonoBlancoPng,
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 7),
                const Text(
                  'HECHO CON CUENTA CLARA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xEBFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconoMetodo(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => Icons.payments_outlined,
        MetodoPago.pagoMovil => Icons.smartphone,
        MetodoPago.transferencia => Icons.account_balance_outlined,
        MetodoPago.zelle => Icons.attach_money,
        MetodoPago.biopago => Icons.fingerprint,
        MetodoPago.puntoDeVenta => Icons.point_of_sale,
      };
}
