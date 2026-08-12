import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/telefono_ve.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/cliente_fiado.dart';
import '../domain/mensajes_fiado.dart';
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

  /// Pide el número y lo guarda. Devuelve el guardado, o `null` si se canceló
  /// o falló.
  ///
  /// Se valida con [normalizarTelefonoVE] antes de guardar: un número que
  /// WhatsApp no puede resolver no sirve de nada aquí, y descubrirlo al pulsar
  /// "Recordar" —que es cuando hay prisa— es tarde. Se guarda lo que el dueño
  /// escribió, no la forma normalizada: es su libreta y así lo reconoce.
  Future<String?> _pedirTelefono(ClienteFiado cliente) async {
    final ctrl = TextEditingController(text: cliente.telefono ?? '');
    final guardado = await showDialog<String>(
      context: context,
      builder: (d) {
        String? error;
        return StatefulBuilder(
          builder: (d2, setDialog) => AlertDialog(
            title: Text(
              (cliente.telefono ?? '').isEmpty
                  ? 'Teléfono de ${cliente.nombre}'
                  : 'Cambiar el teléfono',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '0414-000-0000',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sirve para mandarle el recordatorio por WhatsApp.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.libreta.textoMuted,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d2).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () {
                  final escrito = ctrl.text.trim();
                  if (normalizarTelefonoVE(escrito) == null) {
                    setDialog(() => error = 'Ese número no parece venezolano.');
                    return;
                  }
                  Navigator.of(d2).pop(escrito);
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
    ctrl.dispose();
    if (guardado == null) return null;

    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return null;
    try {
      await ref
          .read(fiadoRepositoryProvider)
          .actualizarTelefono(membresia.negocioId, cliente.id, guardado);
      return guardado;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'guardar el teléfono')),
        ),
      );
      return null;
    }
  }

  /// Manda el detalle que respalda el saldo, no solo la cifra.
  ///
  /// Un recordatorio que dice «$12,00» y nada más no le da al cliente con qué
  /// contrastarlo, y ahí es donde se pierde la confianza. Los movimientos ya
  /// estaban guardados; solo no se usaban.
  Future<void> _estadoDeCuenta(
    BuildContext context,
    ClienteFiado cliente,
    List<MovimientoFiado> movimientos,
  ) async {
    if (movimientos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavía no hay movimientos que mandar.'),
        ),
      );
      return;
    }

    var telefono = cliente.telefono;
    if ((telefono ?? '').trim().isEmpty) {
      telefono = await _pedirTelefono(cliente);
      if (telefono == null || !context.mounted) return;
    }

    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    final borrador = borradorEstadoCuenta(
      nombre: cliente.nombre,
      negocio: negocio?.nombre ?? 'nuestro negocio',
      movimientos: movimientos,
      saldoUSD: cliente.saldoUSD,
      tasa: ref.read(tasaActivaValorProvider),
    );

    if (!context.mounted) return;
    final texto = await editarMensaje(
      context,
      titulo: 'Estado de cuenta de ${cliente.nombre}',
      inicial: borrador,
    );
    if (texto == null || texto.isEmpty) return;

    final r = await abrirWhatsApp(texto: texto, telefono: telefono);
    final aviso = avisoDe(r);
    if (aviso != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aviso)));
    }
  }

  Future<void> _recordar(
    BuildContext context,
    WidgetRef ref,
    ClienteFiado cliente,
  ) async {
    var telefono = cliente.telefono;
    if ((telefono ?? '').trim().isEmpty) {
      // Antes esto era un callejón sin salida: «Este cliente no tiene teléfono
      // guardado» y a otra cosa, sin forma de arreglarlo desde ninguna
      // pantalla. Quien pulsa "Recordar" quiere recordar; se le pide el número
      // aquí mismo y se sigue.
      telefono = await _pedirTelefono(cliente);
      if (telefono == null || !context.mounted) return;
    }
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    final borrador = borradorRecordatorio(
      nombre: cliente.nombre,
      negocio: negocio?.nombre ?? 'nuestro negocio',
      saldoUSD: cliente.saldoUSD,
      tasa: ref.read(tasaActivaValorProvider),
    );

    // El camino por el que de verdad se cobra pasa ahora por la hoja de
    // edición, como ya hacían el banner de vencida y el pedido a proveedores.
    // La propia `editarMensaje` lo decía: cobrarle a alguien es delicado y el
    // tono lo pone el dueño. Aquí salía escrito por la app, y el dueño se
    // enteraba de lo que había dicho cuando ya estaba en el chat.
    if (!context.mounted) return;
    final texto = await editarMensaje(
      context,
      titulo: 'Recordatorio para ${cliente.nombre}',
      inicial: borrador,
    );
    if (texto == null || texto.isEmpty) return;

    final r = await abrirWhatsApp(texto: texto, telefono: telefono);
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
    // El orden de las dos monedas lo decide el negocio, no la pantalla.
    final (principalSaldo, secundarioSaldo) = montosDelNegocio(
      ref,
      cliente.aFavor
          ? cliente.saldoAFavorUSD
          : cliente.saldada
              ? 0
              : cliente.saldoUSD,
    );

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
                        // El teléfono se edita desde aquí. Antes solo se podía
                        // poner al crear la ficha: quien no lo tenía a mano en
                        // ese momento se quedaba sin poder mandarle nunca el
                        // recordatorio, y los clientes que entran desde el
                        // cuaderno de papel nacen todos sin número.
                        _Telefono(
                          cliente: cliente,
                          onEditar: () => _pedirTelefono(cliente),
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
                  border: Border.all(color: context.libreta.renglon),
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
                      principalSaldo,
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
                              : secundarioSaldo == null
                                  ? '—'
                                  : '$secundarioSaldo · a la tasa de hoy',
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

              const SizedBox(height: 10),
              // Va debajo de Abonar/Recordar y no como tercer botón grande: se
              // manda de vez en cuando —cuando el cliente pregunta de dónde
              // sale la cifra—, no en cada visita.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _estadoDeCuenta(
                    context,
                    cliente,
                    movimientosAsync.valueOrNull ?? const [],
                  ),
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                    size: 17,
                    color: LibretaColors.verde,
                  ),
                  label: const Text(
                    'Mandar estado de cuenta',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LibretaColors.verde,
                    ),
                  ),
                ),
              ),

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
    final borrador = borradorCuentaSaldada(
      nombre: cliente.nombre,
      negocio: negocio?.nombre ?? 'nuestro negocio',
      fechaLarga: '${hoy.day} de ${_mesesLargos[hoy.month - 1]} de ${hoy.year}',
      aFavorUSD: cliente.saldoAFavorUSD,
      tasa: ref.read(tasaActivaValorProvider),
    );

    var telefono = cliente.telefono;
    if ((telefono ?? '').trim().isEmpty) {
      if (!context.mounted) return;
      telefono = await _pedirTelefono(cliente);
      if (telefono == null || !context.mounted) return;
    }

    if (!context.mounted) return;
    final texto = await editarMensaje(
      context,
      titulo: 'Aviso para ${cliente.nombre}',
      inicial: borrador,
    );
    if (texto == null || texto.isEmpty) return;

    final r = await abrirWhatsApp(texto: texto, telefono: telefono);
    final aviso = avisoDe(r);
    if (aviso != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aviso)));
    }
  }
}

/// El teléfono bajo el nombre: se toca para ponerlo o para cambiarlo.
class _Telefono extends StatelessWidget {
  const _Telefono({required this.cliente, required this.onEditar});

  final ClienteFiado cliente;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tiene = (cliente.telefono ?? '').trim().isNotEmpty;

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: tiene
            ? 'Cambiar el teléfono de ${cliente.nombre}'
            : 'Agregar teléfono a ${cliente.nombre}',
        child: GestureDetector(
          onTap: onEditar,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            // Vertical generoso: el nombre va justo encima y sin holgura el
            // toque cae en el texto de al lado.
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tiene ? Icons.phone_outlined : Icons.add_circle_outline,
                  size: 13,
                  color: tiene ? t.textoMuted : LibretaColors.verde,
                ),
                const SizedBox(width: 5),
                Text(
                  tiene ? cliente.telefono!.trim() : 'Agregar teléfono',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tiene ? t.textoMuted : LibretaColors.verde,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _mesesLargos = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
