import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../fiados/data/fiado_repository.dart';
import '../../gastos/data/gasto_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../ventas/data/venta_repository.dart';
import '../data/exportador_reporte.dart';
import '../domain/periodo_reporte.dart';

enum _PeriodoExportar {
  semana,
  mes,
  ano,
  personalizado;

  String get etiqueta => switch (this) {
        _PeriodoExportar.semana => 'Semana',
        _PeriodoExportar.mes => 'Mes',
        _PeriodoExportar.ano => 'Año',
        _PeriodoExportar.personalizado => 'Personalizado',
      };
}

/// Exportar reporte (réplica visual de `P1 · EXPORTAR`, `Lote N · Reportes
/// y Más`).
///
/// Genera el archivo de verdad — .xlsx con una hoja por sección o .pdf con el
/// resumen y las tablas — y lo comparte como adjunto, que es lo que muestra
/// `P3`: el reporte llegándole al contador por WhatsApp.
class ExportarReporteScreen extends ConsumerStatefulWidget {
  const ExportarReporteScreen({
    super.key,
    required this.negocio,
    required this.periodoInicial,
  });

  final String negocio;
  final PeriodoReporte periodoInicial;

  @override
  ConsumerState<ExportarReporteScreen> createState() => _ExportarReporteScreenState();
}

class _ExportarReporteScreenState extends ConsumerState<ExportarReporteScreen> {
  FormatoReporte _formato = FormatoReporte.excel;
  late _PeriodoExportar _periodo = switch (widget.periodoInicial) {
    PeriodoReporte.hoy || PeriodoReporte.semana => _PeriodoExportar.semana,
    PeriodoReporte.mes => _PeriodoExportar.mes,
    PeriodoReporte.ano => _PeriodoExportar.ano,
  };
  DateTimeRange? _rangoPersonalizado;
  bool _incluirVentas = true;
  bool _incluirGastos = true;
  bool _incluirFiados = false;
  bool _generando = false;

