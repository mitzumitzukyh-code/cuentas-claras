import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../productos/domain/variante.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../fiados/data/fiado_repository.dart';
import '../../fiados/domain/cliente_fiado.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../../productos/presentation/widgets/escaner_codigo_barras.dart';
import '../data/carrito_provider.dart';
import '../data/venta_repository.dart';
import '../domain/item_carrito.dart';
import '../domain/venta.dart';
import 'widgets/overlay_cobrado.dart';

/// Qué se está armando: una venta que se cobra ya, o una cotización que se
/// manda por WhatsApp y no toca inventario ni caja.
enum _Modo { venta, cotizacion }

/// Ventas de los últimos 30 días: la base para saber qué se mueve de verdad.
final _ventasRecientesProvider = StreamProvider.autoDispose<List<Venta>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  final hace30dias = DateTime.now().subtract(const Duration(days: 30));
  return ref
      .watch(ventaRepositoryProvider)
      .ventasDesde(membresia.negocioId, hace30dias);
});

/// Unidades vendidas por producto en los últimos 30 días.
///
/// Ordena el catálogo de Cobrar por lo que de verdad se mueve: en una bodega
/// con cientos de productos, lo más vendido debe estar arriba sin que el
/// cajero tenga que escribir nada con clientes esperando.
final _frecuenciaVentaProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final ventas = ref.watch(_ventasRecientesProvider).valueOrNull ?? const [];
  final conteo = <String, int>{};
  for (final v in ventas) {
    if (v.anulada) continue;
    for (final item in v.items) {
      if (item.productoId.isEmpty) continue;
      conteo[item.productoId] = (conteo[item.productoId] ?? 0) + item.cantidad.round();
    }
  }
  return conteo;
});

/// Pantalla 7 — Cobrar (`Lote B · P0`).
///
/// El carrito es la superficie de captura: se toca un producto del catálogo y
/// entra al total. Cada línea lleva su `productoId` real, así que
/// [VentaRepository.registrarVenta] descuenta inventario en la misma
/// transacción que escribe la venta.
///
/// El "monto libre" (venta rápida sin producto asociado) sigue disponible
/// detrás del chevron de la tarjeta de total: entra como una línea con
/// `productoId` vacío, que el repositorio reconoce y no descuenta de nada.
class CobrarScreen extends ConsumerStatefulWidget {
  const CobrarScreen({super.key});

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  _Modo _modo = _Modo.venta;
  MetodoPago _metodo = MetodoPago.efectivo;
  bool _fiado = false;
  ClienteFiado? _cliente;

  final _busqueda = TextEditingController();
  String _termino = '';

  /// Venta rápida sin producto: se suma al total y no descuenta inventario.
  double _montoLibre = 0;

  bool _cobrando = false;
  bool _mostrarCheck = false;
  double _montoCobrado = 0;
  String? _fiadoA;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  double _totalDe(List<ItemCarrito> carrito) =>
      carrito.fold<double>(0, (s, i) => s + i.subtotal) + _montoLibre;

  int _piezasDe(List<ItemCarrito> carrito) =>
      carrito.fold<int>(0, (s, i) => s + i.cantidad) + (_montoLibre > 0 ? 1 : 0);

  /// El cliente hace falta para fiar y para cotizar: ambos son una promesa a
  /// nombre de alguien.
  bool get _requiereCliente => _fiado || _modo == _Modo.cotizacion;

