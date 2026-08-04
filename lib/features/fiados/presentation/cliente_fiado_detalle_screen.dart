import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/cliente_fiado.dart';
import 'widgets/overlay_cuenta_saldada.dart';
import '../../../shared/utils/errores.dart';

/// Detalle de un cliente con fiado (réplica visual de `P1 · DETALLE
/// CLIENTE`, `Lote G · Fiados`).
///
/// El botón "Recordar" no abre una pantalla propia: arma el mensaje y lo
/// manda directo a WhatsApp con `wa.me` (igual que el resto de la app),
/// dejando que el dueño lo revise y edite ahí antes de enviarlo — las
/// pantallas de "chat" del mockup (P3) son solo la ilustración de eso.
class ClienteFiadoDetalleScreen extends ConsumerStatefulWidget {
  const ClienteFiadoDetalleScreen({super.key, required this.clienteInicial});

  /// El cliente tal como venía en el `extra` de la ruta: una foto del momento
  /// de navegar. Solo se usa como valor de arranque — lo que se pinta es el
  /// cliente vivo de [clienteFiadoPorIdProvider], porque el saldo cambia sin
  /// salir de esta pantalla (se anota un abono y se vuelve aquí).
  final ClienteFiado clienteInicial;

  @override
  ConsumerState<ClienteFiadoDetalleScreen> createState() =>
      _ClienteFiadoDetalleScreenState();
}

