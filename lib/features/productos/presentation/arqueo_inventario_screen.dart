import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';

/// Arqueo de inventario — "Contar inventario real" (`Lote C`).
///
/// El dueño recorre el estante y escribe lo que **hay**; la pantalla muestra
/// lo que el sistema **cree** y la diferencia. Al guardar, lo contado gana.
///
/// Es el equivalente en mercancía del arqueo de caja: no busca culpables,
/// busca que el número del sistema vuelva a ser cierto. Por eso la diferencia
/// se muestra sin dramatismo (ámbar, no rojo) y los productos sin contar
/// simplemente se dejan como están.
class ArqueoInventarioScreen extends ConsumerStatefulWidget {
  const ArqueoInventarioScreen({super.key});

  @override
  ConsumerState<ArqueoInventarioScreen> createState() =>
      _ArqueoInventarioScreenState();
}

class _ArqueoInventarioScreenState
    extends ConsumerState<ArqueoInventarioScreen> {
  /// productoId → cantidad contada. Lo que no está aquí no se toca.
  final Map<String, double> _contado = {};
  final Map<String, TextEditingController> _controles = {};
  String _busqueda = '';
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _control(Producto p) {
    return _controles.putIfAbsent(p.id, TextEditingController.new);
  }

  double _diferenciaDe(Producto p) {
    final c = _contado[p.id];
    return c == null ? 0 : c - p.cantidad;
  }

  Future<void> _guardar(List<Producto> productos) async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null || _contado.isEmpty) return;

    final conDiferencia = productos
        .where((p) => _contado.containsKey(p.id) && _diferenciaDe(p) != 0)
        .toList();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Guardar el conteo?'),
        content: Text(
          conDiferencia.isEmpty
              ? 'Todo cuadra con el sistema. No hay nada que ajustar.'
              : 'Se van a corregir ${conDiferencia.length} '
                  '${conDiferencia.length == 1 ? "producto" : "productos"}. '
                  'Lo que contaste reemplaza lo que dice el sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(productoRepositoryProvider)
          .ajustarCantidades(membresia.negocioId, _contado);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inventario actualizado.'),
          backgroundColor: AppColors.marca,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.peligro),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final visibles = _busqueda.trim().isEmpty
        ? productos
        : productos
            .where((p) =>
                p.nombre.toLowerCase().contains(_busqueda.toLowerCase().trim()))
            .toList();

    final contados = _contado.length;
    final descuadres = productos
        .where((p) => _contado.containsKey(p.id) && _diferenciaDe(p) != 0)
        .length;

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        LibretaBackButton(
                          oscuro: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contar inventario',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: t.textoFuerte,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                contados == 0
                                    ? 'Escribe lo que hay en el estante'
                                    : '$contados contados · '
                                        '$descuadres sin cuadrar',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: t.textoMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _busqueda = v),
                      style: TextStyle(fontSize: 14, color: t.textoFuerte),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto…',
                        prefixIcon: Icon(
                          Icons.search,
                          size: 19,
                          color: t.textoMuted,
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: t.superficie,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.renglon),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: t.renglon),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibles.isEmpty
                    ? Center(
                        child: Text(
                          productos.isEmpty
                              ? 'No hay productos que contar.'
                              : 'Ningún producto coincide.',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.textoMuted,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        itemCount: visibles.length,
                        itemBuilder: (_, i) {
                          final p = visibles[i];
                          return _FilaConteo(
                            producto: p,
                            control: _control(p),
                            diferencia: _diferenciaDe(p),
                            contado: _contado.containsKey(p.id),
                            onCambio: (texto) {
                              final v = double.tryParse(
                                texto.replaceAll(',', '.'),
                              );
                              setState(() {
                                if (texto.trim().isEmpty || v == null) {
                                  _contado.remove(p.id);
                                } else {
                                  _contado[p.id] = v;
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: LibretaButton(
                  label: contados == 0
                      ? 'Cuenta al menos un producto'
                      : 'Guardar conteo de $contados',
                  loading: _guardando,
                  onPressed:
                      contados == 0 ? null : () => _guardar(productos),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaConteo extends StatelessWidget {
  const _FilaConteo({
    required this.producto,
    required this.control,
    required this.diferencia,
    required this.contado,
    required this.onCambio,
  });

  final Producto producto;
  final TextEditingController control;
  final double diferencia;
  final bool contado;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final cuadra = contado && diferencia == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(
          color: cuadra ? const Color(0x4D0E9F6E) : t.renglon,
        ),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Sistema: ${producto.cantidadLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: t.textoMuted,
                      ),
                    ),
                    if (contado && diferencia != 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        diferencia > 0
                            ? '+${Producto.formatearCantidad(diferencia, producto.vendidoPorPeso)}'
                            : '−${Producto.formatearCantidad(-diferencia, producto.vendidoPorPeso)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: LibretaColors.aviso,
                        ),
                      ),
                    ],
                    if (cuadra) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: LibretaColors.verde,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: TextField(
              controller: control,
              onChanged: onCambio,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
              decoration: InputDecoration(
                hintText: 'real',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: t.textoMuted,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.renglon),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: t.renglon),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Total en USD de lo que se perdió/apareció en el conteo — lo usa el resumen
/// del arqueo si más adelante se quiere reportar.
double valorDelDescuadre(
  List<Producto> productos,
  Map<String, double> contado,
) {
  var total = 0.0;
  for (final p in productos) {
    final c = contado[p.id];
    if (c == null) continue;
    total += (c - p.cantidad) * (p.costo ?? p.precio);
  }
  return total;
}

/// Formatea el valor del descuadre para mostrarlo.
String descuadreLabel(double valor) => MoneyFormatter.usd(valor.abs());
