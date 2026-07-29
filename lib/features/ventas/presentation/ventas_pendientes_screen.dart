import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/venta_repository.dart';
import '../domain/venta.dart';

/// Ventas guardadas sin señal (réplica visual de `P3 · PENDIENTES`,
/// `Lote B · Ventas`).
///
/// No es una cola que la app administre a mano: Firestore ya las sincroniza
/// sola en cuanto detecta conexión. Esta pantalla existe para que el dueño
/// —sobre todo con varios vendedores— vea qué falta subir en vez de tener que
/// confiar a ciegas en que "en algún momento se sube sola".
class VentasPendientesScreen extends ConsumerStatefulWidget {
  const VentasPendientesScreen({super.key});

  @override
  ConsumerState<VentasPendientesScreen> createState() =>
      _VentasPendientesScreenState();
}

class _VentasPendientesScreenState
    extends ConsumerState<VentasPendientesScreen> {
  bool _sincronizando = false;

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    final ok = await ref.read(ventaRepositoryProvider).sincronizarAhora();
    if (!mounted) return;
    setState(() => _sincronizando = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Todo sincronizado.'
              : 'Todavía sin señal. Se seguirá intentando solo.',
        ),
        backgroundColor: ok ? AppColors.marca : AppColors.aviso,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = ref.watch(ventasPendientesProvider);
    final total = pendientes.fold<double>(0, (s, v) => s + v.totalUSD);

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pendientes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: context.libreta.textoFuerte,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${pendientes.length} '
                          '${pendientes.length == 1 ? "venta sin sincronizar" : "ventas sin sincronizar"}',
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

              if (pendientes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 34,
                        color: LibretaColors.verde,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Todo sincronizado',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.libreta.textoFuerte,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No hay ventas esperando por conexión.',
                        style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                      ),
                    ],
                  ),
                )
              else ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x21F2A93C),
                    border: Border.all(color: const Color(0x59F2A93C)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, size: 19, color: LibretaColors.aviso),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Sin conexión — se guardan aquí y se suben solas '
                          'al volver el internet.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: LibretaColors.aviso,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                for (final v in pendientes) _TarjetaPendiente(venta: v),

                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: LibretaColors.verde,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Esperando señal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xD9FFFFFF),
                              ),
                            ),
                            Text(
                              MoneyFormatter.usd(total),
                              style: AppTypography.money(
                                fontSize: 22,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${pendientes.length} '
                        '${pendientes.length == 1 ? "venta" : "ventas"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xD9FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                LibretaButton(
                  label: _sincronizando ? 'Comprobando…' : 'Sincronizar ahora',
                  loading: _sincronizando,
                  onPressed: _sincronizando ? null : _sincronizar,
                  icon: const Icon(Icons.sync, size: 19, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de una venta pendiente, con la etiqueta rotada tipo post-it.
class _TarjetaPendiente extends StatelessWidget {
  const _TarjetaPendiente({required this.venta});

  final Venta venta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => context.push(Routes.ventaDetalle.replaceAll(':ventaId', venta.id)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: context.libreta.superficie,
                border: Border.all(color: const Color(0x141E2A38)),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          venta.items.first.nombre,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.libreta.textoFuerte,
                          ),
                        ),
                        Text(
                          'hoy · ${venta.metodoPago.etiquetaCorta.toLowerCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.libreta.textoMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    MoneyFormatter.usd(venta.totalUSD),
                    style: AppTypography.money(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -9,
              right: 14,
              child: Transform.rotate(
                angle: 0.05,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEFB4),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E1E2A38),
                        offset: Offset(1, 3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    'pendiente de sincronizar',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A7B1A),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
