import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';
import 'nuevo_producto_screen.dart';

/// Pantalla 5 — Productos (bloque `isProductos` del diseño).
///
/// Buscador hundido, chips de categoría, lista de tarjetas con miniatura y
/// precio en USD/Bs, y el botón flotante "+" para dar de alta.
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
        // Las comillas evitan que un nombre con coma rompa las columnas.
        '"${p.nombre}","${p.categoria}",${p.precio},${p.cantidad}',
    ];
    await Share.share(
      filas.join('\n'),
      subject: 'Inventario Cuenta Clara',
    );
  }

  /// Abre WhatsApp con la lista de productos por reponer.
  Future<void> _pedirReabastecimiento(List<Producto> bajos) async {
    final telefono = ref
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
    final texto = 'Hola, necesito reabastecer estos productos:\n\n$lista\n\n'
        '¡Gracias!';
    final uri = Uri.parse(
      'https://wa.me/$telefono?text=${Uri.encodeComponent(texto)}',
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _mostrar('No se pudo abrir WhatsApp.');
    }
  }

  Future<void> _abrirImportar() async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoImportar(),
    );
    if (texto == null || texto.trim().isEmpty) return;

    final membresia = ref.read(membresiaActivaProvider);
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (membresia == null || negocio == null) return;

    // Formato del diseño: "nombre, precio, stock" por línea.
    final nuevos = <Producto>[];
    final invalidas = <int>[];
    final lineas = texto.trim().split('\n');

    for (var i = 0; i < lineas.length; i++) {
      final partes = lineas[i].split(',');
      if (partes.length < 3) {
        invalidas.add(i + 1);
        continue;
      }
      final nombre = partes[0].trim();
      final precio = double.tryParse(partes[1].trim().replaceAll(',', '.'));
      final stock = double.tryParse(partes[2].trim().replaceAll(',', '.'));
      if (nombre.isEmpty || precio == null || stock == null) {
        invalidas.add(i + 1);
        continue;
      }
      nuevos.add(Producto(
        id: '',
        nombre: nombre,
        categoria: negocio.rubro.config.categoriasSugeridas.firstOrNull ?? '',
        precio: precio,
        cantidad: stock,
        alertaEn: 5,
      ));
    }

    if (nuevos.isEmpty) {
      _mostrar('Ninguna línea tenía el formato "nombre, precio, stock".');
      return;
    }

    try {
      await ref
          .read(productoRepositoryProvider)
          .crearVarios(membresia.negocioId, nuevos);
      final aviso = invalidas.isEmpty
          ? '${nuevos.length} productos importados'
          : '${nuevos.length} importados · ${invalidas.length} líneas omitidas';
      _mostrar(aviso);
    } catch (e) {
      _mostrar('No se pudo importar: $e');
    }
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final productosAsync = ref.watch(productosProvider);
    final esDueno = ref.watch(esDuenoProvider);
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(activa: NavTab.productos),
      floatingActionButton: esDueno
          ? Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.marca,
                borderRadius: BorderRadius.circular(22),
                boxShadow: t.shadowBtn,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push(Routes.nuevoProducto),
                  child: const Icon(Icons.add, color: Colors.white, size: 26),
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: productosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar los productos.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSec),
              ),
            ),
          ),
          data: (productos) {
            final categorias = <String>{
              for (final p in productos)
                if (p.categoria.isNotEmpty) p.categoria,
            }.toList()
              ..sort();

            final texto = _busqueda.text.trim().toLowerCase();
            final bajos = productos.where((p) => p.stockBajo).toList();
            final visibles = productos.where((p) {
              final porCategoria =
                  _categoria == null || p.categoria == _categoria;
              final porTexto =
                  texto.isEmpty || p.nombre.toLowerCase().contains(texto);
              final porStock = !_soloStockBajo || p.stockBajo;
              return porCategoria && porTexto && porStock;
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Productos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                    ),
                    if (esDueno) ...[
                      NeuIconBtn(
                        emoji: '📥',
                        radius: 12,
                        onTap: _abrirImportar,
                      ),
                      const SizedBox(width: 8),
                    ],
                    NeuIconBtn(
                      emoji: '📤',
                      radius: 12,
                      onTap: () => _exportar(productos),
                    ),
                  ],
                ),

                // Banner del filtro de stock bajo (el diseño lo abre desde el
                // contador del Dashboard).
                if (_soloStockBajo) ...[
                  const SizedBox(height: 12),
                  _BannerStockBajo(
                    onPedir: () => _pedirReabastecimiento(bajos),
                    onCerrar: () => setState(() => _soloStockBajo = false),
                  ),
                ],

                const SizedBox(height: 16),
                NeuInput(
                  controller: _busqueda,
                  hint: 'Buscar producto',
                  height: 46,
                  onChanged: (_) => setState(() {}),
                ),
                if (categorias.isNotEmpty || bajos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        NeuChip(
                          label: 'Todas',
                          dense: true,
                          selected: _categoria == null && !_soloStockBajo,
                          onTap: () => setState(() {
                            _categoria = null;
                            _soloStockBajo = false;
                          }),
                        ),
                        if (bajos.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: NeuChip(
                              label: 'Stock bajo (${bajos.length})',
                              dense: true,
                              selected: _soloStockBajo,
                              onTap: () => setState(
                                () => _soloStockBajo = !_soloStockBajo,
                              ),
                            ),
                          ),
                        for (final c in categorias)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: NeuChip(
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
                  const _Vacio(
                    emoji: '📦',
                    titulo: 'Aún no tienes productos',
                    detalle: 'Toca + para agregar el primero',
                  )
                else if (visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'No se encontraron productos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.textSec),
                    ),
                  )
                else
                  for (final p in visibles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TarjetaProducto(
                        producto: p,
                        tasa: tasa,
                        // Solo el dueño gestiona el catálogo (CLAUDE.md §6).
                        onTap: esDueno
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
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
    );
  }
}

