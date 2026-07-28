import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../data/carrito_provider.dart';
import '../data/venta_repository.dart';
import '../domain/item_carrito.dart';
import '../domain/venta.dart';
import 'widgets/overlay_cobrado.dart';

enum _ModoCobro { productos, montoLibre }

/// Pantalla 7 — Cobrar híbrido (Lote B · P0).
///
/// Dos modos en la misma pantalla:
/// - **Productos** (carrito): grid del catálogo + items agregados, descuenta
///   inventario al cobrar.
/// - **Monto libre** (calculadora): teclea el total, sin tocar inventario.
///
/// Compatible con el modo anterior: si el negocio no tiene productos cargados,
/// abre en "Monto libre" por defecto.
class CobrarScreen extends ConsumerStatefulWidget {
  const CobrarScreen({super.key});

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  static const _maxDigitos = 9;

  String _entrada = '';
  MetodoPago _metodo = MetodoPago.efectivo;
  bool _cobrando = false;
  bool _mostrarCheck = false;
  double _montoCobrado = 0;
  _ModoCobro _modo = _ModoCobro.montoLibre;
  bool _fiadoSeleccionado = false;
  String? _clienteFiadoId;
  String? _clienteFiadoNombre;

  double get _monto => double.tryParse(_entrada.replaceAll(',', '.')) ?? 0;

  void _tecla(String t) {
    setState(() {
      if (t == '⌫') {
        if (_entrada.isNotEmpty) {
          _entrada = _entrada.substring(0, _entrada.length - 1);
        }
        return;
      }
      if (t == ',') {
        if (_entrada.contains(',') || _entrada.isEmpty) return;
        _entrada += t;
        return;
      }
      if (_entrada.replaceAll(',', '').length >= _maxDigitos) return;
      // Evita ceros a la izquierda ("0" + "5" → "5", no "05").
      if (_entrada == '0') {
        _entrada = t;
      } else {
        _entrada += t;
      }
    });
  }

  Future<void> _cobrar(double tasa, Negocio negocio) async {
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).value;
    final total = _monto;
    if (membresia == null || user == null || total <= 0) return;

    setState(() => _cobrando = true);

    final iva = negocio.incluirIva ? total * Negocio.tasaIva / (1 + Negocio.tasaIva) : 0.0;
    final item = ItemVenta(
      // Vacío a propósito: venta de monto libre, sin producto asociado — el
      // repositorio la reconoce y no toca inventario (ver `_porProducto`).
      productoId: '',
      nombre: 'Venta rápida',
      cantidad: 1,
      precioUnitario: total,
    );

    final venta = Venta(
      id: '',
      items: [item],
      totalUSD: total,
      totalBs: MoneyFormatter.convertirABs(total, tasa),
      tasaBcvUsada: tasa,
      vendidoPor: user.uid,
      fecha: DateTime.now(),
      metodoPago: _metodo,
      ivaUSD: iva,
    );

