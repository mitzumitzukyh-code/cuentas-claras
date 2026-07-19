import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/neu.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../../productos/presentation/widgets/escaner_codigo_barras.dart';
import '../data/venta_repository.dart';
import '../domain/venta.dart';

/// Pantalla 7 — Cobrar (bloque `isCobrar` del diseño).
///
/// Cuadrícula de productos + hoja de carrito con método de pago, descuento,
/// ventas en espera y modal de peso para lo que se vende por kilo.
class CobrarScreen extends ConsumerStatefulWidget {
  const CobrarScreen({super.key});

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

/// Una venta pausada para atender a otro cliente.
///
/// Vive solo en memoria, como en el prototipo: son de vida muy corta (minutos)
/// y persistirlas en Firestore costaría escrituras sin aportar nada.
class _VentaEnEspera {
  const _VentaEnEspera({required this.carrito, required this.creada});

  final Map<String, double> carrito;
  final DateTime creada;

  int get lineas => carrito.length;
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  /// productoId → cantidad (unidades o kilos).
  final Map<String, double> _carrito = {};
  final _busqueda = TextEditingController();
  final List<_VentaEnEspera> _enEspera = [];

  MetodoPago _metodo = MetodoPago.efectivo;
  int _descuentoPct = 0;
  bool _expandido = false;
  bool _cobrando = false;

  static const _descuentos = [0, 5, 10, 15, 20];

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  // --- Carrito ---

  Future<void> _agregar(Producto p) async {
    if (p.vendidoPorPeso) {
      final kg = await _pedirPeso(p);
      if (kg == null) return;
      final total = (_carrito[p.id] ?? 0) + kg;
      if (total > p.cantidad) {
        _avisarStock(p);
        return;
      }
      setState(() => _carrito[p.id] = total);
      return;
    }

    final actual = _carrito[p.id] ?? 0;
    if (actual + 1 > p.cantidad) {
      _avisarStock(p);
      return;
    }
    setState(() => _carrito[p.id] = actual + 1);
  }

  void _quitar(Producto p) {
    final actual = _carrito[p.id] ?? 0;
    // Por peso no tiene sentido restar de uno en uno: se quita la línea.
    if (p.vendidoPorPeso || actual <= 1) {
      setState(() => _carrito.remove(p.id));
    } else {
      setState(() => _carrito[p.id] = actual - 1);
    }
  }

