import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/cliente_fiado.dart';
import '../../../shared/utils/errores.dart';

/// Anotar fiado o abono (réplica visual de `P2 · ANOTAR FIADO/ABONO`,
/// `Lote G · Fiados`).
///
/// Si llega con [clientePreseleccionado] (desde el detalle del cliente), el
/// cliente queda fijo y no se puede cambiar. Si no, se escribe un nombre y se
/// elige entre las sugerencias o se crea uno nuevo al guardar.
class AnotarMovimientoScreen extends ConsumerStatefulWidget {
  const AnotarMovimientoScreen({
    super.key,
    this.clientePreseleccionado,
    this.tipoInicial = TipoMovimientoFiado.fiado,
  });

  final ClienteFiado? clientePreseleccionado;
  final TipoMovimientoFiado tipoInicial;

  @override
  ConsumerState<AnotarMovimientoScreen> createState() =>
      _AnotarMovimientoScreenState();
}

class _AnotarMovimientoScreenState extends ConsumerState<AnotarMovimientoScreen> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _monto = TextEditingController();
  final _concepto = TextEditingController();

  late TipoMovimientoFiado _tipo = widget.tipoInicial;
  ClienteFiado? _clienteSeleccionado;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final pre = widget.clientePreseleccionado;
    if (pre != null) {
      _clienteSeleccionado = pre;
      _nombre.text = pre.nombre;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _telefono.dispose();
    _monto.dispose();
    _concepto.dispose();
    super.dispose();
  }

  double? get _montoValor => double.tryParse(_monto.text.replaceAll(',', '.'));

  bool get _puedeGuardar =>
      _nombre.text.trim().isNotEmpty &&
      _montoValor != null &&
      _montoValor! > 0 &&
      !_guardando;

  Future<void> _guardar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final monto = _montoValor;
    if (membresia == null || user == null || monto == null) return;

    setState(() => _guardando = true);
    try {
      final repo = ref.read(fiadoRepositoryProvider);
      final clienteId = _clienteSeleccionado?.id ??
          await repo.buscarOCrearCliente(
            membresia.negocioId,
            nombre: _nombre.text,
            telefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
          );

      await repo.registrarMovimiento(
        membresia.negocioId,
        clienteId,
        tipo: _tipo,
        montoUSD: monto,
        concepto: _concepto.text.trim(),
        registradoPor: user.uid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e, accion: 'guardar'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasa = ref.watch(tasaActivaValorProvider);
    final monto = _montoValor;
    final bloqueado = widget.clientePreseleccionado != null;
    final sugerencias = bloqueado
        ? const <ClienteFiado>[]
        : (ref.watch(clientesFiadoProvider).valueOrNull ?? const [])
            .where((c) =>
                _clienteSeleccionado == null &&
                _nombre.text.trim().isNotEmpty &&
                c.nombre.toLowerCase().contains(_nombre.text.trim().toLowerCase()))
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
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Nuevo movimiento',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.libreta.bordeSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _Pestana(
                        texto: 'Fiar',
                        activa: _tipo == TipoMovimientoFiado.fiado,
                        onTap: () => setState(() => _tipo = TipoMovimientoFiado.fiado),
                      ),
                    ),
                    Expanded(
                      child: _Pestana(
                        texto: 'Abonar',
                        activa: _tipo == TipoMovimientoFiado.abono,
                        onTap: () => setState(() => _tipo = TipoMovimientoFiado.abono),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Cliente',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted),
              ),
              const SizedBox(height: 6),
              LibretaInput(
                controller: _nombre,
                hint: 'Nombre del cliente',
                enabled: !bloqueado,
                onChanged: (_) => setState(() => _clienteSeleccionado = null),
              ),
              if (sugerencias.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: context.libreta.bordeSuave),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Column(
                    children: [
                      for (final c in sugerencias)
                        InkWell(
                          onTap: () => setState(() {
                            _clienteSeleccionado = c;
                            _nombre.text = c.nombre;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: LibretaColors.tarjetaOscura,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    c.iniciales,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.nombre,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!bloqueado && _clienteSeleccionado == null) ...[
                const SizedBox(height: 12),
                LibretaInput(
                  controller: _telefono,
                  label: 'Teléfono (opcional, para recordatorios)',
                  hint: 'Ej: 584141234567',
                  keyboardType: TextInputType.phone,
                ),
              ],
              const SizedBox(height: 16),

              Text(
                'Monto (USD)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted),
              ),
              const SizedBox(height: 6),
              LibretaInput(
                controller: _monto,
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              if (monto != null && monto > 0 && tasa != null) ...[
                const SizedBox(height: 6),
                Text(
                  MoneyFormatter.usdComoBs(monto, tasa),
                  style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                ),
              ],

              if (_tipo == TipoMovimientoFiado.fiado) ...[
                const SizedBox(height: 16),
                Text(
                  'Concepto / productos',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted),
                ),
                const SizedBox(height: 6),
                LibretaInput(
                  controller: _concepto,
                  hint: 'Ej: Harina PAN ×2, aceite 1L',
                ),
              ],

              const SizedBox(height: 24),
              LibretaButton(
                label: _tipo == TipoMovimientoFiado.fiado ? 'Anotar fiado' : 'Registrar abono',
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
        decoration: BoxDecoration(
          color: activa ? LibretaColors.tarjetaOscura : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            fontWeight: activa ? FontWeight.w800 : FontWeight.w700,
            color: activa ? Colors.white : context.libreta.textoMuted,
          ),
        ),
      ),
    );
  }
}