    try {
      await ref.read(ventaRepositoryProvider).registrarVenta(
            membresia.negocioId,
            venta,
          );
      if (!mounted) return;
      setState(() {
        _montoCobrado = total;
        _entrada = '';
        _cobrando = false;
        _mostrarCheck = true;
      });
      Future.delayed(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _mostrarCheck = false);
      });
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
    final t = context.libreta;
    final tipoTasa = ref.watch(tasaActivaProvider);
    final tasa = ref.watch(tasaActivaValorProvider);
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final total = _monto;

    return Scaffold(
      backgroundColor: t.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.cobrar),
      body: Stack(
        children: [
          LibretaPageBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 22, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cobrar',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: t.textoFuerte,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        _SelectorTasa(
                          valor: tipoTasa,
                          onChanged: (t) =>
                              ref.read(tasaActivaProvider.notifier).elegir(t),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                            decoration: BoxDecoration(
                              color: LibretaColors.tarjetaOscura,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: t.bordeHero, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TOTAL A COBRAR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: Color(0x99FFFFFF),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  MoneyFormatter.usd(total),
                                  style: AppTypography.money(
                                    fontSize: 40,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tasa == null
                                      ? '${tipoTasa.etiqueta} no disponible'
                                      : '${MoneyFormatter.usdComoBs(total, tasa)} · '
                                          '${tipoTasa.etiqueta}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xB3FFFFFF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          _SelectorModo(
                            valor: _modo,
                            onChanged: (m) =>
                                setState(() => _modo = m),
                          ),
                          const SizedBox(height: 14),

                          if (_modo == _ModoCobro.productos)
                            _PanelProductos(
                              ref: ref,
                              carrito: ref.watch(carritoProvider),
                              onAgregar: (p) {
                                ref.read(carritoProvider.notifier).agregar(
                                  ItemCarrito(
                                    productoId: p.id,
                                    nombre: p.nombre,
                                    precioUnitario: p.precio,
                                    fotoUrl: p.fotoUrl,
                                    precioAnterior: p.tieneOferta
                                        ? p.precioAnterior
                                        : null,
                                  ),
                                );
                              },
                              onQuitar: (idx) {
                                ref
                                    .read(carritoProvider.notifier)
                                    .quitar(idx);
                              },
                            )
                          else
                            _TecladoNumerico(
                              entrada: _entrada,
                              onTecla: _tecla,
                            ),

                          const SizedBox(height: 14),
                          _EtiquetaSeccion(texto: 'Método de pago'),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: MetodoPago.values.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                if (i < MetodoPago.values.length) {
                                  final m = MetodoPago.values[i];
                                  return _ChipMetodo(
                                    label: m.etiquetaCorta,
                                    selected: _metodo == m,
                                    onTap: () => setState(() {
                                      _metodo = m;
                                      _fiadoSeleccionado = false;
                                    }),
                                  );
                                }
                                return _ChipMetodo(
                                  label: 'Fiado',
                                  selected: _fiadoSeleccionado,
                                  colorAmbar: true,
                                  onTap: () => setState(() {
                                    _fiadoSeleccionado = !_fiadoSeleccionado;
                                    if (_fiadoSeleccionado) {
                                      _metodo = MetodoPago.efectivo;
                                    }
                                  }),
                                );
                              },
                            ),
                          ),

                          if (_fiadoSeleccionado)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0x4DF2A93C)),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32, height: 32,
                                      decoration: const BoxDecoration(
                                        color: LibretaColors.tarjetaOscura,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _clienteFiadoNombre != null
                                            ? _clienteFiadoNombre![0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _clienteFiadoNombre ?? 'Seleccionar cliente',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: context.libreta.textoFuerte,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // TODO: abrir selector de clientes
                                      },
                                      child: const Text('Cambiar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (_modo == _ModoCobro.montoLibre) ...[
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.5,
                              children: [
                                for (final d in [
                                  '1', '2', '3',
                                  '4', '5', '6',
                                  '7', '8', '9',
                                  ',', '0', '⌫',
                                ])
                                  _TeclaNumerica(
                                    texto: d,
                                    onTap: () => _tecla(d),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

                          LibretaButton(
                            label: _fiadoSeleccionado
                                ? 'Anotar fiado ${MoneyFormatter.usd(total)}'
                                : 'Cobrar ${MoneyFormatter.usd(total)}',
                            loading: _cobrando,
                            onPressed: (total <= 0 || tasa == null || negocio == null)
                                ? null
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
              onTap: () => setState(() => _mostrarCheck = false),
            ),
        ],
      ),
    );
  }
}

class _SelectorModo extends StatelessWidget {
  const _SelectorModo({required this.valor, required this.onChanged});

  final _ModoCobro valor;
  final ValueChanged<_ModoCobro> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.bordeSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(_ModoCobro.productos),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: valor == _ModoCobro.productos
                      ? LibretaColors.verde
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Productos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: valor == _ModoCobro.productos
                        ? Colors.white
                        : t.textoMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(_ModoCobro.montoLibre),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: valor == _ModoCobro.montoLibre
                      ? LibretaColors.verde
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Monto libre',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: valor == _ModoCobro.montoLibre
                        ? Colors.white
                        : t.textoMuted,
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

class _PanelProductos extends ConsumerWidget {
  const _PanelProductos({
    required this.ref,
    required this.carrito,
    required this.onAgregar,
    required this.onQuitar,
  });

