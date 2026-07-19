import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/captura_widget.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import 'estado_screen.dart';

/// Catálogo (bloque `isCatalogo` del diseño).
///
/// Se eligen productos y se comparten de dos formas: como texto para WhatsApp
/// o como imagen generada. En plan gratis la imagen lleva marca de agua
/// (CLAUDE.md §6).
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  final Set<String> _elegidos = {};
  final _lienzo = GlobalKey();

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

    final metodos = negocio.metodosActivos
        .map((m) => m.resumen)
        .join('\n');

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
        text: 'Catálogo de $nombreNegocio',
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
    final t = context.tokens;
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _sembrar(productos);

    final elegidos = _seleccionados(productos);
    final todosMarcados =
        productos.isNotEmpty && _elegidos.length == productos.length;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    NeuIconBtn(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Catálogo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: t.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Elige los productos a incluir · '
                        '${elegidos.length} seleccionados',
                        style: TextStyle(fontSize: 13, color: t.textSec),
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
                          color: AppColors.marca,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (productos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Text('📦', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 10),
                        Text(
                          'Agrega productos para poder compartirlos',
                          style: TextStyle(fontSize: 14, color: t.textSec),
                        ),
                      ],
                    ),
                  )
                else
                  for (final p in productos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FilaSeleccion(
                        producto: p,
                        marcado: _elegidos.contains(p.id),
                        onTap: () => setState(() {
                          if (!_elegidos.remove(p.id)) _elegidos.add(p.id);
                        }),
                      ),
                    ),

                if (productos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  NeuButton(
                    label: 'Compartir por WhatsApp (texto)',
                    color: const Color(0xFF25D366),
                    onPressed: () =>
                        _compartirTexto(productos, negocio, tasa),
                  ),
                  const SizedBox(height: 10),
                  NeuButton(
                    label: 'Compartir como imagen',
                    loading: _generando,
                    onPressed: elegidos.isEmpty
                        ? null
                        : () => _compartirImagen(negocio.nombre),
                  ),
                  const SizedBox(height: 10),
                  NeuSecondaryButton(
                    label: 'Publicar en Estado de WhatsApp',
                    color: AppColors.marca,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EstadoScreen(
                          productos: elegidos.isEmpty ? productos : elegidos,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
      ),
    );
  }
}

/// Fila con casilla de selección.
class _FilaSeleccion extends StatelessWidget {
  const _FilaSeleccion({
    required this.producto,
    required this.marcado,
    required this.onTap,
  });

  final Producto producto;
  final bool marcado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuCard(
      small: true,
      radius: 18,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: marcado ? AppColors.marca : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: marcado ? AppColors.marca : t.border,
                width: 2,
              ),
            ),
            child: marcado
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              producto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ),
          Text(
            MoneyFormatter.usd(producto.precio),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diseño de la imagen que se comparte. Formato apaisado tipo folleto.
class _LienzoCatalogo extends StatelessWidget {
  const _LienzoCatalogo({
    required this.negocio,
    required this.productos,
    required this.tasa,
  });

  final Negocio negocio;
  final List<Producto> productos;
  final double? tasa;

  @override
  Widget build(BuildContext context) {
    // Se pinta en claro siempre: una imagen oscura queda mal en WhatsApp.
    return Container(
      width: 420,
      color: const Color(0xFFF7F5F2),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.marca,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  negocio.nombre,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${productos.length} productos disponibles',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          for (final p in productos.take(14))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2421),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          MoneyFormatter.usd(p.precio),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.marca,
                          ),
                        ),
                        if (tasa != null)
                          Text(
                            MoneyFormatter.usdComoBs(p.precio, tasa!),
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF6B7873),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          if (productos.length > 14)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'y ${productos.length - 14} productos más…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7873),
                ),
              ),
            ),

          const SizedBox(height: 14),
          // Marca de agua del plan gratis (CLAUDE.md §6).
          const Text(
            'Hecho con Cuenta Clara',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFA39D90),
            ),
          ),
        ],
      ),
    );
  }
}
