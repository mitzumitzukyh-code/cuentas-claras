import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/proveedor_repository.dart';
import '../domain/proveedor.dart';
import '../../../shared/utils/errores.dart';

/// Anotar compra a crédito o pago a un proveedor (réplica visual de
/// `P2/P3 · NUEVA DEUDA / REGISTRAR PAGO`, `Lote H · Cierre y Proveedores`).
class AnotarMovimientoProveedorScreen extends ConsumerStatefulWidget {
  const AnotarMovimientoProveedorScreen({
    super.key,
    this.proveedorPreseleccionado,
    this.tipoInicial = TipoMovimientoProveedor.compra,
  });

  final Proveedor? proveedorPreseleccionado;
  final TipoMovimientoProveedor tipoInicial;

  @override
  ConsumerState<AnotarMovimientoProveedorScreen> createState() =>
      _AnotarMovimientoProveedorScreenState();
}

class _AnotarMovimientoProveedorScreenState
    extends ConsumerState<AnotarMovimientoProveedorScreen> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _monto = TextEditingController();
  final _concepto = TextEditingController();
  final _diasVencimiento = TextEditingController(text: '15');

  late TipoMovimientoProveedor _tipo = widget.tipoInicial;
  Proveedor? _proveedorSeleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final pre = widget.proveedorPreseleccionado;
    if (pre != null) {
      _proveedorSeleccionado = pre;
      _nombre.text = pre.nombre;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _monto.dispose();
    _concepto.dispose();
    _diasVencimiento.dispose();
    super.dispose();
  }

  double? get _montoValor => double.tryParse(_monto.text.replaceAll(',', '.'));

  bool get _puedeGuardar =>
      _nombre.text.trim().isNotEmpty && _montoValor != null && _montoValor! > 0 && !_guardando;

  Future<void> _guardar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final monto = _montoValor;
    if (membresia == null || user == null || monto == null) return;

    setState(() => _guardando = true);
    try {
      final repo = ref.read(proveedorRepositoryProvider);
      final proveedorId = _proveedorSeleccionado?.id ??
          await repo.buscarOCrearProveedor(
            membresia.negocioId,
            nombre: _nombre.text,
            telefono: _telefono.text,
          );

      DateTime? vencimiento;
      if (_tipo == TipoMovimientoProveedor.compra) {
        final dias = int.tryParse(_diasVencimiento.text) ?? 0;
        if (dias > 0) vencimiento = DateTime.now().add(Duration(days: dias));
      }

      await repo.registrarMovimiento(
        membresia.negocioId,
        proveedorId,
        tipo: _tipo,
        montoUSD: monto,
        concepto: _concepto.text.trim(),
        registradoPor: user.uid,
        vencimiento: vencimiento,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeDeError(e, accion: 'guardar'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasa = ref.watch(tasaActivaValorProvider);
    final monto = _montoValor;
    final bloqueado = widget.proveedorPreseleccionado != null;
    final sugerencias = bloqueado
        ? const <Proveedor>[]
        : (ref.watch(proveedoresProvider).valueOrNull ?? const [])
            .where((p) =>
                _proveedorSeleccionado == null &&
                _nombre.text.trim().isNotEmpty &&
                p.nombre.toLowerCase().contains(_nombre.text.trim().toLowerCase()))
            .take(4)
            .toList();

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(oscuro: true, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Text(
                    'Nuevo movimiento',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte, letterSpacing: -0.4),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: context.libreta.bordeSuave, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: _Pestana(
                        texto: 'Comprar',
                        activa: _tipo == TipoMovimientoProveedor.compra,
                        onTap: () => setState(() => _tipo = TipoMovimientoProveedor.compra),
                      ),
                    ),
                    Expanded(
                      child: _Pestana(
                        texto: 'Pagar',
                        activa: _tipo == TipoMovimientoProveedor.pago,
                        onTap: () => setState(() => _tipo = TipoMovimientoProveedor.pago),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text('Proveedor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted)),
              const SizedBox(height: 6),
              LibretaInput(
                controller: _nombre,
                hint: 'Nombre del proveedor',
                enabled: !bloqueado,
                onChanged: (_) => setState(() => _proveedorSeleccionado = null),
              ),
              if (sugerencias.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(color: context.libreta.superficie, border: Border.all(color: context.libreta.bordeSuave), borderRadius: BorderRadius.circular(13)),
                  child: Column(
                    children: [
                      for (final p in sugerencias)
                        InkWell(
                          onTap: () => setState(() {
                            _proveedorSeleccionado = p;
                            _nombre.text = p.nombre;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(color: LibretaColors.tarjetaOscura, shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text(p.iniciales, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(p.nombre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte))),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              // Solo al crear uno nuevo: si ya existe, su teléfono se edita
              // desde su ficha, no desde el formulario de un movimiento.
              if (_proveedorSeleccionado == null && !bloqueado) ...[
                Text('WhatsApp del proveedor (opcional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted)),
                const SizedBox(height: 6),
                LibretaInput(
                  controller: _telefono,
                  hint: '0414 123 4567',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sirve para mandarle el pedido de reabastecimiento con un toque.',
                  style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
                ),
              ],
              const SizedBox(height: 16),

              Text('Monto (USD)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted)),
              const SizedBox(height: 6),
              LibretaInput(
                controller: _monto,
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              if (monto != null && monto > 0 && tasa != null) ...[
                const SizedBox(height: 6),
                Text(MoneyFormatter.usdComoBs(monto, tasa), style: TextStyle(fontSize: 12, color: context.libreta.textoMuted)),
              ],

              const SizedBox(height: 16),
              Text('Concepto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted)),
              const SizedBox(height: 6),
              LibretaInput(
                controller: _concepto,
                hint: _tipo == TipoMovimientoProveedor.compra ? 'Ej: pedido semanal' : 'Ej: pago móvil',
              ),

              if (_tipo == TipoMovimientoProveedor.compra) ...[
                const SizedBox(height: 16),
                Text('Vence en (días)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted)),
                const SizedBox(height: 6),
                LibretaInput(
                  controller: _diasVencimiento,
                  hint: '15',
                  keyboardType: TextInputType.number,
                ),
              ],

              const SizedBox(height: 24),
              LibretaButton(
                label: _tipo == TipoMovimientoProveedor.compra ? 'Anotar deuda' : 'Registrar pago',
                loading: _guardando,
                onPressed: _puedeGuardar ? _guardar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({required this.texto, required this.activa, required this.onTap});

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: activa ? LibretaColors.tarjetaOscura : Colors.transparent, borderRadius: BorderRadius.circular(9)),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(fontSize: 14, fontWeight: activa ? FontWeight.w800 : FontWeight.w700, color: activa ? Colors.white : context.libreta.textoMuted),
        ),
      ),
    );
  }
}
