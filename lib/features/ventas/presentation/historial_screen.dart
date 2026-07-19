import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/neu.dart';
import '../data/venta_repository.dart';
import '../domain/venta.dart';
import 'venta_detalle_screen.dart';

/// Historial de ventas (bloque `isHistorial` del diseño).
///
/// Tarjeta verde con el total histórico y la lista completa. Las ventas
/// anuladas se muestran tachadas y atenuadas, nunca se ocultan.
class HistorialScreen extends ConsumerWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final historial = ref.watch(historialVentasProvider);

    return Scaffold(
      body: SafeArea(
        child: historial.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar el historial.\n$e',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textSec),
              ),
            ),
          ),
          data: (ventas) {
            // Las anuladas no suman al total histórico.
            final activas = ventas.where((v) => !v.anulada).toList();
            final total = activas.fold<double>(0, (s, v) => s + v.totalUSD);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Row(
                  children: [
                    NeuIconBtn(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Historial de ventas',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.marca,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: t.shadowBtn,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total histórico',
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
                        '${activas.length} '
                        '${activas.length == 1 ? "venta" : "ventas"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xD9FFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (ventas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Text('🧾', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 10),
                        Text(
                          'Aún no hay ventas registradas',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.textSec,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  NeuCard(
                    clip: true,
                    child: Column(
                      children: [
                        for (var i = 0; i < ventas.length; i++)
                          _FilaHistorial(
                            venta: ventas[i],
                            ultima: i == ventas.length - 1,
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({required this.venta, required this.ultima});

  final Venta venta;
  final bool ultima;

  String _fechaHora(DateTime f) {
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final m = f.minute.toString().padLeft(2, '0');
    final dia = '${f.day}/${f.month}/${f.year}';
    return '$dia · $h:$m ${f.hour < 12 ? "am" : "pm"}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lineas = venta.items.length;

    return Opacity(
      opacity: venta.anulada ? 0.55 : 1,
      child: NeuListTile(
        divider: !ultima,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => VentaDetalleScreen(ventaId: venta.id),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text(
                '\$',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.marca,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$lineas '
                          '${lineas == 1 ? "producto" : "productos"}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                      ),
                      if (venta.anulada)
                        const Text(
                          ' · Anulada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.peligro,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _fechaHora(venta.fecha),
                    style: TextStyle(fontSize: 12, color: t.textSec),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyFormatter.usd(venta.totalUSD),
                  style: AppTypography.money(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ).copyWith(
                    decoration:
                        venta.anulada ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  MoneyFormatter.bs(venta.totalBs),
                  style: TextStyle(fontSize: 11, color: t.textSec),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