  void _aviso(String texto, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? AppColors.peligro : AppColors.marca,
      ),
    );
  }

  // ── Catálogo ────────────────────────────────────────────────────────────

  /// Filtra por nombre y ordena por lo más vendido — con empate, se respeta
  /// el orden original para que la grilla no "baile" en cada venta.
  List<Producto> _filtrarYOrdenar(
    List<Producto> productos,
    Map<String, int> frecuencia,
  ) {
    final termino = _termino.trim().toLowerCase();
    final indexados = productos
        .asMap()
        .entries
        .where((e) => termino.isEmpty || e.value.nombre.toLowerCase().contains(termino))
        .toList();
    indexados.sort((a, b) {
      final fa = frecuencia[a.value.id] ?? 0;
      final fb = frecuencia[b.value.id] ?? 0;
      if (fa != fb) return fb.compareTo(fa);
      return a.key.compareTo(b.key);
    });
    return [for (final e in indexados) e.value];
  }

  Future<void> _escanearProducto(List<Producto> productos) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanerCodigoBarras()),
    );
    if (codigo == null || !mounted) return;
    final producto =
        productos.where((p) => p.codigoBarras == codigo).firstOrNull;
    if (producto == null) {
      _aviso('Ningún producto tiene ese código de barras.');
      return;
    }
    await _agregar(producto);
  }

  Future<void> _agregar(Producto p) async {
    var cantidad = 1;
    Variante? variante;

    if (p.tieneVariantes) {
      variante = await _elegirVariante(p);
      if (variante == null) return;
    }
    if (p.vendidoPorPeso) {
      final kg = await _pedirCantidad(p);
      if (kg == null) return;
      cantidad = kg.round();
    }

    ref.read(carritoProvider.notifier).agregar(
          ItemCarrito(
            productoId: p.id,
            nombre: p.nombre,
            precioUnitario: p.precio,
            cantidad: cantidad,
            varianteValor: variante?.valor,
            varianteColor: variante?.color,
            fotoUrl: p.fotoUrl,
            precioAnterior: p.tieneOferta ? p.precioAnterior : null,
          ),
        );
  }

  Future<Variante?> _elegirVariante(Producto p) {
    return showModalBottomSheet<Variante>(
      context: context,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = ctx.libreta;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 12),
                ...p.variantes.map(
                  (v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      [
                        v.valor,
                        if (v.color != null && v.color!.isNotEmpty) v.color!,
                      ].join(' / '),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.textoFuerte,
                      ),
                    ),
                    subtitle: Text(
                      'Quedan ${v.cantidad}',
                      style: TextStyle(fontSize: 12, color: t.textoMuted),
                    ),
                    onTap: v.cantidad <= 0 && p.bloquearAlAgotarse
                        ? null
                        : () => Navigator.of(ctx).pop(v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<double?> _pedirCantidad(Producto p) {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Cuántos kg de ${p.nombre}?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              double.tryParse(ctrl.text.replaceAll(',', '.')),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirMontoLibre() async {
    final ctrl = TextEditingController(
      text: _montoLibre > 0 ? _montoLibre.toStringAsFixed(2) : '',
    );
    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monto libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para cobrar algo que no está en el inventario. No descuenta '
              'existencias.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: r'$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(0.0),
            child: const Text('Quitar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0,
            ),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (monto != null && mounted) setState(() => _montoLibre = monto);
  }

  // ── Cliente ─────────────────────────────────────────────────────────────

  Future<void> _elegirCliente() async {
    final clientes = ref.read(clientesFiadoProvider).valueOrNull ?? const [];
    final elegido = await showModalBottomSheet<ClienteFiado>(
      context: context,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = ctx.libreta;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elegir cliente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 8),
                if (clientes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Todavía no tienes clientes con cuenta. Créalos desde '
                      'Fiados.',
                      style: TextStyle(fontSize: 13.5, color: t.textoMuted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in clientes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _Avatar(nombre: c.nombre),
                            title: Text(
                              c.nombre,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: t.textoFuerte,
                              ),
                            ),
                            subtitle: Text(
                              c.saldoUSD > 0
                                  ? 'Debe ${MoneyFormatter.usd(c.saldoUSD)}'
                                  : 'Al día',
                              style: TextStyle(
                                fontSize: 12,
                                color: t.textoMuted,
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop(c),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (elegido != null && mounted) setState(() => _cliente = elegido);
  }

  // ── Cobrar ──────────────────────────────────────────────────────────────

  /// Un producto marcado "bloquear al agotarse" no se puede vender por encima
  /// de su stock. Los demás sí (una bodega vende y ajusta después).
  String? _stockInsuficiente(List<ItemCarrito> carrito) {
    final productos = ref.read(productosProvider).valueOrNull ?? const [];
    for (final item in carrito) {
      final p = productos.where((x) => x.id == item.productoId).firstOrNull;
      if (p == null || !p.bloquearAlAgotarse) continue;
      if (item.cantidad > p.cantidad) {
        return 'Solo quedan ${p.cantidadLabel} de "${p.nombre}".';
      }
    }
    return null;
  }

  String _concepto(List<ItemCarrito> carrito) {
    if (carrito.isEmpty) return 'Venta rápida';
    if (carrito.length <= 2) {
      return carrito
          .map((i) => i.cantidad > 1 ? '${i.nombre} ×${i.cantidad}' : i.nombre)
          .join(' + ');
    }
    return '${carrito.length} productos';
  }

  Future<void> _cobrar(double tasa, Negocio negocio) async {
    final carrito = ref.read(carritoProvider);
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).value;
    final total = _totalDe(carrito);
    if (membresia == null || user == null || total <= 0) return;

    if (_fiado && _cliente == null) {
      _aviso('Elige a quién se le fía.');
      return;
    }
    final falta = _stockInsuficiente(carrito);
    if (falta != null) {
      _aviso(falta);
      return;
    }

    setState(() => _cobrando = true);

    final productos = ref.read(productosProvider).valueOrNull ?? const [];
    final items = <ItemVenta>[
      for (final i in carrito)
        ItemVenta(
          productoId: i.productoId,
          nombre: i.nombre,
          cantidad: i.cantidad.toDouble(),
          precioUnitario: i.precioUnitario,
          costoUnitario:
              productos.where((p) => p.id == i.productoId).firstOrNull?.costo,
          varianteValor: i.varianteValor,
          varianteColor: i.varianteColor,
          fotoUrl: i.fotoUrl,
        ),
      // Línea sin producto: el repositorio la reconoce y no toca inventario.
      if (_montoLibre > 0)
        ItemVenta(
          productoId: '',
          nombre: 'Venta rápida',
          cantidad: 1,
          precioUnitario: _montoLibre,
        ),
    ];

    final iva = negocio.incluirIva
        ? total * Negocio.tasaIva / (1 + Negocio.tasaIva)
        : 0.0;
    final venta = Venta(
      id: '',
      items: items,
      totalUSD: total,
      totalBs: MoneyFormatter.convertirABs(total, tasa),
      tasaBcvUsada: tasa,
      vendidoPor: user.uid,
      fecha: DateTime.now(),
      metodoPago: _metodo,
      ivaUSD: iva,
      fiadoClienteId: _fiado ? _cliente!.id : null,
      fiadoClienteNombre: _fiado ? _cliente!.nombre : null,
    );

    try {
      await ref.read(ventaRepositoryProvider).registrarVenta(
            membresia.negocioId,
            venta,
            fiadoA: _fiado
                ? FiadoDeVenta(
                    clienteId: _cliente!.id,
                    clienteNombre: _cliente!.nombre,
                    concepto: _concepto(carrito),
                  )
                : null,
          );
      if (!mounted) return;
      final eraFiado = _fiado;
      final nombre = _cliente?.nombre;
      ref.read(carritoProvider.notifier).vaciar();
      setState(() {
        _montoCobrado = total;
        _montoLibre = 0;
        _cobrando = false;
        _mostrarCheck = true;
        _fiadoA = eraFiado ? nombre : null;
        _fiado = false;
        _cliente = null;
        _metodo = MetodoPago.efectivo;
      });
      Future.delayed(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _mostrarCheck = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      _aviso('$e');
    }
  }

  // ── Cotización ──────────────────────────────────────────────────────────

  Future<void> _enviarCotizacion(double tasa, Negocio negocio) async {
    final carrito = ref.read(carritoProvider);
    final total = _totalDe(carrito);
    if (total <= 0) return;
    if (_cliente == null) {
      _aviso('Elige a quién va la cotización.');
      return;
    }

    final tipo = ref.read(tasaActivaProvider);
    final lineas = carrito
        .map((i) => '• ${i.nombre} ×${i.cantidad} — '
            '${MoneyFormatter.usd(i.subtotal)}')
        .join('\n');

    final mensaje = StringBuffer()
      ..writeln('Hola ${_cliente!.nombre} 👋 aquí tu cotización de '
          '${negocio.nombre}:')
      ..writeln()
      ..writeln(lineas)
      ..writeln()
      ..writeln('${MoneyFormatter.usd(total)} · '
          '${MoneyFormatter.usdComoBs(total, tasa)}')
      ..writeln('válida por 24h · ${tipo.etiqueta}')
      ..writeln()
      ..write('¿La confirmamos? Aviso cuando pases a recoger.');

    await Share.share(
      mensaje.toString(),
      subject: 'Cotización ${negocio.nombre}',
    );
    if (!mounted) return;
    ref.read(carritoProvider.notifier).vaciar();
    setState(() {
      _montoLibre = 0;
      _cliente = null;
      _modo = _Modo.venta;
    });
    _aviso('Cotización enviada.', error: false);
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tipoTasa = ref.watch(tasaActivaProvider);
    final tasa = ref.watch(tasaActivaValorProvider);
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final carrito = ref.watch(carritoProvider);
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final frecuencia = ref.watch(_frecuenciaVentaProvider);
    final productosVisibles = _filtrarYOrdenar(productos, frecuencia);
    final total = _totalDe(carrito);
    final piezas = _piezasDe(carrito);
    final esCotizacion = _modo == _Modo.cotizacion;

    // Solo los métodos que el negocio realmente acepta (Ajustes › Métodos de
    // pago). "Fiado" va siempre al final y no se configura: no es una forma
    // de pago, es una deuda.
    final activos = negocio?.metodosActivos ?? const [];

    final listo = total > 0 && tasa != null && negocio != null && !_cobrando;

    return Scaffold(
      backgroundColor: t.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.cobrar),
      body: Stack(
        children: [
          LibretaPageBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Encabezado ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cobrar',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: t.textoFuerte,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            _SelectorTasa(
                              valor: tipoTasa,
                              onChanged: (v) => ref
                                  .read(tasaActivaProvider.notifier)
                                  .elegir(v),
                            ),
                          ],
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: LibretaAvisoOfflineCompacto(),
                        ),
                        const SizedBox(height: 12),
                        _Segmentado(
                          modo: _modo,
                          onChanged: (m) => setState(() {
                            _modo = m;
                            if (m == _Modo.cotizacion) _fiado = false;
                          }),
                        ),
                        if (!esCotizacion) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in activos)
                                _PastillaMetodo(
                                  label: c.metodo.etiquetaCorta,
                                  activa: !_fiado && _metodo == c.metodo,
                                  onTap: () => setState(() {
                                    _metodo = c.metodo;
                                    _fiado = false;
                                  }),
                                ),
                              _PastillaMetodo(
                                label: 'Fiado',
                                activa: _fiado,
                                esFiado: true,
                                onTap: () => setState(() => _fiado = !_fiado),
                              ),
                            ],
                          ),
                        ],
                        if (_requiereCliente) ...[
                          const SizedBox(height: 10),
                          _TarjetaCliente(
                            cliente: _cliente,
                            sufijo: esCotizacion
                                ? 'recibe la cotización'
                                : 'se anota a su cuenta',
                            onCambiar: _elegirCliente,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Total, carrito y catálogo ───────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BuscadorProductos(
                            controller: _busqueda,
                            onChanged: (v) => setState(() => _termino = v),
                            onEscanear: () => _escanearProducto(productos),
                          ),
                          const SizedBox(height: 10),
                          _TarjetaTotal(
                            etiqueta: esCotizacion
                                ? 'TOTAL A COTIZAR'
                                : 'TOTAL A COBRAR',
                            totalUSD: total,
                            enBs: tasa == null
                                ? '${tipoTasa.etiqueta} no disponible'
                                : '${MoneyFormatter.usdComoBs(total, tasa)}'
                                    ' · ${tipoTasa.etiqueta}',
                            piezas: piezas,
                            onTapPie: _abrirMontoLibre,
                          ),
                          if (carrito.isNotEmpty || _montoLibre > 0) ...[
                            const SizedBox(height: 8),
                            _ListaCarrito(
                              carrito: carrito,
                              montoLibre: _montoLibre,
                              onQuitar: (i) =>
                                  ref.read(carritoProvider.notifier).quitar(i),
                              onQuitarMontoLibre: () =>
                                  setState(() => _montoLibre = 0),
                            ),
                          ],
                          const SizedBox(height: 10),
                          if (_termino.isEmpty && frecuencia.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 13,
                                    color: LibretaColors.aviso,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MÁS VENDIDOS PRIMERO',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: t.textoMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _GridCatalogo(
                              productos: productosVisibles,
                              buscando: _termino.isNotEmpty,
                              onTap: _agregar,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _BotonCobrar(
                            label: esCotizacion
                                ? 'Enviar cotización ${MoneyFormatter.usd(total)}'
                                : _fiado
                                    ? 'Anotar fiado ${MoneyFormatter.usd(total)}'
                                    : 'Cobrar ${MoneyFormatter.usd(total)}',
                            icono: esCotizacion
                                ? Icons.chat_bubble
                                : _fiado
                                    ? Icons.description_outlined
                                    : Icons.check_rounded,
                            cargando: _cobrando,
                            onPressed: !listo
                                ? null
                                : esCotizacion
                                    ? () => _enviarCotizacion(tasa, negocio)
                                    : () => _cobrar(tasa, negocio),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mostrarCheck)
            OverlayCobrado(
              monto: _montoCobrado,
              tasa: tasa,
              fiadoA: _fiadoA,
              onTap: () => setState(() => _mostrarCheck = false),
            ),
        ],
      ),
    );
  }
}

