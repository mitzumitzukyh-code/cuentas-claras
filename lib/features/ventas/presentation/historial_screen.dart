import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/venta_repository.dart';
import '../domain/filtro_ventas.dart';
import '../domain/venta.dart';
import 'filtro_ventas_screen.dart';

/// Historial de ventas (réplica visual de `P1 · HISTORIAL`, `Lote B ·
/// Ventas`, con el filtro de `P1 · FILTROS`, `Lote L · Búsqueda y Datos`).
///
/// Tarjeta verde con el total histórico y la lista agrupada por día. Las
/// ventas anuladas se muestran tachadas y atenuadas, nunca se ocultan.
class HistorialScreen extends ConsumerStatefulWidget {
  const HistorialScreen({super.key});

  @override
  ConsumerState<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends ConsumerState<HistorialScreen> {
  FiltroVentas _filtro = const FiltroVentas(periodo: PeriodoFiltroVenta.personalizado);

  Future<void> _filtrar(List<Venta> todas) async {
    final resultado = await Navigator.of(context).push<FiltroVentas>(
      MaterialPageRoute(
        builder: (_) => FiltroVentasScreen(ventas: todas, inicial: _filtro),
      ),
    );
    if (resultado != null && mounted) setState(() => _filtro = resultado);
  }

  String _tituloDia(DateTime f) {
    final hoy = DateTime.now();
    final d = DateTime(f.year, f.month, f.day);
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final dif = h.difference(d).inDays;
    if (dif == 0) return 'Hoy · ${_diaMes(f)}';
    if (dif == 1) return 'Ayer · ${_diaMes(f)}';
    return _diaMes(f);
  }

  String _diaMes(DateTime f) {
    const dias = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
    ];
    return '${dias[f.weekday - 1]} ${f.day}';
  }

  String _hora(DateTime f) {
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final m = f.minute.toString().padLeft(2, '0');
    return '$h:$m ${f.hour < 12 ? "am" : "pm"}';
  }

  String _resumenFiltro() {
    final partes = <String>[
      if (_filtro.periodo != PeriodoFiltroVenta.personalizado ||
          (_filtro.personalizadoDesde != null && _filtro.personalizadoHasta != null))
        _filtro.periodo.etiqueta,
      if (_filtro.metodo != null) _filtro.metodo!.etiquetaCorta,
      if (_filtro.estado != EstadoFiltroVenta.todas) _filtro.estado.etiqueta,
    ];
    return partes.isEmpty ? 'Filtrado' : partes.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final historial = ref.watch(historialVentasProvider);

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: historial.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo cargar el historial.\n$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.libreta.textoMuted),
                ),
              ),
            ),
            data: (ventas) {
              final activas = ventas.where((v) => !v.anulada).toList();
              // "Esta semana" = últimos 7 días corridos, no la semana
              // calendario: a media semana el dueño quiere saber cuánto lleva
              // vendido, no cuánto va del lunes.
              final desde = DateTime.now().subtract(const Duration(days: 7));
              final totalSemana = activas
                  .where((v) => v.fecha.isAfter(desde))
                  .fold<double>(0, (s, v) => s + v.totalUSD);
              final visibles = ventas.where(_filtro.aplicaA).toList();

              // Agrupa por día conservando el orden (ya viene más reciente
              // primero desde el repositorio).
              final grupos = <String, List<Venta>>{};
              for (final v in visibles) {
                grupos.putIfAbsent(_tituloDia(v.fecha), () => []).add(v);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
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
                              'Historial',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: context.libreta.textoFuerte,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Esta semana · '),
                                  TextSpan(
                                    text: MoneyFormatter.usd(totalSemana),
                                    style: const TextStyle(
                                      color: LibretaColors.verde,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LibretaIconButton(
                        icon: Icons.tune,
                        onTap: () => _filtrar(ventas),
                      ),
                    ],
                  ),
                  if (!_filtro.esNeutro) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0x1F0E9F6E),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _resumenFiltro(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: LibretaColors.verde),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(
                                () => _filtro = const FiltroVentas(periodo: PeriodoFiltroVenta.personalizado),
                              ),
                              child: const Icon(Icons.close, size: 14, color: LibretaColors.verde),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // El diseño retiró la tarjeta verde de "total histórico":
                  // el encabezado ya lleva el número que importa ("Esta
                  // semana"), y la lista arranca directo.
                  const SizedBox(height: 8),

                  if (ventas.isEmpty)
                    LibretaEstadoVacio(
                      titulo: 'Aún no registras ventas hoy',
                      detalle: 'Cuando cobres, tus ventas del día aparecerán '
                          'aquí, sumadas solas.',
                      tagline: 'tu primera venta te espera',
                      boton: LibretaButton(
                        label: 'Cobrar ahora',
                        icon: const Icon(Icons.point_of_sale_outlined, size: 19, color: Colors.white),
                        onPressed: () => context.push(Routes.cobrar),
                      ),
                    )
                  else if (visibles.isEmpty)
                    LibretaEstadoVacio(
                      busqueda: true,
                      titulo: 'Sin ventas con este filtro',
                      detalle: 'Prueba con otro período, método de pago o estado.',
                      boton: LibretaSecondaryButton(
                        label: 'Limpiar filtro',
                        onPressed: () => setState(
                          () => _filtro = const FiltroVentas(periodo: PeriodoFiltroVenta.personalizado),
                        ),
                      ),
                    )
                  else
                    for (final entrada in grupos.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 4),
                        child: Text(
                          entrada.key.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: context.libreta.textoMuted,
                          ),
                        ),
                      ),
                      for (final v in entrada.value)
                        _FilaHistorial(
                          venta: v,
                          hora: _hora(v.fecha),
                        ),
                      const SizedBox(height: 12),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilaHistorial extends StatelessWidget {
  const _FilaHistorial({required this.venta, required this.hora});

  final Venta venta;
  final String hora;

  @override
  Widget build(BuildContext context) {
    final lineas = venta.items.length;

    return Opacity(
      opacity: venta.anulada ? 0.55 : 1,
      child: InkWell(
        onTap: () => context.push(Routes.ventaDetalle.replaceAll(':ventaId', venta.id)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.libreta.renglon)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            venta.items.first.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.libreta.textoFuerte,
                            ),
                          ),
                        ),
                        if (venta.anulada)
                          const Text(
                            ' · anulada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.peligro,
                            ),
                          )
                        else if (venta.pendiente)
                          const Text(
                            ' · sin confirmar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.aviso,
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '$hora · ${venta.metodoPago.etiquetaCorta} · '
                      '$lineas ${lineas == 1 ? "item" : "items"}',
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
                '+${MoneyFormatter.usd(venta.totalUSD)}',
                style: AppTypography.money(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: venta.anulada
                      ? context.libreta.textoMuted
                      : LibretaColors.verde,
                ).copyWith(
                  decoration:
                      venta.anulada ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
