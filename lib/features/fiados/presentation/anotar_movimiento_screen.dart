import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/numero_ve.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/cliente_fiado.dart';
import '../domain/mensajes_fiado.dart';
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

  /// Por `normalizarNumeroVE`: con `replaceAll(',', '.')` un fiado de
  /// "1.500" se anotaba como 1,5 —el punto se tomaba por decimal— en un libro
  /// mayor que nunca se edita ni se borra.
  double? get _montoValor => normalizarNumeroVE(_monto.text);

  bool get _puedeGuardar =>
      _nombre.text.trim().isNotEmpty &&
      _montoValor != null &&
      _montoValor! > 0 &&
      !_guardando;

  /// Tras un abono, ofrece mandarle el comprobante al cliente.
  ///
  /// Es el único mensaje de todos los que manda la app que no le pide nada al
  /// cliente, y el que más confianza construye. Antes solo se avisaba al
  /// llegar a cero, así que quien abonaba $5 de $20 —justo al que conviene
  /// reforzarle la costumbre— no recibía constancia de nada.
  ///
  /// **Solo si el cliente tiene teléfono guardado.** Con el cliente delante y
  /// otro esperando, una hoja que hay que despachar en cada abono es fricción
  /// pura; a quien tiene número guardado es a quien el dueño ya le escribe.
  /// Los demás se cubren desde el detalle del cliente, que ahora deja poner el
  /// teléfono.
  Future<void> _ofrecerComprobante(
    String clienteId,
    double abono,
    double saldoAntes,
  ) async {
    if (_tipo != TipoMovimientoFiado.abono) return;

    final cliente = ref.read(clienteFiadoPorIdProvider(clienteId));
    if (cliente == null) return;
    final telefono = cliente.telefono;
    if ((telefono ?? '').trim().isEmpty) return;

    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    // El saldo se calcula desde el de ANTES de escribir el movimiento y no
    // desde `cliente.saldoUSD`, que llega por el stream.
    //
    // Se probó en dispositivo y salía mal: Firestore aplica `increment` en
    // local al instante, así que para cuando se lee aquí el stream ya trae el
    // abono descontado — restarlo otra vez lo contaba dos veces. Con un fiado
    // de $20 y un abono de $5, el mensaje le decía al cliente que le quedaban
    // $10 en vez de $15. Un mensaje que va por WhatsApp con el nombre del
    // negocio encima y le perdona $5 a alguien por escrito.
    //
    // Desde el saldo de antes la cuenta es determinista y no depende de en qué
    // momento emita el stream.
    final restante = saldoAntes - abono;
    final borrador = borradorAbono(
      nombre: cliente.nombre,
      negocio: negocio?.nombre ?? 'nuestro negocio',
      abonoUSD: abono,
      saldoRestanteUSD: restante,
      tasa: ref.read(tasaActivaValorProvider),
    );

    if (!mounted) return;
    final texto = await editarMensaje(
      context,
      titulo: 'Comprobante para ${cliente.nombre}',
      inicial: borrador,
      accion: 'Mandar comprobante',
    );
    if (texto == null || texto.isEmpty || !mounted) return;

    final r = await abrirWhatsApp(texto: texto, telefono: telefono);
    final aviso = avisoDe(r);
    if (aviso != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aviso)));
    }
  }

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

      // Se lee ANTES de escribir: en cuanto el movimiento se registra, el
      // stream ya trae el saldo nuevo y deja de servir para saber de dónde se
      // partía.
      final saldoAntes = ref.read(clienteFiadoPorIdProvider(clienteId))?.saldoUSD ??
          _clienteSeleccionado?.saldoUSD ??
          0;

      await repo.registrarMovimiento(
        membresia.negocioId,
        clienteId,
        tipo: _tipo,
        montoUSD: monto,
        concepto: _concepto.text.trim(),
        registradoPor: user.uid,
      );
      if (!mounted) return;
      await _ofrecerComprobante(clienteId, monto, saldoAntes);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e, accion: 'guardar el movimiento'))),
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