/// Fondo de las "pistas" de pastillas y segmentados: rgba(30,42,56,.06) en
/// claro, su equivalente crema en oscuro.
Color _pista(LibretaTokens t) => t.textoFuerte.withValues(alpha: 0.06);

// ── Encabezado ────────────────────────────────────────────────────────────

/// Pastillas BCV / Paralelo del encabezado.
class _SelectorTasa extends StatelessWidget {
  const _SelectorTasa({required this.valor, required this.onChanged});

  final TipoTasa valor;
  final ValueChanged<TipoTasa> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _pista(t),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillTasa(
            texto: 'BCV',
            activa: valor == TipoTasa.bcv,
            onTap: () => onChanged(TipoTasa.bcv),
          ),
          _PillTasa(
            // Copy de cara al usuario; el enum sigue siendo `binance`.
            texto: 'Paralelo',
            activa: valor == TipoTasa.binance,
            onTap: () => onChanged(TipoTasa.binance),
          ),
        ],
      ),
    );
  }
}

class _PillTasa extends StatelessWidget {
  const _PillTasa({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: activa ? t.superficie : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: activa
              ? const [
                  BoxShadow(
                    color: Color(0x2E1E2A38),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activa ? FontWeight.w800 : FontWeight.w700,
            color: activa ? t.textoFuerte : t.textoMuted,
          ),
        ),
      ),
    );
  }
}

