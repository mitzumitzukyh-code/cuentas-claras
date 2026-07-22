import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/captura_widget.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../productos/domain/producto.dart';

/// Formato de la imagen para el Estado de WhatsApp.
enum FormatoEstado { grilla, flyer }

/// Publicar en Estado (bloques `isEstado`, `isEstadoGrilla`, `isEstadoFlyer`).
///
/// Genera una imagen vertical 9:16 lista para subir. En grilla entran varios
/// productos; en flyer se destaca uno solo.
class EstadoScreen extends ConsumerStatefulWidget {
  const EstadoScreen({super.key, required this.productos});

  final List<Producto> productos;

  @override
  ConsumerState<EstadoScreen> createState() => _EstadoScreenState();
}

class _EstadoScreenState extends ConsumerState<EstadoScreen> {
  final _lienzo = GlobalKey();

  FormatoEstado _formato = FormatoEstado.grilla;
  Producto? _destacado;
  int _plantilla = 0;
  bool _generando = false;

  /// Plantillas de color del diseño.
  static const _plantillas = [
    (Color(0xFF0F6B5C), Color(0xFF0B4A40)),
    (Color(0xFF1B3A4B), Color(0xFF102530)),
    (Color(0xFFC9852B), Color(0xFF9A631C)),
    (Color(0xFF8A5FB0), Color(0xFF5F3F7D)),
  ];

  @override
  void initState() {
    super.initState();
    _destacado = widget.productos.firstOrNull;
  }

  Future<void> _compartir() async {
    setState(() => _generando = true);
    try {
      // 360×640 lógicos × 3 = 1080×1920, el tamaño que pide WhatsApp.
      final archivo = await CapturaWidget.aPng(
        _lienzo,
        escala: 3,
        nombre: 'estado',
      );
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: '📲 Hecho con Cuenta Clara — ${AppLinks.descargar}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lienzo = _LienzoEstado(
      formato: _formato,
      negocioNombre: negocio.nombre,
      productos: widget.productos,
      destacado: _destacado,
      colores: _plantillas[_plantilla],
      tasa: tasa,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
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
                  'Publicar en Estado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Formato ---
            Row(
              children: [
                Expanded(
                  child: _Pestana(
                    texto: 'Grilla',
                    activa: _formato == FormatoEstado.grilla,
                    onTap: () =>
                        setState(() => _formato = FormatoEstado.grilla),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Pestana(
                    texto: 'Flyer destacado',
                    activa: _formato == FormatoEstado.flyer,
                    onTap: () =>
                        setState(() => _formato = FormatoEstado.flyer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_formato == FormatoEstado.grilla)
              Text(
                'Se incluirán ${widget.productos.length.clamp(0, 6)} productos '
                'del catálogo.',
                style: TextStyle(fontSize: 13, color: t.textSec),
              )
            else ...[
              Text(
                'Elige el producto a destacar',
                style: TextStyle(fontSize: 13, color: t.textSec),
              ),
              const SizedBox(height: 10),
              for (final p in widget.productos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeuCard(
                    small: true,
                    radius: 18,
                    onTap: () => setState(() => _destacado = p),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _destacado?.id == p.id
                                ? AppColors.marca
                                : Colors.transparent,
                            border: Border.all(
                              color: _destacado?.id == p.id
                                  ? AppColors.marca
                                  : t.border,
                              width: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            p.nombre,
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
                          MoneyFormatter.usd(p.precio),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: t.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],

            const SizedBox(height: 18),

            // --- Plantillas de color ---
            Text(
              'Color',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textSec,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _plantillas.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _plantilla = i),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _plantillas[i].$1,
                              _plantillas[i].$2,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _plantilla == i
                                ? AppColors.marca
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Vista previa (el mismo widget que se captura) ---
            Center(
              child: FittedBox(
                child: RepaintBoundary(key: _lienzo, child: lienzo),
              ),
            ),
            const SizedBox(height: 18),

            NeuButton(
              label: 'Compartir en Estado',
              loading: _generando,
              onPressed: widget.productos.isEmpty ? null : _compartir,
            ),
            const SizedBox(height: 10),
            Text(
              'Se abre WhatsApp para que la subas a tu Estado.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: activa ? AppColors.marca : t.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: activa ? t.shadowBtn : t.shadowRaisedSm,
        ),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: activa ? Colors.white : t.text,
          ),
        ),
      ),
    );
  }
}

/// La imagen 9:16 que se sube al Estado.
class _LienzoEstado extends StatelessWidget {
  const _LienzoEstado({
    required this.formato,
    required this.negocioNombre,
    required this.productos,
    required this.destacado,
    required this.colores,
    required this.tasa,
  });

  final FormatoEstado formato;
  final String negocioNombre;
  final List<Producto> productos;
  final Producto? destacado;
  final (Color, Color) colores;
  final double? tasa;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colores.$1, colores.$2],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            negocioNombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Disponible ahora',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)),
          ),
          const SizedBox(height: 28),

          Expanded(
            child: formato == FormatoEstado.flyer
                ? _Flyer(producto: destacado, tasa: tasa)
                : _Grilla(productos: productos, tasa: tasa),
          ),

          const SizedBox(height: 16),
          if (tasa != null)
            Text(
              'Tasa BCV ${MoneyFormatter.bs(tasa!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Hecho con Cuenta Clara',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0x80FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hasta 6 productos en dos columnas.
class _Grilla extends StatelessWidget {
  const _Grilla({required this.productos, required this.tasa});

  final List<Producto> productos;
  final double? tasa;

  @override
  Widget build(BuildContext context) {
    final visibles = productos.take(6).toList();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        for (final p in visibles)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MoneyFormatter.usd(p.precio),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (tasa != null)
                      Text(
                        MoneyFormatter.usdComoBs(p.precio, tasa!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un solo producto en grande.
class _Flyer extends StatelessWidget {
  const _Flyer({required this.producto, required this.tasa});

  final Producto? producto;
  final double? tasa;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    if (p == null) {
      return const Center(
        child: Text(
          'Elige un producto',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.nombre,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              MoneyFormatter.usd(p.precio),
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
            if (tasa != null) ...[
              const SizedBox(height: 6),
              Text(
                MoneyFormatter.usdComoBs(p.precio, tasa!),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xD9FFFFFF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
