import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../ventas/domain/venta.dart';
import '../data/reportes_providers.dart';
import '../domain/periodo_reporte.dart';

/// Reportes de ventas (bloque `isReportes` del diseño).
///
/// Solo para el dueño: es información financiera (CLAUDE.md §6).
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  PeriodoReporte _periodo = PeriodoReporte.semana;

  Future<void> _enviarPorWhatsapp(
    String negocio,
    List<Venta> ventas,
    double total,
    double ticket,
    double? ganancia,
    List<_TopProducto> top,
  ) async {
    final texto =
        StringBuffer()
          ..writeln('*Reporte de $negocio*')
          ..writeln('Periodo: ${_periodo.etiqueta.toLowerCase()}')
          ..writeln()
          ..writeln('Ventas: ${ventas.length}')
          ..writeln('Total: ${MoneyFormatter.usd(total)}')
          ..writeln('Ticket promedio: ${MoneyFormatter.usd(ticket)}');
    if (ganancia != null) {
      texto.writeln('Ganancia: ${MoneyFormatter.usd(ganancia)}');
    }

    if (top.isNotEmpty) {
      texto
        ..writeln()
        ..writeln('*Más vendidos:*');
      for (final p in top.take(5)) {
        texto.writeln(
          '• ${p.nombre} — ${p.unidadesLabel} · ${MoneyFormatter.usd(p.total)}',
        );
      }
    }

    await Share.share(texto.toString(), subject: 'Reporte $negocio');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final esDueno = ref.watch(esDuenoProvider);
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    // Consulta por rango en el servidor: trae el periodo completo (más los
    // últimos 7 días para el gráfico), no una página del historial.
    final historial =
        ref.watch(ventasReporteProvider(_periodo)).valueOrNull ?? const [];

    // Los reportes son información financiera: el empleado no los ve.
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
                  'Los reportes financieros solo los ve el dueño del negocio.',
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

    final desde = _periodo.desde;
    final ventas =
        historial.where((v) => !v.anulada && !v.fecha.isBefore(desde)).toList();
    final total = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    final ticket = ventas.isEmpty ? 0.0 : total / ventas.length;

    final ganancia = ventas.fold<double>(0, (s, v) => s + v.gananciaUSD);
    final itemsPeriodo = ventas.fold<int>(0, (s, v) => s + v.items.length);
    final sinCosto = ventas.fold<int>(0, (s, v) => s + v.itemsSinCosto);
    // Sin ningún costo registrado no hay ganancia que mostrar; con costos
    // parciales la cifra va con "≈" para no venderla como exacta.
    final hayGanancia = itemsPeriodo > 0 && sinCosto < itemsPeriodo;

    final barras = _barrasSemana(historial);
    final top = _masVendidos(ventas);

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
                Text(
                  'Reportes de ventas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Periodos ---
            Row(
              children: [
                for (final p in PeriodoReporte.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _periodo = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          height: 38,
                          decoration: BoxDecoration(
                            color: _periodo == p ? AppColors.marca : t.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow:
                                _periodo == p ? t.shadowBtn : t.shadowRaisedSm,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.etiqueta,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _periodo == p ? Colors.white : t.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // --- KPIs ---
            Row(
              children: [
                Expanded(
                  child: _Kpi(
                    etiqueta: _periodo.etiqueta,
                    valor: MoneyFormatter.usd(total),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Kpi(
                    etiqueta: 'Ticket promedio',
                    valor: MoneyFormatter.usd(ticket),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Kpi(
              etiqueta:
                  sinCosto > 0 && hayGanancia
                      ? 'Ganancia (sin contar $sinCosto sin costo)'
                      : 'Ganancia',
              valor:
                  hayGanancia
                      ? '${sinCosto > 0 ? "≈" : ""}${MoneyFormatter.usd(ganancia)}'
                      : 'Registra costos para verla',
            ),
            const SizedBox(height: 16),

            // --- Gráfico ---
            NeuCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ventas por día',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _GraficoBarras(barras: barras),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // --- Más vendidos ---
            Text(
              'Más vendidos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 10),
            if (top.isEmpty)
              NeuCard(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'Sin ventas en este periodo',
                    style: TextStyle(fontSize: 13, color: t.textSec),
                  ),
                ),
              )
            else
              NeuCard(
                clip: true,
                child: Column(
                  children: [
                    for (var i = 0; i < top.length && i < 5; i++)
                      _FilaTop(
                        producto: top[i],
                        ultima: i == top.length - 1 || i == 4,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
            NeuButton(
              label: '📤 Enviar reporte por WhatsApp',
              color: const Color(0xFF25D366),
              onPressed:
                  ventas.isEmpty
                      ? null
                      : () => _enviarPorWhatsapp(
                        negocio?.nombre ?? 'mi negocio',
                        ventas,
                        total,
                        ticket,
                        hayGanancia ? ganancia : null,
                        top,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// Totales de los últimos 7 días, de lunes a domingo relativo a hoy.
  List<_Barra> _barrasSemana(List<Venta> historial) {
    final hoy = DateTime.now();
    const nombres = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return List.generate(7, (i) {
      final dia = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
      ).subtract(Duration(days: 6 - i));
      final siguiente = dia.add(const Duration(days: 1));
      final total = historial
          .where(
            (v) =>
                !v.anulada &&
                v.fecha.isAfter(dia) &&
                v.fecha.isBefore(siguiente),
          )
          .fold<double>(0, (s, v) => s + v.totalUSD);
      return _Barra(etiqueta: nombres[dia.weekday - 1], total: total);
    });
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
      // Si el bruto es 0 no hay nada que repartir (evita dividir por cero).
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
}

class _Barra {
  const _Barra({required this.etiqueta, required this.total});

  final String etiqueta;
  final double total;
}

class _InicialTop extends StatelessWidget {
  const _InicialTop({required this.nombre});

  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Text(
      nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w800,
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
    final n =
        unidades == unidades.roundToDouble()
            ? unidades.toStringAsFixed(0)
            : unidades.toStringAsFixed(2).replaceAll('.', ',');
    return porPeso ? '$n kg' : '$n uds';
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 12, color: t.textSec)),
          const SizedBox(height: 4),
          Text(valor, style: AppTypography.money(fontSize: 20, color: t.text)),
        ],
      ),
    );
  }
}

/// Barras de los últimos 7 días, escaladas al día de mayor venta.
class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({required this.barras});

  final List<_Barra> barras;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maximo = barras.fold<double>(0, (m, b) => b.total > m ? b.total : m);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in barras)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (b.total > 0)
                    Text(
                      MoneyFormatter.usd(b.total).replaceAll('.00', ''),
                      style: TextStyle(fontSize: 9, color: t.textSec),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    // Mínimo de 3 px para que un día sin ventas se distinga
                    // de uno con muy pocas, en vez de desaparecer.
                    height:
                        maximo == 0 ? 3 : (b.total / maximo * 90).clamp(3, 90),
                    decoration: BoxDecoration(
                      color: b.total > 0 ? AppColors.marca : t.border,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                        bottom: Radius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.etiqueta,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: t.textSec,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaTop extends StatelessWidget {
  const _FilaTop({required this.producto, required this.ultima});

  final _TopProducto producto;
  final bool ultima;

  static const _colores = [
    Color(0xFF0F6B5C),
    Color(0xFF3D6CA8),
    Color(0xFFC9852B),
    Color(0xFF8A5FB0),
    Color(0xFFC74A3A),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = _colores[producto.nombre.hashCode.abs() % _colores.length];

    final tieneFoto = producto.fotoUrl != null && producto.fotoUrl!.isNotEmpty;

    return NeuListTile(
      divider: !ultima,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child:
                tieneFoto
                    ? FotoRed(
                      producto.fotoUrl!,
                      width: 34,
                      height: 34,
                      alError: _InicialTop(nombre: producto.nombre),
                    )
                    : _InicialTop(nombre: producto.nombre),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                Text(
                  producto.unidadesLabel,
                  style: TextStyle(fontSize: 12, color: t.textSec),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.usd(producto.total),
            style: AppTypography.money(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}