  (DateTime, DateTime?) _rango() {
    final ahora = DateTime.now();
    switch (_periodo) {
      case _PeriodoExportar.semana:
        final lunes = DateTime(ahora.year, ahora.month, ahora.day)
            .subtract(Duration(days: ahora.weekday - 1));
        return (lunes, null);
      case _PeriodoExportar.mes:
        return (DateTime(ahora.year, ahora.month), null);
      case _PeriodoExportar.ano:
        return (DateTime(ahora.year), null);
      case _PeriodoExportar.personalizado:
        final r = _rangoPersonalizado;
        if (r == null) return (DateTime(ahora.year, ahora.month), null);
        return (r.start, DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1)));
    }
  }

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(ahora.year - 2),
      lastDate: ahora,
      initialDateRange: _rangoPersonalizado,
    );
    if (r == null) return;
    setState(() {
      _periodo = _PeriodoExportar.personalizado;
      _rangoPersonalizado = r;
    });
  }

  void _elegirPeriodo(_PeriodoExportar p) {
    if (p == _PeriodoExportar.personalizado) {
      _elegirRango();
      return;
    }
    setState(() => _periodo = p);
  }

  Future<void> _exportar() async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;
    setState(() => _generando = true);

    final (desde, hasta) = _rango();

    try {
      final ventas = !_incluirVentas
          ? null
          : (await ref.read(ventaRepositoryProvider).ventasDesde(membresia.negocioId, desde).first)
              .where((v) => !v.anulada && (hasta == null || v.fecha.isBefore(hasta)))
              .toList();
      final gastos = !_incluirGastos
          ? null
          : (await ref.read(gastoRepositoryProvider).gastosDesde(membresia.negocioId, desde).first)
              .where((g) => hasta == null || g.fecha.isBefore(hasta))
              .toList();
      // El fiado no se recorta al período: lo que interesa es cuánto le deben
      // al negocio hoy, no qué se fió en julio.
      final fiados = !_incluirFiados
          ? null
          : (await ref.read(clientesFiadoProvider.future))
              .where((c) => c.saldoUSD > 0)
              .toList();

      final datos = DatosReporte(
        negocio: widget.negocio,
        periodo: _etiquetaPeriodo(),
        desde: desde,
        hasta: hasta,
        ventas: ventas,
        gastos: gastos,
        fiados: fiados,
      );

      const exportador = ExportadorReporte();
      final ruta = await exportador.generar(datos, _formato);
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(ruta)],
        subject: 'Reporte ${widget.negocio}',
        text: 'Reporte de ${widget.negocio} — ${datos.periodo.toLowerCase()}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo crear el archivo: $e')),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  String _etiquetaPeriodo() {
    final r = _rangoPersonalizado;
    if (_periodo != _PeriodoExportar.personalizado || r == null) {
      return _periodo.etiqueta;
    }
    String d(DateTime f) => '${f.day}/${f.month}/${f.year}';
    return '${d(r.start)} – ${d(r.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;

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
                    'Exportar reporte',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.textoFuerte, letterSpacing: -0.4),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Text('FORMATO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: t.textoMuted)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _TarjetaFormato(icono: Icons.description_outlined, etiqueta: 'Excel', seleccionado: _formato == FormatoReporte.excel, onTap: () => setState(() => _formato = FormatoReporte.excel))),
                  const SizedBox(width: 12),
                  Expanded(child: _TarjetaFormato(icono: Icons.picture_as_pdf_outlined, etiqueta: 'PDF', seleccionado: _formato == FormatoReporte.pdf, onTap: () => setState(() => _formato = FormatoReporte.pdf))),
                ],
              ),
              const SizedBox(height: 18),

              Text('PERÍODO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: t.textoMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _PeriodoExportar.values)
                    LibretaChip(
                      label: p == _PeriodoExportar.personalizado && _periodo == p && _rangoPersonalizado != null
                          ? '${_rangoPersonalizado!.start.day}/${_rangoPersonalizado!.start.month} – ${_rangoPersonalizado!.end.day}/${_rangoPersonalizado!.end.month}'
                          : p.etiqueta,
                      selected: _periodo == p,
                      onTap: () => _elegirPeriodo(p),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              Text('INCLUIR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: t.textoMuted)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: t.superficie,
                  border: Border.all(color: t.bordeSuave),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _FilaIncluir(
                      etiqueta: 'Ventas',
                      valor: _incluirVentas,
                      divisor: true,
                      onChanged: (v) => setState(() => _incluirVentas = v),
                    ),
                    _FilaIncluir(
                      etiqueta: 'Gastos',
                      valor: _incluirGastos,
                      divisor: true,
                      onChanged: (v) => setState(() => _incluirGastos = v),
                    ),
                    _FilaIncluir(
                      etiqueta: 'Fiados y abonos',
                      valor: _incluirFiados,
                      divisor: false,
                      onChanged: (v) => setState(() => _incluirFiados = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              LibretaButton(
                label: _generando ? 'Preparando…' : 'Exportar y compartir',
                loading: _generando,
                icon: _generando ? null : const LibretaIcono(AppAssets.accCompartir, size: 18, color: Colors.white),
                onPressed: (_generando || (!_incluirVentas && !_incluirGastos && !_incluirFiados)) ? null : _exportar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaFormato extends StatelessWidget {
  const _TarjetaFormato({
    required this.icono,
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: seleccionado ? LibretaColors.verde : t.bordeSuave, width: seleccionado ? 2 : 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icono, size: 26, color: seleccionado ? LibretaColors.verde : t.textoFuerte),
            const SizedBox(height: 8),
            Text(etiqueta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: t.textoFuerte)),
          ],
        ),
      ),
    );
  }
}

class _FilaIncluir extends StatelessWidget {
  const _FilaIncluir({
    required this.etiqueta,
    required this.valor,
    required this.divisor,
    required this.onChanged,
  });

  final String etiqueta;
  final bool valor;
  final bool divisor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: divisor ? Border(bottom: BorderSide(color: t.renglon)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.textoFuerte)),
          LibretaToggle(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