class _ClienteFiadoDetalleScreenState
    extends ConsumerState<ClienteFiadoDetalleScreen> {
  /// `true` mientras se muestra la celebración de cuenta saldada.
  bool _celebrando = false;

  /// Si la cuenta ya estaba en cero al abrir, no se celebra: la celebración es
  /// por el abono que la salda, no por entrar a mirar una cuenta vieja.
  late bool _estabaSaldada = widget.clienteInicial.saldada;

  String _fechaCorta(DateTime f) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${f.day} ${meses[f.month - 1]}';
  }

  Future<void> _recordar(
    BuildContext context,
    WidgetRef ref,
    ClienteFiado cliente,
  ) async {
    if ((cliente.telefono ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene teléfono guardado.')),
      );
      return;
    }
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    final tasa = ref.read(tasaActivaValorProvider);
    final bs = tasa == null ? '' : ' (${MoneyFormatter.usdComoBs(cliente.saldoUSD, tasa)})';
    final texto = 'Hola ${cliente.nombre.split(' ').first} 👋 Le recordamos con '
        'cariño su saldo pendiente en ${negocio?.nombre ?? "nuestro negocio"}: '
        '${MoneyFormatter.usd(cliente.saldoUSD)}$bs. ¡Gracias por su preferencia!';

    final r = await abrirWhatsApp(texto: texto, telefono: cliente.telefono);
    final aviso = avisoDe(r);
    if (aviso != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aviso)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente =
        ref.watch(clienteFiadoPorIdProvider(widget.clienteInicial.id)) ??
            widget.clienteInicial;

    // El cruce de "debe" a "no debe" es el momento que se celebra. Se mira en
    // build y no con un listener aparte porque el saldo llega por el stream de
    // la lista: cuando el abono se escribe, este widget ya se está
    // reconstruyendo con el valor nuevo.
    if (!_estabaSaldada && cliente.saldada) {
      _estabaSaldada = true;
      _celebrando = true;
    } else if (!cliente.saldada) {
      _estabaSaldada = false;
    }
    final movimientosAsync = ref.watch(movimientosClienteProvider(cliente.id));
    final tasa = ref.watch(tasaActivaValorProvider);

    return Stack(
      children: [
        Scaffold(
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: LibretaColors.tarjetaOscura,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cliente.iniciales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.libreta.textoFuerte,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (cliente.telefono != null && cliente.telefono!.isNotEmpty)
                          Text(
                            cliente.telefono!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.libreta.textoMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      cliente.aFavor
                          ? 'SALDO A FAVOR'
                          : cliente.saldada
                              ? 'CUENTA AL DÍA'
                              : 'SALDO PENDIENTE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: cliente.saldada
                            ? LibretaColors.verde
                            : context.libreta.textoMuted,
                      ),
                    ),
                    // "A favor" se muestra en positivo. Una deuda negativa
                    // (−$3,00) se lee como un error de la app, no como crédito.
                    Text(
                      MoneyFormatter.usd(
                        cliente.aFavor
                            ? cliente.saldoAFavorUSD
                            : cliente.saldada
                                ? 0
                                : cliente.saldoUSD,
                      ),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: cliente.saldada
                            ? LibretaColors.verde
                            : context.libreta.textoFuerte,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      cliente.aFavor
                          ? 'a cuenta de su próxima compra'
                          : cliente.saldada
                              ? 'no te debe nada'
                              : tasa == null
                                  ? '—'
                                  : '${MoneyFormatter.usdComoBs(cliente.saldoUSD, tasa)} · a la tasa de hoy',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.libreta.textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: LibretaButton(
                      // "Abonar" y no "Registrar abono": con el botón de
                      // Recordar al lado, la etiqueta larga se cortaba en
                      // "Registrar ab…" en una pantalla de 900 px.
                      label: 'Abonar',
                      height: 48,
                      onPressed: () => context.push(
                        Routes.fiadoMovimientoDe(cliente.id),
                        extra: {
                          'clientePreseleccionado': cliente,
                          'tipoInicial': TipoMovimientoFiado.abono,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LibretaSecondaryButton(
                      label: 'Recordar',
                      height: 48,
                      icon: const LibretaIcono(AppAssets.accMensaje, size: 17, color: LibretaColors.verde),
                      onPressed: () => _recordar(context, ref, cliente),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _eliminar(context, cliente),
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    size: 17,
                    color: LibretaColors.peligro,
                  ),
                  label: const Text(
                    'Quitar cliente',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LibretaColors.peligro,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),
              Text(
                'MOVIMIENTOS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: context.libreta.textoMuted,
                ),
              ),
              const SizedBox(height: 4),
              movimientosAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(mensajeDeError(e, accion: 'cargar los movimientos'), style: TextStyle(color: context.libreta.textoMuted)),
                ),
                data: (movs) => movs.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Sin movimientos todavía.',
                          style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                        ),
                      )
                    : Column(
                        children: [
                          for (final m in movs)
                            Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: context.libreta.renglon)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.tipo == TipoMovimientoFiado.abono
                                              ? 'Abono'
                                              : (m.concepto.isEmpty ? 'Fiado' : m.concepto),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: context.libreta.textoFuerte,
                                          ),
                                        ),
                                        Text(
                                          _fechaCorta(m.fecha),
                                          style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    m.tipo == TipoMovimientoFiado.abono
                                        ? '−${MoneyFormatter.usd(m.montoUSD)}'
                                        : '+${MoneyFormatter.usd(m.montoUSD)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: m.tipo == TipoMovimientoFiado.abono
                                          ? LibretaColors.verde
                                          : context.libreta.textoFuerte,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
        ),
        if (_celebrando)
          OverlayCuentaSaldada(
            nombre: cliente.nombre.split(' ').first,
            saldoAFavorUSD: cliente.saldoAFavorUSD,
            onAvisar: () {
              setState(() => _celebrando = false);
              _avisarSaldada(context, cliente);
            },
            onCerrar: () => setState(() => _celebrando = false),
          ),
      ],
    );
  }

  /// Quita al cliente de la lista.
  ///
  /// No lo destruye: sus movimientos son el libro mayor de lo que le fiaste y
  /// te pagó, y las reglas de Firestore prohíben borrarlos. Se marca y deja de
  /// aparecer.
  ///
  /// Si todavía debe, el diálogo lo dice con el monto: quitarlo hace que esa
  /// deuda deje de contar en el total, y eso no puede pasar por descuido.
  Future<void> _eliminar(BuildContext context, ClienteFiado cliente) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Quitar a ${cliente.nombre}?'),
        content: Text(
          cliente.saldada
              ? 'Su cuenta está al día. Deja de aparecer en Fiados; el '
                  'historial de lo que le fiaste y te pagó no se borra.'
              : 'Todavía te debe ${MoneyFormatter.usd(cliente.saldoUSD)}. Si '
                  'lo quitas, esa deuda deja de contar en tu total por cobrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: TextButton.styleFrom(foregroundColor: LibretaColors.peligro),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;
    try {
      await ref
          .read(fiadoRepositoryProvider)
          .eliminarCliente(membresia.negocioId, cliente.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${cliente.nombre} ya no aparece en Fiados.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeDeError(e, accion: 'quitar el cliente'))),
      );
    }
  }

  /// El comprobante de que la cuenta quedó en cero.
  ///
  /// Va por el mismo `wa.me` que el resto: al chat directo, esté o no el
  /// cliente en la agenda. Sin teléfono guardado no hay a quién escribirle y se
  /// dice, en vez de abrir el selector de contactos.
  Future<void> _avisarSaldada(BuildContext context, ClienteFiado cliente) async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    final hoy = DateTime.now();
    final fecha = '${hoy.day} de ${_mesesLargos[hoy.month - 1]} de ${hoy.year}';

    final extra = cliente.aFavor
        ? ' Además le quedan ${MoneyFormatter.usd(cliente.saldoAFavorUSD)} a '
            'favor para su próxima compra.'
        : '';
    final texto =
        'Hola ${cliente.nombre.split(' ').first} 👋 Su cuenta en '
        '${negocio?.nombre ?? "nuestro negocio"} quedó en CERO hoy, $fecha. '
        '¡Gracias por su pago!$extra';

    if ((cliente.telefono ?? '').trim().isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente no tiene teléfono guardado.'),
        ),
      );
      return;
    }

    final r = await abrirWhatsApp(texto: texto, telefono: cliente.telefono);
    final aviso = avisoDe(r);
    if (aviso != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aviso)));
    }
  }
}

const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
