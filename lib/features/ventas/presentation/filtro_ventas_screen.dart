import 'package:flutter/material.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../domain/filtro_ventas.dart';
import '../domain/venta.dart';

/// Filtrar ventas (réplica visual de `P1 · FILTROS`, `Lote L · Búsqueda y
/// Datos`).
///
/// Recibe el historial completo para mostrar en vivo cuántas ventas y cuánto
/// total deja cada combinación, antes de aplicarla.
class FiltroVentasScreen extends StatefulWidget {
  const FiltroVentasScreen({
    super.key,
    required this.ventas,
    required this.inicial,
  });

  final List<Venta> ventas;
  final FiltroVentas inicial;

  @override
  State<FiltroVentasScreen> createState() => _FiltroVentasScreenState();
}

class _FiltroVentasScreenState extends State<FiltroVentasScreen> {
  late FiltroVentas _filtro = widget.inicial;

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
      initialDateRange: _filtro.personalizadoDesde != null && _filtro.personalizadoHasta != null
          ? DateTimeRange(start: _filtro.personalizadoDesde!, end: _filtro.personalizadoHasta!)
          : null,
    );
    if (rango == null) return;
    setState(() {
      _filtro = _filtro.copyWith(
        periodo: PeriodoFiltroVenta.personalizado,
        personalizadoDesde: rango.start,
        personalizadoHasta: rango.end,
      );
    });
  }

  void _elegirPeriodo(PeriodoFiltroVenta p) {
    if (p == PeriodoFiltroVenta.personalizado) {
      _elegirRango();
      return;
    }
    setState(() => _filtro = _filtro.copyWith(periodo: p));
  }

  String _fechaCorta(DateTime f) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${f.day} ${meses[f.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final resultado = widget.ventas.where(_filtro.aplicaA).toList();
    final total = resultado.fold<double>(0, (s, v) => s + v.totalUSD);

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(oscuro: true, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Text(
                    'Filtrar ventas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.textoFuerte, letterSpacing: -0.4),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _Etiqueta('PERÍODO'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in PeriodoFiltroVenta.values)
                    LibretaChip(
                      label: p == PeriodoFiltroVenta.personalizado &&
                              _filtro.periodo == PeriodoFiltroVenta.personalizado &&
                              _filtro.personalizadoDesde != null &&
                              _filtro.personalizadoHasta != null
                          ? '${_fechaCorta(_filtro.personalizadoDesde!)} – ${_fechaCorta(_filtro.personalizadoHasta!)}'
                          : p.etiqueta,
                      selected: _filtro.periodo == p,
                      onTap: () => _elegirPeriodo(p),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              _Etiqueta('MÉTODO DE PAGO'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  LibretaChip(
                    label: 'Todos',
                    selected: _filtro.metodo == null,
                    onTap: () => setState(() => _filtro = _filtro.copyWith(sinMetodo: true)),
                  ),
                  for (final m in MetodoPago.values)
                    LibretaChip(
                      label: m.etiquetaCorta,
                      selected: _filtro.metodo == m,
                      onTap: () => setState(() => _filtro = _filtro.copyWith(metodo: m)),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              _Etiqueta('ESTADO'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in EstadoFiltroVenta.values)
                    LibretaChip(
                      label: e.etiqueta,
                      selected: _filtro.estado == e,
                      onTap: () => setState(() => _filtro = _filtro.copyWith(estado: e)),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: t.superficie,
                  border: Border.all(color: t.bordeSuave),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Resultado', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textoMuted)),
                    Text(
                      '${resultado.length} ${resultado.length == 1 ? "venta" : "ventas"} · ${MoneyFormatter.usd(total)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.textoFuerte),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LibretaButton(
                label: 'Aplicar filtros',
                onPressed: () => Navigator.of(context).pop(_filtro),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _filtro = const FiltroVentas(periodo: PeriodoFiltroVenta.personalizado)),
                  child: Text('Limpiar todo', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: t.textoMuted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: context.libreta.textoMuted,
      ),
    );
  }
}
