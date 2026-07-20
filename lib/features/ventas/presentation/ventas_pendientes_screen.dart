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

/// Ventas guardadas sin señal y todavía sin confirmar con el servidor.
///
/// No es una cola que la app administre a mano: Firestore ya las sincroniza
/// solo en cuanto detecta conexión. Esta pantalla existe para que el dueño
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
    final t = context.tokens;
    final pendientes = ref.watch(ventasPendientesProvider);
    final total = pendientes.fold<double>(0, (s, v) => s + v.totalUSD);

    return Scaffold(
      body: SafeArea(
        child: ListView(
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
                    'Ventas pendientes',
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

            if (pendientes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 34)),
                    const SizedBox(height: 12),
                    Text(
                      'Todo sincronizado',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No hay ventas esperando por conexión.',
                      style: TextStyle(fontSize: 13, color: t.textSec),
                    ),
                  ],
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.aviso,
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
              const SizedBox(height: 12),
              Text(
                'Estas ventas ya descontaron el stock en este teléfono. Se '
                'confirmarán con el servidor solas en cuanto haya señal — no '
                'hace falta hacer nada, pero puedes revisar aquí qué falta.',
                style: TextStyle(fontSize: 12.5, color: t.textSec, height: 1.4),
              ),
              const SizedBox(height: 16),

              NeuCard(
                clip: true,
                child: Column(
                  children: [
                    for (var i = 0; i < pendientes.length; i++)
                      _FilaPendiente(
                        venta: pendientes[i],
                        ultima: i == pendientes.length - 1,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              NeuButton(
                label: _sincronizando ? 'Comprobando…' : '🔄 Sincronizar ahora',
                onPressed: _sincronizando ? null : _sincronizar,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilaPendiente extends StatelessWidget {
  const _FilaPendiente({required this.venta, required this.ultima});

  final Venta venta;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuListTile(
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
            decoration:
                BoxDecoration(color: AppColors.avisoSuave, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('⏳', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${venta.items.length} '
                  '${venta.items.length == 1 ? "producto" : "productos"}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                Text(
                  'Sin confirmar todavía',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.aviso,
                  ),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.usd(venta.totalUSD),
            style: AppTypography.money(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}