  void _avisarStock(Producto p) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Solo quedan ${p.cantidadLabel} de ${p.nombre}')),
    );
  }

  /// Modal de peso (bloque `pesoModalOpen` del diseño).
  Future<double?> _pedirPeso(Producto p) {
    return showDialog<double>(
      context: context,
      builder: (_) => _DialogoPeso(producto: p),
    );
  }

  // --- Ventas en espera ---

  void _ponerEnEspera() {
    if (_carrito.isEmpty) return;
    setState(() {
      _enEspera.add(_VentaEnEspera(
        carrito: Map<String, double>.from(_carrito),
        creada: DateTime.now(),
      ));
      _carrito.clear();
      _expandido = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Venta puesta en espera')),
    );
  }

  void _reanudar(_VentaEnEspera venta) {
    setState(() {
      // Lo que hubiera en el carrito se guarda para no perderlo.
      if (_carrito.isNotEmpty) {
        _enEspera.add(_VentaEnEspera(
          carrito: Map<String, double>.from(_carrito),
          creada: DateTime.now(),
        ));
      }
      _carrito
        ..clear()
        ..addAll(venta.carrito);
      _enEspera.remove(venta);
      _expandido = true;
    });
  }

  // --- Escáner ---

  Future<void> _escanear(List<Producto> productos) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanerCodigoBarras()),
    );
    if (codigo == null || !mounted) return;

    final encontrado =
        productos.where((p) => p.codigoBarras == codigo).firstOrNull;
    if (encontrado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ningún producto tiene el código $codigo')),
      );
      return;
    }
    await _agregar(encontrado);
  }

  // --- Cobro ---

  Future<void> _cobrar(
    List<Producto> productos,
    double tasa,
    Negocio negocio,
  ) async {
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).value;
    if (membresia == null || user == null || _carrito.isEmpty) return;

    setState(() => _cobrando = true);

    final items = <ItemVenta>[];
    for (final p in productos) {
      final cantidad = _carrito[p.id];
      if (cantidad == null || cantidad == 0) continue;
      items.add(ItemVenta(
        productoId: p.id,
        nombre: p.nombre,
        cantidad: cantidad,
        precioUnitario: p.precio,
        vendidoPorPeso: p.vendidoPorPeso,
      ));
    }

    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
    final conDescuento = subtotal - (subtotal * _descuentoPct / 100);
    final iva = negocio.incluirIva ? conDescuento * Negocio.tasaIva : 0.0;
    final total = conDescuento + iva;

    final venta = Venta(
      id: '',
      items: items,
      totalUSD: total,
      totalBs: MoneyFormatter.convertirABs(total, tasa),
      tasaBcvUsada: tasa,
      vendidoPor: user.uid,
      fecha: DateTime.now(),
      metodoPago: _metodo,
      descuentoPct: _descuentoPct,
      ivaUSD: iva,
    );

    try {
      await ref
          .read(ventaRepositoryProvider)
          .registrarVenta(membresia.negocioId, venta);
      if (!mounted) return;
      setState(() {
        _carrito.clear();
        _descuentoPct = 0;
        _expandido = false;
        _cobrando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Venta registrada: ${MoneyFormatter.usd(total)}'),
          backgroundColor: AppColors.marca,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.peligro),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final productosAsync = ref.watch(productosProvider);
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(activa: NavTab.cobrar),
      body: SafeArea(
        bottom: false,
        child: productosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (productos) {
            if (productos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Necesitas productos en el inventario para poder cobrar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: t.textSec),
                  ),
                ),
              );
            }

            final texto = _busqueda.text.trim().toLowerCase();
            final visibles = texto.isEmpty
                ? productos
                : productos
                    .where((p) => p.nombre.toLowerCase().contains(texto))
                    .toList();

            final enCarrito =
                productos.where((p) => (_carrito[p.id] ?? 0) > 0).toList();
            final subtotal = enCarrito.fold<double>(
              0,
              (s, p) => s + (_carrito[p.id] ?? 0) * p.precio,
            );
            final conDescuento = subtotal - (subtotal * _descuentoPct / 100);
            final iva =
                (negocio?.incluirIva ?? false) ? conDescuento * Negocio.tasaIva : 0.0;
            final total = conDescuento + iva;

            final espacioInferior = _carrito.isEmpty ? 90.0 : 150.0;

            return Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, espacioInferior),
                  children: [
                    Text(
                      'Cobrar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toca un producto o escanea su código',
                      style: TextStyle(fontSize: 13, color: t.textSec),
                    ),
                    const SizedBox(height: 14),
                    NeuSecondaryButton(
                      label: 'Escanear código de barras',
                      height: 48,
                      radius: 18,
                      icon: const Text('📊', style: TextStyle(fontSize: 14)),
                      onPressed: () => _escanear(productos),
                    ),
                    const SizedBox(height: 14),
                    const _SeparadorTexto(texto: 'O AGREGA MANUALMENTE'),
                    const SizedBox(height: 14),
                    NeuInput(
                      controller: _busqueda,
                      hint: 'Buscar producto',
                      height: 44,
                      radius: 16,
                      onChanged: (_) => setState(() {}),
                    ),

                    // --- Ventas en espera ---
                    if (_enEspera.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _enEspera.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _ChipEnEspera(
                            venta: _enEspera[i],
                            onTap: () => _reanudar(_enEspera[i]),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.35,
                      children: [
                        for (final p in visibles)
                          _MosaicoProducto(
                            producto: p,
                            cantidad: _carrito[p.id] ?? 0,
                            onTap: () => _agregar(p),
                          ),
                      ],
                    ),
                  ],
                ),

                if (_expandido)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _expandido = false),
                      child: Container(color: const Color(0x59000000)),
                    ),
                  ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _HojaCarrito(
                    items: enCarrito,
                    carrito: _carrito,
                    subtotal: subtotal,
                    iva: iva,
                    total: total,
                    tasa: tasa,
                    descuentoPct: _descuentoPct,
                    metodo: _metodo,
                    expandido: _expandido,
                    cobrando: _cobrando,
                    onAlternar: () => setState(() => _expandido = !_expandido),
                    onMas: _agregar,
                    onMenos: _quitar,
                    onVaciar: () => setState(() {
                      _carrito.clear();
                      _descuentoPct = 0;
                      _expandido = false;
                    }),
                    onEnEspera: _ponerEnEspera,
                    onMetodo: (m) => setState(() => _metodo = m),
                    onDescuento: (d) => setState(() => _descuentoPct = d),
                    descuentos: _descuentos,
                    onCobrar: tasa == null || _cobrando || negocio == null
                        ? null
                        : () => _cobrar(productos, tasa, negocio),
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

/// Modal para capturar el peso de un producto vendido por kilo.
class _DialogoPeso extends StatefulWidget {
  const _DialogoPeso({required this.producto});

  final Producto producto;

  @override
  State<_DialogoPeso> createState() => _DialogoPesoState();
}

class _DialogoPesoState extends State<_DialogoPeso> {
  final _kg = TextEditingController();

  double? get _valor => double.tryParse(_kg.text.replaceAll(',', '.'));

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final kg = _valor;
    final valido = kg != null && kg > 0;

    return AlertDialog(
      title: Text('⚖️ ${widget.producto.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresa el peso en kilogramos',
            style: TextStyle(fontSize: 12.5, color: t.textSec),
          ),
          const SizedBox(height: 12),
          NeuInput(
            controller: _kg,
            hint: 'Ej: 0,500',
            height: 48,
            radius: 14,
            fillWithPageBg: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          // Anticipa el cobro para que se pueda confirmar con el cliente.
          Text(
            valido
                ? 'Total: ${MoneyFormatter.usd(kg * widget.producto.precio)}'
                : '${MoneyFormatter.usd(widget.producto.precio)} por kg',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: valido ? AppColors.marca : t.textSec,
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
          onPressed: valido ? () => Navigator.of(context).pop(kg) : null,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

/// Chip azul de una venta pausada.
class _ChipEnEspera extends StatelessWidget {
  const _ChipEnEspera({required this.venta, required this.onTap});

  final _VentaEnEspera venta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutos = DateTime.now().difference(venta.creada).inMinutes;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.infoSuave,
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: Text(
          '⏸️ Reanudar (${venta.lineas}) · hace ${minutos}m',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.info,
          ),
        ),
      ),
    );
  }
}

/// Separador con texto en mayúsculas al centro.
class _SeparadorTexto extends StatelessWidget {
  const _SeparadorTexto({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: t.border2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.textSec,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: t.border2)),
      ],
    );
  }
}