/// Segmentado Venta | Cotización.
class _Segmentado extends StatelessWidget {
  const _Segmentado({required this.modo, required this.onChanged});

  final _Modo modo;
  final ValueChanged<_Modo> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _pista(t),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final m in _Modo.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: modo == m ? LibretaColors.verde : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    m == _Modo.venta ? 'Venta' : 'Cotización',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          modo == m ? FontWeight.w800 : FontWeight.w700,
                      color: modo == m ? Colors.white : t.textoMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastilla de método de pago. La de "Fiado" es ámbar con texto navy — es la
/// única que no cobra plata en el momento.
class _PastillaMetodo extends StatelessWidget {
  const _PastillaMetodo({
    required this.label,
    required this.activa,
    required this.onTap,
    this.esFiado = false,
  });

  final String label;
  final bool activa;
  final VoidCallback onTap;
  final bool esFiado;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: activa
              ? (esFiado ? const Color(0xFFF2A93C) : LibretaColors.verde)
              : _pista(t),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: activa
                ? (esFiado ? LibretaColors.tarjetaOscura : Colors.white)
                : t.textoMuted,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del cliente al que se le fía o se le cotiza.
class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({
    required this.cliente,
    required this.sufijo,
    required this.onCambiar,
  });

  final ClienteFiado? cliente;
  final String sufijo;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tel = cliente?.telefono;
    return GestureDetector(
      onTap: cliente == null ? onCambiar : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: const Color(0x4D0E9F6E), width: 1.5),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            _Avatar(nombre: cliente?.nombre),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cliente?.nombre ?? 'Elegir cliente',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    cliente == null
                        ? 'toca para buscarlo'
                        : [
                            if (tel != null && tel.isNotEmpty) tel,
                            sufijo,
                          ].join(' · '),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: t.textoMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCambiar,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Cambiar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
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

/// Círculo navy con las iniciales del cliente.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nombre});

