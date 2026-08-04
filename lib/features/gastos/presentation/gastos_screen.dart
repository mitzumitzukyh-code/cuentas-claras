import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/estado_carga.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';
import 'gasto_detalle_screen.dart';
import '../../../shared/utils/errores.dart';

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
        SnackBar(content: Text(mensajeDeError(e, accion: 'eliminar el gasto'))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esDueno = ref.watch(esDuenoProvider);
    final mes = ref.watch(mesGastosProvider);
    final gastosAsync = ref.watch(gastosDelMesElegidoProvider);
    final gastos = gastosAsync.valueOrNull ?? const <Gasto>[];
    // Cargando, error y vacío son tres cosas distintas: un fallo de lectura no
    // puede verse igual que "no hay gastos".
    final cargando = gastosAsync.isLoading && !gastosAsync.hasValue;
    final fallo = gastosAsync.hasError && !gastosAsync.hasValue;
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
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.libreta.textoFuerte,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              _SelectorMes(mes: mes, total: total),
              const SizedBox(height: 6),
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

              if (cargando)
                const LibretaCargando()
              else if (fallo)
                LibretaErrorCarga(
                  mensaje: 'No pudimos cargar tus gastos. Revisa tu internet '
                      'e intenta de nuevo.',
                  detalleTecnico: gastosAsync.error,
                  onReintentar: () =>
                      ref.invalidate(gastosDelMesElegidoProvider),
                )
              else if (gastos.isEmpty)
                LibretaEstadoVacio(
                  ilustracion: Ilustracion.sinReportes,
                  titulo: 'Aún no registras gastos este mes',
                  detalle: 'Registra lo que compras y paga el negocio para '
                      'saber cuánto te queda de verdad.',
                  tagline: 'cada gasto cuenta',
                  boton: LibretaButton(
                    label: 'Registrar gasto',
                    onPressed: () => context.push(Routes.nuevoGasto),
                  ),
                )
              else ...[
                // El diseño rotula el bloque con el mes: sin él la lista
                // arranca en seco y no dice de cuándo es lo que se ve.
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_mesEnLetras(mes)} ${mes.year}'.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ),
                for (var i = 0; i < gastos.length; i++)
                  _FilaGasto(
                    gasto: gastos[i],
                    ultima: i == gastos.length - 1,
                    onEliminar: () => _confirmarEliminar(context, ref, gastos[i]),
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            GastoDetalleScreen(gastoInicial: gastos[i]),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const _mesesCortos = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _mesEnLetras(DateTime f) => _meses[f.month - 1];

/// Quita el emoji de `categoriaLabel` — el ícono ya se dibuja aparte.
String _sinEmoji(String etiqueta) =>
    etiqueta.replaceFirst(RegExp(r'^\S+\s'), '').toLowerCase();

class _FilaGasto extends StatelessWidget {
  const _FilaGasto({
    required this.gasto,
    required this.ultima,
    required this.onEliminar,
    required this.onTap,
  });

  final Gasto gasto;
  final bool ultima;
  final VoidCallback onEliminar;
  final VoidCallback onTap;

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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                  '${f.day} ${_mesesCortos[f.month - 1]} · ${_sinEmoji(gasto.categoriaLabel)}',
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
            icon: LibretaIcono(AppAssets.accEliminar,
              size: 18,
              color: context.libreta.textoMuted,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Navegación por mes: `‹ agosto 2026 · −$104,86 ›`.
///
/// Solo por mes, sin rango libre: un bodeguero piensa en meses, y comparar mes
/// contra mes es la razón por la que alguien registra gastos. El rango libre es
/// más pantalla para un puñado de casos.
class _SelectorMes extends ConsumerWidget {
  const _SelectorMes({required this.mes, required this.total});

  final DateTime mes;
  final double total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final hoy = DateTime.now();
    // No se navega al futuro: no hay nada que ver y confunde.
    final haySiguiente = mes.year < hoy.year ||
        (mes.year == hoy.year && mes.month < hoy.month);

    void mover(int meses) {
      ref.read(mesGastosProvider.notifier).state =
          DateTime(mes.year, mes.month + meses);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => mover(-1),
            icon: Icon(Icons.chevron_left, color: t.textoFuerte),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_mesEnLetras(mes)} ${mes.year}',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
                Text(
                  '−${MoneyFormatter.usd(total)}',
                  style: AppTypography.money(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.textoMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: haySiguiente ? () => mover(1) : null,
            icon: Icon(
              Icons.chevron_right,
              color: haySiguiente ? t.textoFuerte : t.renglon,
            ),
          ),
        ],
      ),
    );
  }
}