  final WidgetRef ref;
  final List<ItemCarrito> carrito;
  final ValueChanged<Producto> onAgregar;
  final ValueChanged<int> onQuitar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(productosProvider).valueOrNull ?? [];
    final t = context.libreta;
    final busqueda = ValueNotifier('');

    return Column(
      children: [
        if (carrito.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 68),
            decoration: BoxDecoration(
              color: t.superficie,
              border: Border.all(color: t.bordeSuave),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: carrito.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 0),
              itemBuilder: (_, i) {
                final item = carrito[i];
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.cantidad}x ${item.nombre}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      MoneyFormatter.usd(item.subtotal),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0E9F6E)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onQuitar(i),
                      child: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFC74A3A)),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar producto…',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.bordeSuave)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.bordeSuave)),
          ),
          style: const TextStyle(fontSize: 14),
          onChanged: (v) => busqueda.value = v,
        ),
        const SizedBox(height: 10),
        if (productos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No hay productos cargados',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textoMuted),
            ),
          )
        else
          ...productos.take(6).map((p) => _TarjetaProducto(
                producto: p,
                onTap: () => onAgregar(p),
              )),
      ],
    );
  }
}

class _TarjetaProducto extends StatelessWidget {
  const _TarjetaProducto({required this.producto, required this.onTap});

  final Producto producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.superficie,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: t.bordeSuave),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      MoneyFormatter.usd(producto.precio),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LibretaColors.verde),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, size: 22, color: LibretaColors.verde),
            ],
          ),
        ),
      ),
    );
  }
}

class _TecladoNumerico extends StatelessWidget {
  const _TecladoNumerico({required this.entrada, required this.onTecla});

  final String entrada;
  final ValueChanged<String> onTecla;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        for (final d in [
          '1', '2', '3',
          '4', '5', '6',
          '7', '8', '9',
          ',', '0', '⌫',
        ])
          _TeclaNumerica(texto: d, onTap: () => onTecla(d)),
      ],
    );
  }
}

class _EtiquetaSeccion extends StatelessWidget {
  const _EtiquetaSeccion({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: context.libreta.textoMuted,
      ),
    );
  }
}

/// Pastilla BCV/Binance del encabezado.
class _SelectorTasa extends StatelessWidget {
  const _SelectorTasa({required this.valor, required this.onChanged});

  final TipoTasa valor;
  final ValueChanged<TipoTasa> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.libreta.bordeSuave,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pill(
            texto: 'BCV',
            activa: valor == TipoTasa.bcv,
            onTap: () => onChanged(TipoTasa.bcv),
          ),
          _Pill(
            texto: 'Paralelo',
            activa: valor == TipoTasa.binance,
            onTap: () => onChanged(TipoTasa.binance),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.texto, required this.activa, required this.onTap});

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

class _ChipMetodo extends StatelessWidget {
  const _ChipMetodo({
    required this.label,
    required this.selected,
    required this.onTap,
    this.colorAmbar = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool colorAmbar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final bg = colorAmbar ? const Color(0xFFF2A93C) : LibretaColors.verde;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? bg : t.superficie,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? bg : t.bordeSuave,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : t.textoFuerte,
          ),
        ),
      ),
    );
  }
}

/// Una tecla del teclado numérico.
class _TeclaNumerica extends StatelessWidget {
  const _TeclaNumerica({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final esBorrar = texto == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.bordeSuave),
        ),
        alignment: Alignment.center,
        child: esBorrar
            ? Icon(
                Icons.backspace_outlined,
                size: 20,
                color: t.textoMuted,
              )
            : Text(
                texto,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: t.textoFuerte,
                ),
              ),
      ),
    );
  }
}

/// Overlay de confirmación con el check dibujándose a mano.

