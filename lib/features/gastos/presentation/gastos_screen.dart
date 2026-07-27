import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';

/// Pantalla 9 — Gastos del mes (réplica visual de `P0 · GASTOS`,
/// `Lote C · Gastos y Productos`).
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
    final esDueno = ref.watch(esDuenoProvider);
    final gastos = ref.watch(gastosDelMesProvider).valueOrNull ?? const <Gasto>[];
    final total = gastos.fold<double>(0, (s, g) => s + g.monto);

    if (!esDueno) {
      return Scaffold(
        backgroundColor: context.libreta.papel,
        body: LibretaPageBackground(
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: LibretaBackButton(
                      oscuro: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.lock_outline, size: 34, color: context.libreta.textoMuted),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Los gastos del negocio solo los ve el dueño.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: context.libreta.textoMuted),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.libreta.papel,
      floatingActionButton: FloatingActionButton(
        backgroundColor: context.libreta.textoFuerte,
        shape: const CircleBorder(),
        onPressed: () => context.push(Routes.nuevoGasto),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 96),
            children: [
              Text(
                'Gastos',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.libreta.textoFuerte,
                  letterSpacing: -0.4,
                ),
              ),
              Row(
                children: [
                  Text(
                    'Este mes · ',
                    style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                  ),
                  Text(
                    '−${MoneyFormatter.usd(total)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (gastos.isEmpty)
                LibretaEstadoVacio(
                  titulo: 'Aún no registras gastos este mes',
                  detalle: 'Registra lo que compras y paga el negocio para '
                      'saber cuánto te queda de verdad.',
                  tagline: 'cada gasto cuenta',
                  boton: LibretaButton(
                    label: 'Registrar gasto',
                    onPressed: () => context.push(Routes.nuevoGasto),
                  ),
                )
              else
                for (var i = 0; i < gastos.length; i++)
                  _FilaGasto(
                    gasto: gastos[i],
                    ultima: i == gastos.length - 1,
                    onEliminar: () => _confirmarEliminar(context, ref, gastos[i]),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quita el emoji de `categoriaLabel` — el ícono ya se dibuja aparte.
String _sinEmoji(String etiqueta) =>
    etiqueta.replaceFirst(RegExp(r'^\S+\s'), '').toLowerCase();

class _FilaGasto extends StatelessWidget {
  const _FilaGasto({
    required this.gasto,
    required this.ultima,
    required this.onEliminar,
  });

  final Gasto gasto;
  final bool ultima;
  final VoidCallback onEliminar;

  IconData get _icono => switch (gasto.categoria) {
        CategoriaGasto.mercancia => Icons.inventory_2_outlined,
        CategoriaGasto.transporte => Icons.local_shipping_outlined,
        CategoriaGasto.servicios => Icons.bolt_outlined,
        CategoriaGasto.otro => Icons.schedule,
      };

  Color _colorIcono(BuildContext context) => switch (gasto.categoria) {
        CategoriaGasto.mercancia => LibretaColors.verde,
        CategoriaGasto.servicios => LibretaColors.aviso,
        _ => context.libreta.textoFuerte,
      };

  Color get _fondoIcono => switch (gasto.categoria) {
        CategoriaGasto.mercancia => const Color(0x1F0E9F6E),
        CategoriaGasto.servicios => const Color(0x26F2A93C),
        _ => const Color(0x141E2A38),
      };

  @override
  Widget build(BuildContext context) {
    final f = gasto.fecha;
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _fondoIcono,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_icono, size: 17, color: _colorIcono(context)),
          ),
          const SizedBox(width: 11),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.libreta.textoFuerte,
                  ),
                ),
                Text(
                  '${f.day}/${f.month} · ${_sinEmoji(gasto.categoriaLabel)}',
                  style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                ),
              ],
            ),
          ),
          Text(
            '−${MoneyFormatter.usd(gasto.monto)}',
            style: AppTypography.money(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.libreta.textoFuerte,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onEliminar,
            icon: Icon(
              Icons.delete_outline,
              size: 18,
              color: context.libreta.textoMuted,
            ),
          ),
        ],
      ),
    );
  }
}
