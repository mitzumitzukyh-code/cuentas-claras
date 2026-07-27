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
import '../data/venta_repository.dart';
import '../domain/venta.dart';
import 'widgets/overlay_cobrado.dart';

/// Pantalla 7 — Cobrar (réplica visual de `P0 · COBRAR`, `Lote B · Ventas`).
///
/// Calculadora de monto libre: el dueño teclea el total a cobrar en vez de
/// elegir productos uno por uno. Por diseño explícito, estas ventas **no
/// descuentan inventario ni se atribuyen a un producto** en Reportes — quedan
/// registradas como `productoId` vacío (ver `VentaRepository`). El método de
/// pago sí se conserva porque lo necesita el cierre de caja (Lote H).
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
                    padding: const EdgeInsets.fromLTRB(54, 30, 22, 12),
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

                          _EtiquetaSeccion(texto: 'Método de pago'),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: MetodoPago.values.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (_, i) => _ChipMetodo(
                                label: MetodoPago.values[i].etiquetaCorta,
                                selected: _metodo == MetodoPago.values[i],
                                onTap: () => setState(
                                  () => _metodo = MetodoPago.values[i],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

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

                          LibretaButton(
                            label: 'Cobrar ${MoneyFormatter.usd(total)}',
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
            texto: 'Binance',
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? LibretaColors.verde : t.superficie,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? LibretaColors.verde : t.bordeSuave,
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

