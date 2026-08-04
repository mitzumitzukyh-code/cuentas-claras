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
import '../../../shared/utils/errores.dart';

final _busquedaFiadosProvider = StateProvider<String>((_) => '');

/// Fiados (réplica visual de `P0 · LISTA DE FIADOS`, `Lote G · Fiados`).
///
/// Lista de clientes con deuda, más reciente primero. El total por cobrar es
/// la suma de los saldos positivos.
class FiadosScreen extends ConsumerWidget {
  const FiadosScreen({super.key});

  String _hace(DateTime f) {
    final dias = DateTime.now().difference(f).inDays;
    if (dias <= 0) return 'hoy';
    if (dias == 1) return 'ayer';
    return 'hace $dias días';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientesAsync = ref.watch(clientesFiadoProvider);
    final tasa = ref.watch(tasaActivaValorProvider);
    final busqueda = ref.watch(_busquedaFiadosProvider);

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: clientesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:
                (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      mensajeDeError(e, accion: 'cargar tus fiados'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.libreta.textoMuted),
                    ),
                  ),
                ),
            data: (todos) {
              final conDeuda = todos.where((c) => !c.saldada).toList();
              final total = conDeuda.fold<double>(0, (s, c) => s + c.saldoUSD);

              // Los que ya pagaron van al final, no desaparecen: el dueño
              // necesita poder abrirlos para mandar el comprobante o para ver
              // qué le pagaron, y antes se esfumaban de la pantalla al llegar
              // a cero. El total sigue contando solo la deuda viva.
              final saldados = todos.where((c) => c.saldada).toList();

              bool coincide(ClienteFiado c) =>
                  busqueda.isEmpty ||
                  c.nombre.toLowerCase().contains(busqueda.toLowerCase());

              final filtrados = [
                ...conDeuda.where(coincide),
                ...saldados.where(coincide),
              ];

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 100),
                    children: [
                      // Fiados no es una pestaña: se llega empujando desde
                      // Más, Cobrar o una urgencia del Inicio. Sin este botón
                      // la única salida era el gesto del sistema.
                      Row(
                        children: [
                          const LibretaBackButton(oscuro: true),
                          const SizedBox(width: 12),
                          Text(
                            'Fiados',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: context.libreta.textoFuerte,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: LibretaAvisoOfflineCompacto(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: LibretaColors.tarjetaOscura,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.libreta.bordeHero,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL POR COBRAR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Color(0x99FFFFFF),
                              ),
                            ),
                            Text(
                              MoneyFormatter.usd(total),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.6,
                              ),
                            ),
                            Text(
                              tasa == null
                                  ? '${conDeuda.length} ${conDeuda.length == 1 ? "cliente" : "clientes"}'
                                  : '${MoneyFormatter.usdComoBs(total, tasa)} · '
                                      '${conDeuda.length} ${conDeuda.length == 1 ? "cliente" : "clientes"}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xBFFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (conDeuda.isEmpty)
                        LibretaEstadoVacio(
                          ilustracion: Ilustracion.sinFiados,
                          titulo: 'Nadie te debe… por ahora',
                          detalle:
                              'Aquí verás a quién le fiaste, cuánto y '
                              'desde cuándo, para no perder la cuenta.',
                          tagline: 'cuentas claras, amistades largas',
                          boton: LibretaButton(
                            label: 'Anotar un fiado',
                            onPressed:
                                () => context.push(
                                  Routes.fiadoMovimientoDe(),
                                ),
                          ),
                        )
                      else ...[
                        _RecordatorioVencido(clientes: conDeuda),
                        Text(
                          'CLIENTES CON DEUDA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: context.libreta.textoMuted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _BuscadorFiados(),
                        const SizedBox(height: 4),
                        if (filtrados.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: LibretaEstadoVacio(
                              ilustracion: Ilustracion.sinResultados,
                              titulo: 'Sin resultados',
                              detalle:
                                  'Ningún cliente coincide con "$busqueda"',
                            ),
                          )
                        else
                          for (final c in filtrados)
                            _FilaCliente(
                              cliente: c,
                              hace: _hace(c.actualizadoEn),
                              tasa: tasa,
                              onTap:
                                  () => context.push(
                                    Routes.fiadoDetalle.replaceAll(
                                      ':clienteId',
                                      c.id,
                                    ),
                                    extra: c,
                                  ),
                            ),
                      ],
                    ],
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 16,
                    child: LibretaButton(
                      label: 'Nuevo fiado',
                      icon: const Icon(
                        Icons.add,
                        size: 19,
                        color: Colors.white,
                      ),
                      onPressed:
                          () => context.push(Routes.fiadoMovimientoDe()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Recordatorio del fiado más atrasado (Lote G · F7).
///
/// Solo aparece con deudas de [_diasParaAvisar] días o más y solo señala una
/// —la más vieja—: una lista de morosos en la pantalla principal convierte
/// Fiados en un tablero de reclamos, y el dueño deja de abrirla.
class _RecordatorioVencido extends ConsumerWidget {
  const _RecordatorioVencido({required this.clientes});

  final List<ClienteFiado> clientes;

  static const int _diasParaAvisar = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ahora = DateTime.now();
    final vencidos =
        clientes
            .where(
              (c) =>
                  ahora.difference(c.actualizadoEn).inDays >= _diasParaAvisar,
            )
            .toList()
          ..sort((a, b) => a.actualizadoEn.compareTo(b.actualizadoEn));
    if (vencidos.isEmpty) return const SizedBox.shrink();

    final c = vencidos.first;
    final dias = ahora.difference(c.actualizadoEn).inDays;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final t = context.libreta;

    Future<void> enviar() async {
      final borrador =
          'Hola ${c.nombre} 👋 te escribo de ${negocio?.nombre ?? "la bodega"}. '
          'Tienes un saldo pendiente de ${MoneyFormatter.usd(c.saldoUSD)}. '
          '¿Puedes pasar a abonar esta semana? ¡Gracias!';
      final texto = await editarMensaje(
        context,
        titulo: 'Recordatorio para ${c.nombre}',
        inicial: borrador,
      );
      if (texto == null || texto.isEmpty) return;
      final r = await abrirWhatsApp(texto: texto, telefono: c.telefono);
      final aviso = avisoDe(r);
      if (aviso != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(aviso)));
      }
    }

    // Verde, no ámbar: el diseño lo trata como una oportunidad de cobrar, no
    // como una alarma. El ámbar queda para lo que ya salió mal.
    return GestureDetector(
      onTap: enviar,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0x140E9F6E),
          border: Border.all(color: const Color(0x4D0E9F6E), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: LibretaColors.verde,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.nombre} lleva $dias días vencida',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: t.textoFuerte,
                    ),
                  ),
                  const Text(
                    'Recordatorio automático listo para enviar',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: LibretaColors.verde,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: LibretaColors.verde,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Enviar',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buscador de clientes fiados.
class _BuscadorFiados extends ConsumerWidget {
  const _BuscadorFiados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (v) => ref.read(_busquedaFiadosProvider.notifier).state = v,
      style: TextStyle(fontSize: 14, color: context.libreta.textoFuerte),
      decoration: InputDecoration(
        hintText: 'Buscar cliente…',
        hintStyle: TextStyle(color: context.libreta.textoMuted),
        prefixIcon: LibretaIcono(
          AppAssets.accBuscar,
          size: 20,
          color: context.libreta.textoMuted,
        ),
        filled: true,
        fillColor: context.libreta.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _FilaCliente extends StatelessWidget {
  const _FilaCliente({
    required this.cliente,
    required this.hace,
    required this.tasa,
    required this.onTap,
  });

  final ClienteFiado cliente;
  final String hace;
  final double? tasa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Deuda vieja (>14 días) se destaca en ámbar, como el mockup.
    final vieja = DateTime.now().difference(cliente.actualizadoEn).inDays > 14;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.libreta.renglon)),
        ),
        child: Row(
          children: [
            // Solo el vencido lleva el avatar navy: en una lista de seis, el
            // que hay que atender primero se reconoce sin leer las fechas.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    vieja
                        ? LibretaColors.tarjetaOscura
                        : context.libreta.textoFuerte.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                cliente.iniciales,
                style: TextStyle(
                  color: vieja ? Colors.white : context.libreta.textoFuerte,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                  Text(
                    hace,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          vieja
                              ? const Color(0xFFF2A93C)
                              : context.libreta.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (cliente.saldada)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: LibretaColors.verde.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Al día',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: LibretaColors.verde,
                      ),
                    ),
                  )
                else
                  Text(
                    MoneyFormatter.usd(cliente.saldoUSD),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                if (cliente.aFavor)
                  Text(
                    '${MoneyFormatter.usd(cliente.saldoAFavorUSD)} a favor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: LibretaColors.verde,
                    ),
                  )
                else if (!cliente.saldada && tasa != null)
                  Text(
                    MoneyFormatter.bs(
                      MoneyFormatter.convertirABs(cliente.saldoUSD, tasa!),
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.libreta.textoMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