/// Banner ámbar del filtro de stock bajo, con atajo a WhatsApp.
class _BannerStockBajo extends StatelessWidget {
  const _BannerStockBajo({required this.onPedir, required this.onCerrar});

  final VoidCallback onPedir;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.avisoSuave,
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
                color: AppColors.aviso,
              ),
            ),
          ),
          GestureDetector(
            onTap: onPedir,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.aviso,
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
            child: const Icon(Icons.close, size: 16, color: AppColors.aviso),
          ),
        ],
      ),
    );
  }
}

/// Modal de importación masiva: una línea por producto.
class _DialogoImportar extends StatefulWidget {
  const _DialogoImportar();

  @override
  State<_DialogoImportar> createState() => _DialogoImportarState();
}

class _DialogoImportarState extends State<_DialogoImportar> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AlertDialog(
      title: const Text('Importar productos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Un producto por línea: nombre, precio, stock',
            style: TextStyle(fontSize: 12.5, color: t.textSec),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: NeuInset(
              radius: 14,
              color: t.pageBg,
              child: TextField(
                controller: _texto,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(fontSize: 13, color: t.text),
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Harina PAN 1kg, 1.20, 45\nArroz Diana 1kg, 0.95, 30',
                  hintStyle: TextStyle(fontSize: 13, color: t.muted),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_texto.text),
          child: const Text('Importar'),
        ),
      ],
    );
  }
}

/// Estado vacío con emoji, título y pista.
class _Vacio extends StatelessWidget {
  const _Vacio({
    required this.emoji,
    required this.titulo,
    required this.detalle,
  });

  final String emoji;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: t.textSec,
            ),
          ),
          const SizedBox(height: 4),
          Text(detalle, style: TextStyle(fontSize: 13, color: t.textSec)),
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
    this.onTap,
  });

  final Producto producto;
  final double? tasa;
  final VoidCallback? onTap;

  /// El prototipo asigna un color estable por nombre cuando no hay foto.
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
    final t = context.tokens;
    final tieneFoto = producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty;

    return NeuCard(
      small: true,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tieneFoto ? t.pageBg : _color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: t.shadowRaisedSm,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: tieneFoto
                ? Image.network(
                    producto.fotoUrl!,
                    fit: BoxFit.cover,
                    width: 42,
                    height: 42,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.image_outlined, color: t.muted, size: 18),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (producto.categoria.isNotEmpty) producto.categoria,
                    'quedan ${producto.cantidadLabel}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: producto.stockBajo ? AppColors.aviso : t.textSec,
                    fontWeight:
                        producto.stockBajo ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                MoneyFormatter.usd(producto.precio),
                style: AppTypography.money(fontSize: 14, color: t.text),
              ),
              if (tasa != null)
                Text(
                  MoneyFormatter.usdComoBs(producto.precio, tasa!),
                  style: TextStyle(fontSize: 11, color: t.textSec),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