/// Mosaico de producto con insignia de cantidad en el carrito.
class _MosaicoProducto extends StatelessWidget {
  const _MosaicoProducto({
    required this.producto,
    required this.cantidad,
    required this.onTap,
  });

  final Producto producto;
  final double cantidad;
  final VoidCallback onTap;

  static const _colores = [
    Color(0xFF0F6B5C),
    Color(0xFF3D6CA8),
    Color(0xFFC9852B),
    Color(0xFF8A5FB0),
    Color(0xFFC74A3A),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final agotado = producto.cantidad <= 0;
    final color = _colores[producto.nombre.hashCode.abs() % _colores.length];

    return Opacity(
      opacity: agotado ? 0.45 : 1,
      child: NeuCard(
        small: true,
        radius: 20,
        onTap: agotado ? null : onTap,
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: t.shadowRaisedSm,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    producto.nombre.isEmpty
                        ? '?'
                        : producto.nombre[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  agotado
                      ? 'Agotado'
                      : producto.vendidoPorPeso
                          ? '${MoneyFormatter.usd(producto.precio)} / kg'
                          : MoneyFormatter.usd(producto.precio),
                  style: TextStyle(
                    fontSize: 12,
                    color: agotado ? AppColors.peligro : t.textSec,
                  ),
                ),
              ],
            ),
            if (cantidad > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: AppColors.marca,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    Producto.formatearCantidad(
                      cantidad,
                      producto.vendidoPorPeso,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
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

/// Hoja inferior del carrito.
class _HojaCarrito extends StatelessWidget {
  const _HojaCarrito({
    required this.items,
    required this.carrito,
    required this.subtotal,
    required this.iva,
    required this.total,
    required this.tasa,
    required this.descuentoPct,
    required this.metodo,
    required this.expandido,
    required this.cobrando,
    required this.onAlternar,
    required this.onMas,
    required this.onMenos,
    required this.onVaciar,
    required this.onEnEspera,
    required this.onMetodo,
    required this.onDescuento,
    required this.descuentos,
    required this.onCobrar,
  });

  final List<Producto> items;
  final Map<String, double> carrito;
  final double subtotal;
  final double iva;
  final double total;
  final double? tasa;
  final int descuentoPct;
  final MetodoPago metodo;
  final bool expandido;
  final bool cobrando;
  final VoidCallback onAlternar;
  final void Function(Producto) onMas;
  final void Function(Producto) onMenos;
  final VoidCallback onVaciar;
  final VoidCallback onEnEspera;
  final ValueChanged<MetodoPago> onMetodo;
  final ValueChanged<int> onDescuento;
  final List<int> descuentos;
  final VoidCallback? onCobrar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final vacio = items.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: t.border2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            offset: Offset(0, -8),
            blurRadius: 24,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: vacio ? null : onAlternar,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.border,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (vacio)
                      Text(
                        'Carrito vacío',
                        style: TextStyle(fontSize: 13, color: t.muted),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${items.length} '
                              '${items.length == 1 ? "producto" : "productos"}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                          ),
                          Text(
                            MoneyFormatter.usd(total),
                            style: AppTypography.money(
                              fontSize: 16,
                              color: t.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: t.chip,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              expandido
                                  ? Icons.keyboard_arrow_down
                                  : Icons.keyboard_arrow_up,
                              size: 18,
                              color: AppColors.marca,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            if (!vacio && expandido)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final p in items)
                              _LineaCarrito(
                                producto: p,
                                cantidad: carrito[p.id] ?? 0,
                                onMas: () => onMas(p),
                                onMenos: () => onMenos(p),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: NeuSecondaryButton(
                              label: '⏸️ En espera',
                              height: 36,
                              radius: 14,
                              background: t.chip,
                              onPressed: onEnEspera,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: NeuSecondaryButton(
                              label: '🗑️ Vaciar',
                              height: 36,
                              radius: 14,
                              color: AppColors.peligro,
                              background: AppColors.peligroSuave,
                              onPressed: onVaciar,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- Método de pago ---
                      _EtiquetaSeccion(texto: 'Método de pago'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: MetodoPago.values.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => NeuChip(
                            label: MetodoPago.values[i].etiquetaCorta,
                            dense: true,
                            selected: metodo == MetodoPago.values[i],
                            onTap: () => onMetodo(MetodoPago.values[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Descuento ---
                      _EtiquetaSeccion(texto: 'Descuento'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: descuentos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => NeuChip(
                            label: descuentos[i] == 0
                                ? 'Sin descuento'
                                : '${descuentos[i]}%',
                            dense: true,
                            selected: descuentoPct == descuentos[i],
                            onTap: () => onDescuento(descuentos[i]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Totales ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (descuentoPct > 0)
                                Text(
                                  MoneyFormatter.usd(subtotal),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.textSec,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              if (iva > 0)
                                Text(
                                  'IVA 16%: ${MoneyFormatter.usd(iva)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.textSec,
                                  ),
                                ),
                              Text(
                                tasa == null
                                    ? 'Tasa BCV no disponible'
                                    : MoneyFormatter.usdComoBs(total, tasa!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: t.textSec,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            MoneyFormatter.usd(total),
                            style: AppTypography.money(
                              fontSize: 22,
                              color: t.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      NeuButton(
                        label: 'Cobrar ${MoneyFormatter.usd(total)}',
                        height: 50,
                        loading: cobrando,
                        onPressed: onCobrar,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EtiquetaSeccion extends StatelessWidget {
  const _EtiquetaSeccion({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      texto,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: t.textSec,
      ),
    );
  }
}

/// Línea del carrito con los botones − / +.
class _LineaCarrito extends StatelessWidget {
  const _LineaCarrito({
    required this.producto,
    required this.cantidad,
    required this.onMas,
    required this.onMenos,
  });

  final Producto producto;
  final double cantidad;
  final VoidCallback onMas;
  final VoidCallback onMenos;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              producto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ),
          _BotonCantidad(
            icono: producto.vendidoPorPeso ? Icons.close : Icons.remove,
            onTap: onMenos,
          ),
          SizedBox(
            width: 56,
            child: Text(
              Producto.formatearCantidad(cantidad, producto.vendidoPorPeso),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ),
          _BotonCantidad(icono: Icons.add, onTap: onMas),
          SizedBox(
            width: 60,
            child: Text(
              MoneyFormatter.usd(producto.precio * cantidad),
              textAlign: TextAlign.right,
              style: AppTypography.money(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonCantidad extends StatelessWidget {
  const _BotonCantidad({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: t.chip,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Icon(icono, size: 16, color: t.text),
      ),
    );
  }
}
