import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_typography.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/presentation/permiso_requerido.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../../core/business/business_profile_provider.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';
import 'nuevo_producto_screen.dart';
import '../../../shared/utils/errores.dart';

/// Pantalla 5 — Productos (réplica visual de `P2 · PRODUCTOS`,
/// `Lote C · Gastos y Productos`).
///
/// Buscador, chips de categoría, lista de tarjetas con miniatura y precio en
/// USD/Bs, y el botón "+" para dar de alta.
class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _busqueda = TextEditingController();
  String? _categoria;
  bool _soloStockBajo = false;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  /// Exporta el inventario como CSV y abre el diálogo de compartir.
  Future<void> _exportar(List<Producto> productos) async {
    if (productos.isEmpty) {
      _mostrar('No hay productos que exportar.');
      return;
    }
    final filas = <String>[
      'Nombre,Categoria,Precio USD,Stock',
      for (final p in productos)
        '"${p.nombre}","${p.categoria}",${p.precio},${p.cantidad}',
    ];
    await Share.share(filas.join('\n'), subject: 'Inventario Cuenta Clara');
  }

  /// Abre WhatsApp con la lista de productos por reponer.
  Future<void> _pedirReabastecimiento(List<Producto> bajos) async {
    final telefono =
        ref
            .read(negocioActivoProvider)
            .valueOrNull
            ?.proveedorWhatsapp
            ?.replaceAll(RegExp(r'\D'), '') ??
        '';
    if (telefono.isEmpty) {
      _mostrar('Configura el WhatsApp del proveedor en Ajustes.');
      return;
    }

    final lista = bajos
        .map((p) => '• ${p.nombre} (quedan ${p.cantidadLabel})')
        .join('\n');
    final texto =
        'Hola, necesito reabastecer estos productos:\n\n$lista\n\n'
        '¡Gracias!';
    final uri = Uri.parse(
      'https://wa.me/$telefono?text=${Uri.encodeComponent(texto)}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _mostrar('No se pudo abrir WhatsApp.');
    }
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosProvider);
    final perfil = ref.watch(businessProfileProvider);
    final vocab = perfil.vocab;
    // Permiso, no rol: un vendedor con «editar inventario» activado también
    // puede cargar mercancía. El dueño lo cumple siempre.
    final puedeEditar = ref.watch(puedeProvider(Permisos.editarInventario));
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    return Scaffold(
      backgroundColor: context.libreta.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.productos),
      floatingActionButton:
          puedeEditar
              ? FloatingActionButton(
                backgroundColor: LibretaColors.verde,
                shape: const CircleBorder(),
                onPressed: () => context.push(Routes.nuevoProducto),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              )
              : null,
      body: LibretaPageBackground(
        child: SafeArea(
          bottom: false,
          child: productosAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      mensajeDeError(e, accion: 'cargar tu ${vocab.inventoryLabel.toLowerCase()}'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.libreta.textoMuted),
                    ),
                  ),
                ),
            data: (productos) {
              final categorias =
                  <String>{
                      for (final p in productos)
                        if (p.categoria.isNotEmpty) p.categoria,
                    }.toList()
                    ..sort();

              final texto = _busqueda.text.trim().toLowerCase();
              final bajos = productos.where((p) => p.stockBajo).toList();
              final visibles =
                  productos.where((p) {
                    final porCategoria =
                        _categoria == null || p.categoria == _categoria;
                    final porTexto =
                        texto.isEmpty || p.nombre.toLowerCase().contains(texto);
                    final porStock = !_soloStockBajo || p.stockBajo;
                    return porCategoria && porTexto && porStock;
                  }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(22, 30, 22, 100),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vocab.inventoryLabel,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: context.libreta.textoFuerte,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '${productos.length} en inventario',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: LibretaAvisoOfflineCompacto(),
                            ),
                          ],
                        ),
                      ),
                      if (puedeEditar) ...[
                        LibretaIconButton(
                          icon: Icons.file_download_outlined,
                          onTap: () => context.push(Routes.importarInventario),
                        ),
                        const SizedBox(width: 8),
                      ],
                      LibretaIconButton(
                        icon: Icons.ios_share,
                        onTap: () => _exportar(productos),
                      ),
                    ],
                  ),

                  if (_soloStockBajo) ...[
                    const SizedBox(height: 14),
                    _BannerStockBajo(
                      onPedir: () => _pedirReabastecimiento(bajos),
                      onCerrar: () => setState(() => _soloStockBajo = false),
                    ),
                  ],

                  const SizedBox(height: 16),
                  LibretaInput(
                    controller: _busqueda,
                    hint: 'Buscar ${vocab.itemSingular}…',
                    height: 46,
                    bordeVerde: true,
                    leading: const LibretaIcono(AppAssets.accBuscar,
                      size: 18,
                      color: LibretaColors.verde,
                    ),
                    suffix:
                        _busqueda.text.isEmpty
                            ? null
                            : GestureDetector(
                              onTap: () => setState(() => _busqueda.clear()),
                              child: LibretaIcono(AppAssets.accCerrar,
                                size: 17,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${visibles.length} de ${productos.length} ${vocab.itemPlural}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                  if (puedeEditar && productos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _BotonContarInventario(
                      onTap: () => context.push(Routes.arqueoInventario),
                    ),
                  ],
                  if (categorias.isNotEmpty || bajos.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          LibretaChip(
                            label: 'Todas',
                            dense: true,
                            selected: _categoria == null && !_soloStockBajo,
                            onTap:
                                () => setState(() {
                                  _categoria = null;
                                  _soloStockBajo = false;
                                }),
                          ),
                          if (bajos.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: LibretaChip(
                                label: 'Stock bajo (${bajos.length})',
                                dense: true,
                                selected: _soloStockBajo,
                                onTap:
                                    () => setState(
                                      () => _soloStockBajo = !_soloStockBajo,
                                    ),
                              ),
                            ),
                          for (final c in categorias)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: LibretaChip(
                                label: c,
                                dense: true,
                                selected: _categoria == c,
                                onTap: () => setState(() => _categoria = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (productos.isEmpty)
                    LibretaEstadoVacio(
                      ilustracion: Ilustracion.sinProductos,
                      titulo: 'Tu ${vocab.inventoryLabel.toLowerCase()} está vacía',
                      detalle:
                          'Agrega ${vocab.itemPlural} con foto, precio y '
                          'stock para empezar a cobrar rápido.',
                      tagline: 'empieza a llenar tu cuaderno',
                      boton:
                          puedeEditar
                              ? LibretaButton(
                                label: vocab.addItemCta,
                                icon: const Icon(
                                  Icons.add,
                                  size: 19,
                                  color: Colors.white,
                                ),
                                onPressed:
                                    () => context.push(Routes.nuevoProducto),
                              )
                              : null,
                    )
                  else if (visibles.isEmpty)
                    LibretaEstadoVacio(
                      ilustracion: Ilustracion.sinResultados,
                      titulo: 'Sin resultados',
                      detalle: texto.isNotEmpty
                          ? 'No hay ${vocab.itemPlural} que coincidan con '
                              '«${_busqueda.text.trim()}».'
                          : 'Ningún ${vocab.itemSingular} coincide con este filtro.',
                      boton: LibretaSecondaryButton(
                        label: 'Limpiar filtros',
                        onPressed: () => setState(() {
                          _busqueda.clear();
                          _categoria = null;
                          _soloStockBajo = false;
                        }),
                      ),
                    )
                  else
                    for (final p in visibles)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TarjetaProducto(
                          producto: p,
                          tasa: tasa,
                          unidadPorDefecto: perfil.defaultUnit,
                          onTap:
                              puedeEditar
                                  ? () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) =>
                                              NuevoProductoScreen(producto: p),
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Banner ámbar del filtro de stock bajo, con atajo a WhatsApp.
/// Botón punteado "Contar inventario real" (Lote C).
///
/// Punteado y no sólido a propósito: no es una acción del día a día, es el
/// mantenimiento que se hace de vez en cuando.
class _BotonContarInventario extends StatelessWidget {
  const _BotonContarInventario({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: DottedBorderBox(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fact_check_outlined, size: 17, color: t.textoMuted),
              const SizedBox(width: 8),
              Text(
                'Contar inventario real',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: t.textoFuerte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerStockBajo extends StatelessWidget {
  const _BannerStockBajo({required this.onPedir, required this.onCerrar});

  final VoidCallback onPedir;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x21F2A93C),
        border: Border.all(color: const Color(0x59F2A93C)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Mostrando solo productos con stock bajo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: LibretaColors.aviso,
              ),
            ),
          ),
          GestureDetector(
            onTap: onPedir,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: LibretaColors.aviso,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Pedir por WhatsApp',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCerrar,
            child: const LibretaIcono(AppAssets.accCerrar,
              size: 16,
              color: LibretaColors.aviso,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila-tarjeta de producto.
class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({
    required this.producto,
    required this.tasa,
    required this.unidadPorDefecto,
    this.onTap,
  });

  final Producto producto;
  final double? tasa;

  /// La del perfil del negocio, para los productos que no traen la suya.
  final String unidadPorDefecto;
  final VoidCallback? onTap;

  static const _colores = [
    Color(0xFF0F6B5C),
    Color(0xFF3D6CA8),
    Color(0xFFC9852B),
    Color(0xFF8A5FB0),
    Color(0xFFC74A3A),
  ];

  Color get _color =>
      _colores[producto.nombre.hashCode.abs() % _colores.length];

  @override
  Widget build(BuildContext context) {
    final tieneFoto = producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.libreta.superficie,
          border: Border.all(color: const Color(0x141E2A38)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tieneFoto ? context.libreta.papel : _color,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child:
                  tieneFoto
                      ? FotoRed(
                        producto.fotoUrl!,
                        width: 42,
                        height: 42,
                        alError: Icon(
                          Icons.image_outlined,
                          color: context.libreta.textoMuted,
                          size: 18,
                        ),
                      )
                      : Text(
                        producto.nombre.isEmpty
                            ? '?'
                            : producto.nombre[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (producto.categoria.isNotEmpty) producto.categoria,
                      'quedan ${producto.cantidadCon(unidadPorDefecto)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          producto.stockBajo
                              ? LibretaColors.aviso
                              : context.libreta.textoMuted,
                      fontWeight:
                          producto.stockBajo
                              ? FontWeight.w700
                              : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Un producto sin precio no lleva conversión ni jerarquía de
                // moneda: lleva un aviso. Lo demás lo ordena `LibretaMonto`
                // según la moneda que el negocio eligió.
                if (producto.precio == null) ...[
                  Text(
                    producto.precioLabel,
                    style: AppTypography.money(
                      fontSize: 14,
                      color: LibretaColors.aviso,
                    ),
                  ),
                  Text(
                    'ponle precio para venderlo',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: LibretaColors.aviso,
                    ),
                  ),
                ] else
                  LibretaMonto(
                    usd: producto.precio!,
                    alineacion: CrossAxisAlignment.end,
                    estiloPrincipal: AppTypography.money(
                      fontSize: 14,
                      color: context.libreta.textoFuerte,
                    ),
                    estiloSecundario: TextStyle(
                      fontSize: 11,
                      color: context.libreta.textoMuted,
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
