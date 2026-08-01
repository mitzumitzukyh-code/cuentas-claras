import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/cliente_fiado.dart';

/// Detalle de un cliente con fiado (réplica visual de `P1 · DETALLE
/// CLIENTE`, `Lote G · Fiados`).
///
/// El botón "Recordar" no abre una pantalla propia: arma el mensaje y lo
/// manda directo a WhatsApp con `wa.me` (igual que el resto de la app),
/// dejando que el dueño lo revise y edite ahí antes de enviarlo — las
/// pantallas de "chat" del mockup (P3) son solo la ilustración de eso.
class ClienteFiadoDetalleScreen extends ConsumerWidget {
  const ClienteFiadoDetalleScreen({super.key, required this.cliente});

  final ClienteFiado cliente;

  String _fechaCorta(DateTime f) {
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${f.day} ${meses[f.month - 1]}';
  }

  Future<void> _recordar(BuildContext context, WidgetRef ref) async {
    final telefono = cliente.telefono?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (telefono.isEmpty) {
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

    final uri = Uri.parse(
      'https://wa.me/$telefono?text=${Uri.encodeComponent(texto)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientosAsync = ref.watch(movimientosClienteProvider(cliente.id));
    final tasa = ref.watch(tasaActivaValorProvider);

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
                      'SALDO PENDIENTE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: context.libreta.textoMuted,
                      ),
                    ),
                    Text(
                      MoneyFormatter.usd(cliente.saldoUSD),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: context.libreta.textoFuerte,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      tasa == null
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
                      label: 'Registrar abono',
                      height: 48,
                      onPressed: () => context.push(
                        Routes.fiadoMovimiento.replaceAll(':clienteId', cliente.id),
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
                      onPressed: () => _recordar(context, ref),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
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
                  child: Text('No se pudo cargar: $e', style: TextStyle(color: context.libreta.textoMuted)),
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
    );
  }
}
