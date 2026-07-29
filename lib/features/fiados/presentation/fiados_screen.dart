import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/cliente_fiado.dart';

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
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar los fiados.\n$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.libreta.textoMuted),
                ),
              ),
            ),
            data: (todos) {
              final conDeuda = todos.where((c) => c.saldoUSD > 0).toList();
              final total = conDeuda.fold<double>(0, (s, c) => s + c.saldoUSD);

              final filtrados = busqueda.isEmpty
                  ? conDeuda
                  : conDeuda
                      .where((c) => c.nombre
                          .toLowerCase()
                          .contains(busqueda.toLowerCase()))
                      .toList();

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 100),
                    children: [
                      Text(
                        'Fiados',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.libreta.textoFuerte,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: LibretaAvisoOfflineCompacto(),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        decoration: BoxDecoration(
                          color: LibretaColors.tarjetaOscura,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.libreta.bordeHero, width: 1.5),
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
                          titulo: 'Nadie te debe… por ahora',
                          detalle: 'Aquí verás a quién le fiaste, cuánto y '
                              'desde cuándo, para no perder la cuenta.',
                          tagline: 'cuentas claras, amistades largas',
                          boton: LibretaButton(
                            label: 'Anotar un fiado',
onPressed: () => context.push(Routes.fiadoMovimiento.replaceAll(':clienteId', '')),
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
                              onTap: () => context.push(Routes.fiadoDetalle.replaceAll(':clienteId', c.id), extra: c),
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
                      icon: const Icon(Icons.add, size: 19, color: Colors.white),
                      onPressed: () => context.push(Routes.fiadoMovimiento.replaceAll(':clienteId', '')),
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
    final vencidos = clientes
        .where((c) => ahora.difference(c.actualizadoEn).inDays >= _diasParaAvisar)
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
      await abrirWhatsApp(texto: texto, telefono: c.telefono);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0x1FF2A93C),
        border: Border.all(color: const Color(0x59F2A93C)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 16,
                color: LibretaColors.aviso,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${c.nombre} lleva $dias días sin abonar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Recordatorio listo para enviar · ${MoneyFormatter.usd(c.saldoUSD)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: t.textoMuted,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: enviar,
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2A93C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Enviar recordatorio',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: LibretaColors.tarjetaOscura,
                ),
              ),
            ),
          ),
        ],
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
      style: TextStyle(
        fontSize: 14,
        color: context.libreta.textoFuerte,
      ),
      decoration: InputDecoration(
        hintText: 'Buscar cliente…',
        hintStyle: TextStyle(color: context.libreta.textoMuted),
        prefixIcon: Icon(Icons.search, size: 20, color: context.libreta.textoMuted),
        filled: true,
        fillColor: context.libreta.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: LibretaColors.tarjetaOscura,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                cliente.iniciales,
                style: const TextStyle(
                  color: Colors.white,
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
                      color: vieja ? LibretaColors.aviso : context.libreta.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormatter.usd(cliente.saldoUSD),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.libreta.textoFuerte,
                  ),
                ),
                if (tasa != null)
                  Text(
                    MoneyFormatter.bs(MoneyFormatter.convertirABs(cliente.saldoUSD, tasa!)),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.libreta.textoMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
