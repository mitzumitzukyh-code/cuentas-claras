import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/routes.dart';
import '../../../core/constants/app_links.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/captura_widget.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../../ventas/domain/venta.dart';

/// Catálogo (réplica visual de `P1 · CATÁLOGO`, `Lote D · Planes y
/// Catálogo`).
///
/// Se eligen productos (grilla con selección, chips de categoría) y se
/// comparten de tres formas: texto para WhatsApp, imagen generada, o Estado.
/// En plan gratis la imagen lleva marca de agua (CLAUDE.md §6).
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  final Set<String> _elegidos = {};
  final _lienzo = GlobalKey();

  String? _categoria;
  bool _generando = false;
  bool _sembrado = false;

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
          : ' (${MoneyFormatter.usdComoBs(p.precio, tasa)})';
      return '• ${p.nombre} — ${MoneyFormatter.usd(p.precio)}$bs';
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
      ..writeln('📲 Hecho con Cuenta Clara — ${AppLinks.descargar}');

    await Share.share(texto.toString(), subject: 'Catálogo ${negocio.nombre}');
  }

  Future<void> _compartirImagen(String nombreNegocio) async {
    setState(() => _generando = true);
    try {
      final archivo = await CapturaWidget.aPng(
        _lienzo,
        escala: 2.5,
        nombre: 'catalogo',
      );
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: 'Catálogo de $nombreNegocio\n'
            '📲 Hecho con Cuenta Clara — ${AppLinks.descargar}',
      );
    } catch (e) {
      _mostrar('No se pudo generar la imagen: $e');
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _sembrar(productos);

    final categorias = <String>{
      for (final p in productos)
        if (p.categoria.isNotEmpty) p.categoria,
    }.toList()
      ..sort();
    final visibles = _categoria == null
        ? productos
        : productos.where((p) => p.categoria == _categoria).toList();

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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${elegidos.length} seleccionados',
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
                if (categorias.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        LibretaChip(
                          label: 'Todos',
                          selected: _categoria == null,
                          onTap: () => setState(() => _categoria = null),
                        ),
                        for (final c in categorias)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: LibretaChip(
                              label: c,
                              selected: _categoria == c,
                              onTap: () => setState(() => _categoria = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                Divider(height: 1, color: context.libreta.renglon),
                Expanded(
                  child: productos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'Agrega productos para poder compartirlos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.86,
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
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.libreta.renglon),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LibretaButton(
                          label: 'Compartir por WhatsApp',
                          onPressed: () =>
                              _compartirTexto(productos, negocio, tasa),
                        ),
                        const SizedBox(height: 10),
                        LibretaSecondaryButton(
                          label: _generando ? 'Generando…' : 'Compartir como imagen',
                          icon: _generando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : null,
                          onPressed: elegidos.isEmpty || _generando
                              ? null
                              : () => _compartirImagen(negocio.nombre),
                        ),
                        const SizedBox(height: 10),
                        LibretaSecondaryButton(
                          label: 'Publicar en Estado de WhatsApp',
                          onPressed: () => context.push(
                            Routes.estadoWhatsApp,
                            extra: elegidos.isEmpty ? productos : elegidos,
                          ),
                        ),
                      ],
                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de producto de la grilla (réplica del mockup: foto + nombre +
/// precio, con insignia de selección).
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.libreta.superficie,
          border: Border.all(color: const Color(0x141E2A38)),
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
                            alError: const Icon(
                              Icons.inventory_2_outlined,
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
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 30,
                              color: Color(0x66000000),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: marcado ? LibretaColors.verde : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: marcado ? LibretaColors.verde : context.libreta.bordeSuave,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: marcado
                          ? const Icon(Icons.check, size: 15, color: Colors.white)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
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
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MoneyFormatter.usd(producto.precio),
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: LibretaColors.verde,
                    ),
                  ),
                ],
              ),
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
  });

  final Negocio negocio;
  final List<Producto> productos;
  final double? tasa;

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
                            child: const Icon(
                              Icons.inventory_2_outlined,
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
                              Text(
                                MoneyFormatter.usd(p.precio),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.marca,
                                ),
                              ),
                              if (tasa != null)
                                Text(
                                  MoneyFormatter.usdComoBs(p.precio, tasa!),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8A9A96),
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
          Container(
            color: const Color(0xFF1E2A38),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            child: const Text(
              'HECHO CON CUENTA CLARA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Color(0xEBFFFFFF),
              ),
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
