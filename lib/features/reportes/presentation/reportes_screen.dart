import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../ventas/domain/venta.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../data/balance_acumulado_provider.dart';
import '../data/reportes_providers.dart';
import '../domain/periodo_reporte.dart';
import 'exportar_reporte_screen.dart';
import 'widgets/grafico_linea.dart';

/// Reportes de ventas (réplica visual de `P0 · REPORTES`, `Lote N ·
/// Reportes y Más`).
///
/// Solo para el dueño: es información financiera (CLAUDE.md §6).
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  PeriodoReporte _periodo = PeriodoReporte.mes;

  static const _segmentos = [
    PeriodoReporte.semana,
    PeriodoReporte.mes,
    PeriodoReporte.ano,
  ];

  List<PuntoGrafico> _serie(List<Venta> ventas) {
    final hoy = DateTime.now();
    switch (_periodo) {
      case PeriodoReporte.hoy:
      case PeriodoReporte.semana:
        final lunes = DateTime(hoy.year, hoy.month, hoy.day)
            .subtract(Duration(days: hoy.weekday - 1));
        const nombres = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
        return List.generate(7, (i) {
          final dia = lunes.add(Duration(days: i));
          final siguiente = dia.add(const Duration(days: 1));
          final total = ventas
              .where((v) => !v.fecha.isBefore(dia) && v.fecha.isBefore(siguiente))
              .fold<double>(0, (s, v) => s + v.totalUSD);
          return PuntoGrafico(nombres[i], total);
        });
      case PeriodoReporte.mes:
        final inicioMes = DateTime(hoy.year, hoy.month);
        final finMes = DateTime(hoy.year, hoy.month + 1);
        final semanas = <PuntoGrafico>[];
        var cursor = inicioMes;
        var i = 1;
        while (cursor.isBefore(finMes)) {
          final fin = cursor.add(const Duration(days: 7));
          final finReal = fin.isBefore(finMes) ? fin : finMes;
          final total = ventas
              .where((v) => !v.fecha.isBefore(cursor) && v.fecha.isBefore(finReal))
              .fold<double>(0, (s, v) => s + v.totalUSD);
          semanas.add(PuntoGrafico('Sem $i', total));
          cursor = fin;
          i++;
        }
        return semanas;
      case PeriodoReporte.ano:
        const meses = [
          'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
        ];
        return List.generate(12, (i) {
          final inicio = DateTime(hoy.year, i + 1);
          final fin = DateTime(hoy.year, i + 2);
          final total = ventas
              .where((v) => !v.fecha.isBefore(inicio) && v.fecha.isBefore(fin))
              .fold<double>(0, (s, v) => s + v.totalUSD);
          return PuntoGrafico(meses[i], total);
        });
    }
  }

  /// Agrupa las líneas de venta por producto y las ordena por facturación.
  ///
  /// El descuento y el IVA de cada venta se reparten entre sus líneas en
  /// proporción a lo que pesan. Así la suma de "más vendidos" cuadra con el
  /// total del periodo, en vez de mostrar el precio de lista y descuadrar.
  List<_TopProducto> _masVendidos(List<Venta> ventas) {
    final acumulado = <String, _TopProducto>{};
    for (final v in ventas) {
      final bruto = v.subtotalUSD;
      final factor = bruto == 0 ? 1.0 : v.totalUSD / bruto;
      for (final item in v.items) {
        final actual = acumulado[item.nombre];
        acumulado[item.nombre] = _TopProducto(
          nombre: item.nombre,
          unidades: (actual?.unidades ?? 0) + item.cantidad,
          total: (actual?.total ?? 0) + item.subtotal * factor,
          porPeso: item.vendidoPorPeso,
          fotoUrl: actual?.fotoUrl ?? item.fotoUrl,
        );
      }
    }
    final lista =
        acumulado.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final esDueno = ref.watch(esDuenoProvider);

    if (!esDueno) {
      return Scaffold(
        backgroundColor: t.papel,
        bottomNavigationBar: const AppBottomNav(activa: NavTab.reportes),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const Text('🔒', style: TextStyle(fontSize: 34)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Los reportes financieros solo los ve el dueño del negocio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: t.textoMuted),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      );
    }

    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final historial =
        ref.watch(ventasReporteProvider(_periodo)).valueOrNull ?? const [];
    final comparativo =
        ref.watch(ventasComparativoProvider(_periodo)).valueOrNull ?? const [];

    final desde = _periodo.desde;
    final ventas = historial.where((v) => !v.anulada && !v.fecha.isBefore(desde)).toList();
    final total = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    final ticket = ventas.isEmpty ? 0.0 : total / ventas.length;

    final ganancia = ventas.fold<double>(0, (s, v) => s + v.gananciaUSD);
    final itemsPeriodo = ventas.fold<int>(0, (s, v) => s + v.items.length);
    final sinCosto = ventas.fold<int>(0, (s, v) => s + v.itemsSinCosto);
    final hayGanancia = itemsPeriodo > 0 && sinCosto < itemsPeriodo;

    final anteriores = comparativo
        .where((v) =>
            !v.anulada &&
            v.fecha.isBefore(desde) &&
            !v.fecha.isBefore(_periodo.desdeAnterior))
        .toList();
    final totalAnterior = anteriores.fold<double>(0, (s, v) => s + v.totalUSD);
    final cambioPct = totalAnterior == 0 ? null : ((total - totalAnterior) / totalAnterior * 100);

    final serie = _serie(ventas);
    final top = _masVendidos(ventas).take(3).toList();

    return Scaffold(
      backgroundColor: t.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.reportes),
      body: LibretaPageBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 90),
                children: [
                  Text(
                    'Reportes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: LibretaAvisoOfflineCompacto(
                      copy: 'Sin conexión — datos hasta el último sync',
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.bordeSuave,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        for (final p in _segmentos)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _periodo = p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _periodo == p ? t.superficie : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  p.etiqueta,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _periodo == p ? FontWeight.w800 : FontWeight.w700,
                                    color: _periodo == p ? t.textoFuerte : t.textoMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // --- Hero: total del periodo + comparativo ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: LibretaColors.verde,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x470E9F6E),
                          offset: Offset(0, 12),
                          blurRadius: 26,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ventas de ${_periodo.etiqueta.toLowerCase()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Color(0xD9FFFFFF),
                              ),
                            ),
                            if (cambioPct != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FFFFFF),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${cambioPct >= 0 ? "▲" : "▼"} ${cambioPct.abs().toStringAsFixed(0)}% vs ${_periodo.etiquetaAnterior}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          MoneyFormatter.usd(total),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6),
                        ),
                        Text(
                          '${ventas.length} ${ventas.length == 1 ? "venta" : "ventas"}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _TarjetaKpi(
                          etiqueta: 'Ganancia',
                          valor: hayGanancia
                              ? '${sinCosto > 0 ? "≈" : ""}${MoneyFormatter.usd(ganancia)}'
                              : '—',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TarjetaKpi(
                          etiqueta: 'Ticket prom.',
                          valor: MoneyFormatter.usd(ticket),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _BalanceAcumulado(),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                    decoration: BoxDecoration(
                      color: t.superficie,
                      border: Border.all(color: t.bordeSuave),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Ventas por ${_periodo == PeriodoReporte.ano ? "mes" : _periodo == PeriodoReporte.mes ? "semana" : "día"}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.textoFuerte),
                          ),
                        ),
                        const SizedBox(height: 10),
                        GraficoLinea(puntos: serie),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'MÁS VENDIDOS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: t.textoMuted),
                  ),
                  const SizedBox(height: 4),
                  if (top.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Sin ventas en este periodo', style: TextStyle(fontSize: 13, color: t.textoMuted)),
                    )
                  else
                    for (var i = 0; i < top.length; i++)
                      _FilaTop(posicion: i + 1, producto: top[i]),
                ],
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: LibretaButton(
                  label: 'Exportar reporte',
                  color: const Color(0xFF1E2A38),
                  icon: const Icon(Icons.ios_share, size: 18, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExportarReporteScreen(
                        negocio: negocio?.nombre ?? 'mi negocio',
                        periodoInicial: _periodo,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopProducto {
  const _TopProducto({
    required this.nombre,
    required this.unidades,
    required this.total,
    required this.porPeso,
    this.fotoUrl,
  });

  final String nombre;
  final double unidades;
  final double total;
  final bool porPeso;
  final String? fotoUrl;

  String get unidadesLabel {
    final n = unidades == unidades.roundToDouble()
        ? unidades.toStringAsFixed(0)
        : unidades.toStringAsFixed(2).replaceAll('.', ',');
    return porPeso ? '$n kg' : '$n uds';
  }
}

/// Balance desde que el negocio empezó a usar la app (`Lote N · P0`).
///
/// Los periodos de arriba dicen cómo va la semana; esto dice cómo va el
/// negocio. Se calcula con agregaciones del servidor, que no leen caché: sin
/// señal la tarjeta no aparece en vez de bloquear la pantalla.
class _BalanceAcumulado extends ConsumerWidget {
  const _BalanceAcumulado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceAcumuladoProvider).valueOrNull;
    if (balance == null || balance.vacio) return const SizedBox.shrink();

    final t = context.libreta;
    final tasa = ref.watch(tasaActivaValorProvider);
    final positivo = balance.balanceUSD >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: LibretaColors.tarjetaOscura,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bordeHero, width: 1.5),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BALANCE ACUMULADO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0x99FFFFFF),
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'desde que empezaste',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0x8CFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                MoneyFormatter.usd(balance.balanceUSD),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: positivo ? Colors.white : const Color(0xFFF2A93C),
                ),
              ),
              if (tasa != null)
                Text(
                  MoneyFormatter.usdComoBs(balance.balanceUSD, tasa),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0x99FFFFFF),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaKpi extends StatelessWidget {
  const _TarjetaKpi({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.bordeSuave),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: t.textoMuted),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.textoFuerte),
          ),
        ],
      ),
    );
  }
}

class _FilaTop extends StatelessWidget {
  const _FilaTop({required this.posicion, required this.producto});

  final int posicion;
  final _TopProducto producto;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tieneFoto = producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty;

    return Container(
      height: 50,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.renglon))),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '$posicion',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: LibretaColors.verde),
            ),
          ),
          const SizedBox(width: 12),
          if (tieneFoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FotoRed(
                producto.fotoUrl!,
                width: 30,
                height: 30,
                alError: Icon(Icons.image_outlined, size: 16, color: t.textoMuted),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              producto.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textoFuerte),
            ),
          ),
          Text(
            MoneyFormatter.usd(producto.total),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.textoFuerte),
          ),
        ],
      ),
    );
  }
}