  final String? nombre;

  String get _iniciales {
    final partes = (nombre ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: LibretaColors.tarjetaOscura,
        shape: BoxShape.circle,
      ),
      child: Text(
        _iniciales,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Total y carrito ───────────────────────────────────────────────────────

/// Tarjeta hero navy con el total. El pie es tocable: abre el monto libre.
class _TarjetaTotal extends StatelessWidget {
  const _TarjetaTotal({
    required this.etiqueta,
    required this.totalUSD,
    required this.enBs,
    required this.piezas,
    required this.onTapPie,
  });

  final String etiqueta;
  final double totalUSD;
  final String enBs;
  final int piezas;
  final VoidCallback onTapPie;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: LibretaColors.tarjetaOscura,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.bordeHero, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              MoneyFormatter.usd(totalUSD),
              style: AppTypography.money(fontSize: 44, color: Colors.white)
                  .copyWith(letterSpacing: -1, height: 1),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            enBs,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xB3FFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTapPie,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x24FFFFFF))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      piezas == 0
                          ? 'Carrito vacío — toca un producto'
                          : piezas == 1
                              ? '1 producto en el carrito'
                              : '$piezas productos en el carrito',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xD9FFFFFF),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xB3FFFFFF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Las líneas ya agregadas. Tocar una la quita (una unidad a la vez).
class _ListaCarrito extends StatelessWidget {
  const _ListaCarrito({
    required this.carrito,
    required this.montoLibre,
    required this.onQuitar,
    required this.onQuitarMontoLibre,
  });

