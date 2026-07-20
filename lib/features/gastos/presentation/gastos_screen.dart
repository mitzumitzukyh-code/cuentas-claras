import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';
import 'registrar_gasto_screen.dart';

/// Pantalla 9 — Gastos del mes.
///
/// Información financiera: solo el dueño (las reglas de Firestore lo exigen
/// además de esta pantalla).
class GastosScreen extends ConsumerWidget {
  const GastosScreen({super.key});

  Future<void> _confirmarEliminar(
    BuildContext context,
    WidgetRef ref,
    Gasto gasto,
  ) async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Eliminar este gasto?'),
        content: Text(
          '${gasto.descripcion.isEmpty ? gasto.categoriaLabel : gasto.descripcion} '
          '· ${MoneyFormatter.usd(gasto.monto)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;

    try {
      final ok = await ref
          .read(gastoRepositoryProvider)
          .eliminar(membresia.negocioId, gasto.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Gasto eliminado'
            : 'Eliminado sin señal. Se sincroniza solo al volver la conexión.'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final esDueno = ref.watch(esDuenoProvider);
    final gastos = ref.watch(gastosDelMesProvider).valueOrNull ?? const <Gasto>[];
    final total = gastos.fold<double>(0, (s, g) => s + g.monto);

    if (!esDueno) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: NeuIconBtn(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              const Spacer(),
              const Text('🔒', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Los gastos del negocio solo los ve el dueño.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: t.textSec),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.marca,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RegistrarGastoScreen(),
          ),
        ),
        label: const Text(
          'Registrar gasto',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
          children: [
            Row(
              children: [
                NeuIconBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  'Gastos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastado este mes',
                    style: TextStyle(fontSize: 12, color: t.textSec),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormatter.usd(total),
                    style: AppTypography.money(fontSize: 24, color: t.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${gastos.length} ${gastos.length == 1 ? "gasto" : "gastos"}',
                    style: TextStyle(fontSize: 12, color: t.textSec),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (gastos.isEmpty)
              NeuCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  children: [
                    const Text('🧾', style: TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      'Aún no registras gastos este mes',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: t.textSec,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Registra lo que compras y paga el negocio para saber '
                      'cuánto te queda de verdad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: t.textSec),
                    ),
                  ],
                ),
              )
            else
              NeuCard(
                clip: true,
                child: Column(
                  children: [
                    for (var i = 0; i < gastos.length; i++)
                      _FilaGasto(
                        gasto: gastos[i],
                        ultima: i == gastos.length - 1,
                        onEliminar: () =>
                            _confirmarEliminar(context, ref, gastos[i]),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaGasto extends StatelessWidget {
  const _FilaGasto({
    required this.gasto,
    required this.ultima,
    required this.onEliminar,
  });

  final Gasto gasto;
  final bool ultima;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final f = gasto.fecha;
    return NeuListTile(
      divider: !ultima,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gasto.descripcion.isEmpty
                      ? gasto.categoriaLabel
                      : gasto.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                Text(
                  '${gasto.categoriaLabel} · ${f.day}/${f.month}/${f.year}',
                  style: TextStyle(fontSize: 12, color: t.textSec),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.usd(gasto.monto),
            style: AppTypography.money(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onEliminar,
            icon: Icon(Icons.delete_outline, size: 18, color: t.textSec),
          ),
        ],
      ),
    );
  }
}