  final List<ItemCarrito> carrito;
  final double montoLibre;
  final ValueChanged<int> onQuitar;
  final VoidCallback onQuitarMontoLibre;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      constraints: const BoxConstraints(maxHeight: 68),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        children: [
          for (var i = 0; i < carrito.length; i++)
            _FilaCarrito(
              nombre: carrito[i].cantidad > 1
                  ? '${carrito[i].nombre} ×${carrito[i].cantidad}'
                  : carrito[i].nombre,
              monto: carrito[i].subtotal,
              onQuitar: () => onQuitar(i),
            ),
          if (montoLibre > 0)
            _FilaCarrito(
              nombre: 'Monto libre',
              monto: montoLibre,
              onQuitar: onQuitarMontoLibre,
            ),
        ],
      ),
    );
  }
}

class _FilaCarrito extends StatelessWidget {
  const _FilaCarrito({
    required this.nombre,
    required this.monto,
    required this.onQuitar,
  });

  final String nombre;
  final double monto;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onQuitar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.renglon)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.textoFuerte,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              MoneyFormatter.usd(monto),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.close_rounded, size: 14, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}

/// Buscador del catálogo + atajo al escáner de código de barras.
///
/// Con muchos productos y varios clientes esperando, deslizar buscando por
/// nombre no alcanza: escribir dos letras o escanear el código es más rápido
/// que leer etiquetas truncadas en la grilla.
class _BuscadorProductos extends StatelessWidget {
  const _BuscadorProductos({
    required this.controller,
    required this.onChanged,
    required this.onEscanear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.superficie,
              border: Border.all(color: t.renglon),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: t.textoMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.textoFuerte,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Buscar producto…',
                      hintStyle: TextStyle(
                        color: t.textoMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: t.textoMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEscanear,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: LibretaColors.tarjetaOscura,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// Catálogo en dos columnas. Es la superficie de captura de la pantalla.
class _GridCatalogo extends StatelessWidget {
  const _GridCatalogo({
    required this.productos,
    required this.onTap,
    this.buscando = false,
  });

  final List<Producto> productos;
  final ValueChanged<Producto> onTap;
  final bool buscando;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    if (productos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            buscando
                ? 'Ningún producto coincide con esa búsqueda.'
                : 'Todavía no tienes productos cargados.\nToca el total '
                    'para cobrar un monto libre.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: t.textoMuted,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 58,
      ),
      itemCount: productos.length,
      itemBuilder: (_, i) => _FichaProducto(
        producto: productos[i],
        onTap: () => onTap(productos[i]),
      ),
    );
  }
}

class _FichaProducto extends StatelessWidget {
  const _FichaProducto({required this.producto, required this.onTap});

  final Producto producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.renglon),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              producto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: t.textoFuerte,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  MoneyFormatter.usd(producto.precio),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.verde,
                  ),
                ),
                if (producto.tieneOferta) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      MoneyFormatter.usd(producto.precioAnterior!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: t.textoMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// CTA de 56px con la sombra verde del diseño.
class _BotonCobrar extends StatelessWidget {
  const _BotonCobrar({
    required this.label,
    required this.icono,
    required this.cargando,
    required this.onPressed,
  });

  final String label;
  final IconData icono;
  final bool cargando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: activo
            ? const [
                BoxShadow(
                  color: Color(0x590E9F6E),
                  offset: Offset(0, 12),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: activo ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: LibretaColors.verde,
            disabledBackgroundColor:
                LibretaColors.verde.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: cargando
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icono, size: 21, color: Colors.white),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
