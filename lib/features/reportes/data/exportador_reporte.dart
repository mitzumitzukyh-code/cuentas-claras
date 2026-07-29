import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../fiados/domain/cliente_fiado.dart';
import '../../gastos/domain/gasto.dart';
import '../../ventas/domain/venta.dart';

/// Lo que se va a exportar (`Lote N · P1 · Exportar reporte`).
///
/// Cada lista es `null` cuando el interruptor de esa sección está apagado —
/// distinto de una lista vacía, que significa "sí la pidió y no hubo nada".
class DatosReporte {
  const DatosReporte({
    required this.negocio,
    required this.periodo,
    required this.desde,
    this.hasta,
    this.ventas,
    this.gastos,
    this.fiados,
  });

  final String negocio;

  /// "Mes", "Semana", "Año" o el rango personalizado ya formateado.
  final String periodo;

  final DateTime desde;
  final DateTime? hasta;

  final List<Venta>? ventas;
  final List<Gasto>? gastos;
  final List<ClienteFiado>? fiados;

  double get totalVentas =>
      (ventas ?? const []).fold<double>(0, (s, v) => s + v.totalUSD);
  double get totalGastos =>
      (gastos ?? const []).fold<double>(0, (s, g) => s + g.monto);
  double get totalFiado =>
      (fiados ?? const []).fold<double>(0, (s, c) => s + c.saldoUSD);
}

enum FormatoReporte { excel, pdf }

/// Genera el archivo del reporte y lo deja en la carpeta temporal, listo para
/// compartir (`Lote N · P3` lo muestra llegando por WhatsApp como adjunto).
///
/// Los montos van al archivo como número, no como texto formateado: quien
/// abra el .xlsx tiene que poder sumar la columna. El formato bonito se queda
/// para el PDF, que se lee y no se calcula.
class ExportadorReporte {
  const ExportadorReporte();

  static final _fecha = DateFormat('dd/MM/yyyy');
  static final _fechaHora = DateFormat('dd/MM/yyyy HH:mm');
  static final _sello = DateFormat('yyyy-MM-dd');

  /// Escribe el reporte y devuelve la ruta del archivo temporal.
  Future<String> generar(DatosReporte datos, FormatoReporte formato) async {
    final bytes = formato == FormatoReporte.excel
        ? _excel(datos)
        : await _pdf(datos);

    final dir = await getTemporaryDirectory();
    final ruta = '${dir.path}/${nombreArchivo(datos, formato)}';
    await File(ruta).writeAsBytes(bytes, flush: true);
    return ruta;
  }

  /// "Reporte_Abasto-La-Esquina_2026-07-29.xlsx".
  String nombreArchivo(DatosReporte datos, FormatoReporte formato) {
    final limpio = datos.negocio
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final base = limpio.isEmpty ? 'negocio' : limpio;
    final ext = formato == FormatoReporte.excel ? 'xlsx' : 'pdf';
    return 'Reporte_${base}_${_sello.format(DateTime.now())}.$ext';
  }

  // ── Excel ────────────────────────────────────────────────────────────────

  List<int> _excel(DatosReporte d) {
    final libro = Excel.createExcel();
    final creada = libro.getDefaultSheet();

    _hojaResumen(libro['Resumen'], d);
    if (d.ventas != null) _hojaVentas(libro['Ventas'], d.ventas!);
    if (d.gastos != null) _hojaGastos(libro['Gastos'], d.gastos!);
    if (d.fiados != null) _hojaFiados(libro['Fiados'], d.fiados!);

    // La hoja que crea el paquete queda vacía y confunde a quien abre el
    // archivo; se borra al final, cuando ya hay otra que pueda quedar activa.
    if (creada != null) libro.delete(creada);

    return libro.save() ?? const <int>[];
  }

  void _hojaResumen(Sheet h, DatosReporte d) {
    h.appendRow([TextCellValue('Reporte de ${d.negocio}')]);
    h.appendRow([TextCellValue('Periodo'), TextCellValue(d.periodo)]);
    h.appendRow([
      TextCellValue('Desde'),
      TextCellValue(_fecha.format(d.desde)),
      TextCellValue('Hasta'),
      TextCellValue(_fecha.format(
        d.hasta?.subtract(const Duration(days: 1)) ?? DateTime.now(),
      )),
    ]);
    h.appendRow([TextCellValue('Generado'), TextCellValue(_fechaHora.format(DateTime.now()))]);
    h.appendRow([]);
    h.appendRow([TextCellValue('Concepto'), TextCellValue('Cantidad'), TextCellValue('Total USD')]);
    if (d.ventas != null) {
      h.appendRow([
        TextCellValue('Ventas'),
        IntCellValue(d.ventas!.length),
        DoubleCellValue(d.totalVentas),
      ]);
    }
    if (d.gastos != null) {
      h.appendRow([
        TextCellValue('Gastos'),
        IntCellValue(d.gastos!.length),
        DoubleCellValue(d.totalGastos),
      ]);
    }
    if (d.ventas != null && d.gastos != null) {
      h.appendRow([
        TextCellValue('Neto'),
        TextCellValue(''),
        DoubleCellValue(d.totalVentas - d.totalGastos),
      ]);
    }
    if (d.fiados != null) {
      h.appendRow([
        TextCellValue('Fiado pendiente (a hoy)'),
        IntCellValue(d.fiados!.length),
        DoubleCellValue(d.totalFiado),
      ]);
    }
  }

  void _hojaVentas(Sheet h, List<Venta> ventas) {
    h.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Método'),
      TextCellValue('Productos'),
      TextCellValue('Subtotal USD'),
      TextCellValue('Descuento USD'),
      TextCellValue('IVA USD'),
      TextCellValue('Total USD'),
      TextCellValue('Fiado a'),
    ]);
    for (final v in ventas) {
      h.appendRow([
        TextCellValue(_fechaHora.format(v.fecha)),
        TextCellValue(_sinEmoji(v.metodoPago.etiqueta)),
        TextCellValue(v.items.map((i) => '${i.cantidadLabel} ${i.nombreCompleto}').join(', ')),
        DoubleCellValue(v.subtotalUSD),
        DoubleCellValue(v.descuentoUSD),
        DoubleCellValue(v.ivaUSD),
        DoubleCellValue(v.totalUSD),
        TextCellValue(v.fiadoClienteNombre ?? ''),
      ]);
    }
  }

  void _hojaGastos(Sheet h, List<Gasto> gastos) {
    h.appendRow([
      TextCellValue('Fecha'),
      TextCellValue('Categoría'),
      TextCellValue('Subcategoría'),
      TextCellValue('Descripción'),
      TextCellValue('Monto USD'),
    ]);
    for (final g in gastos) {
      h.appendRow([
        TextCellValue(_fecha.format(g.fecha)),
        TextCellValue(_sinEmoji(g.categoria.etiqueta)),
        TextCellValue(g.subcategoria ?? ''),
        TextCellValue(g.descripcion),
        DoubleCellValue(g.monto),
      ]);
    }
  }

  void _hojaFiados(Sheet h, List<ClienteFiado> clientes) {
    h.appendRow([
      TextCellValue('Cliente'),
      TextCellValue('Teléfono'),
      TextCellValue('Debe USD'),
      TextCellValue('Último movimiento'),
    ]);
    for (final c in clientes) {
      h.appendRow([
        TextCellValue(c.nombre),
        TextCellValue(c.telefono ?? ''),
        DoubleCellValue(c.saldoUSD),
        TextCellValue(_fecha.format(c.actualizadoEn)),
      ]);
    }
  }

  // ── PDF ──────────────────────────────────────────────────────────────────

  Future<List<int>> _pdf(DatosReporte d) async {
    final doc = pw.Document(title: 'Reporte de ${d.negocio}');
    final verde = PdfColor.fromInt(0xFF0F9D82);
    final azul = PdfColor.fromInt(0xFF1B3A4B);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 14),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: verde, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _sinEmoji(d.negocio),
                style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: azul),
              ),
              pw.Text(
                '${d.periodo} · ${_fecha.format(d.desde)}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Cuenta Clara · página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (_) => [
          _resumenPdf(d, verde, azul),
          if (d.ventas != null) ...[
            _tituloPdf('Ventas', azul),
            _tablaPdf(
              const ['Fecha', 'Método', 'Total USD'],
              [
                for (final v in d.ventas!)
                  [
                    _fechaHora.format(v.fecha),
                    _sinEmoji(v.metodoPago.etiqueta),
                    _monto(v.totalUSD),
                  ],
              ],
              verde,
            ),
          ],
          if (d.gastos != null) ...[
            _tituloPdf('Gastos', azul),
            _tablaPdf(
              const ['Fecha', 'Categoría', 'Descripción', 'Monto USD'],
              [
                for (final g in d.gastos!)
                  [
                    _fecha.format(g.fecha),
                    _sinEmoji(g.categoria.etiqueta),
                    _sinEmoji(g.descripcion),
                    _monto(g.monto),
                  ],
              ],
              verde,
            ),
          ],
          if (d.fiados != null) ...[
            _tituloPdf('Fiado pendiente', azul),
            _tablaPdf(
              const ['Cliente', 'Teléfono', 'Debe USD'],
              [
                for (final c in d.fiados!)
                  [_sinEmoji(c.nombre), c.telefono ?? '', _monto(c.saldoUSD)],
              ],
              verde,
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _resumenPdf(DatosReporte d, PdfColor verde, PdfColor azul) {
    pw.Widget bloque(String titulo, String valor, PdfColor color) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const pw.EdgeInsets.only(right: 8),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(titulo.toUpperCase(),
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
                pw.SizedBox(height: 2),
                pw.Text(valor,
                    style: pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ],
            ),
          ),
        );

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          if (d.ventas != null) bloque('Ventas', _monto(d.totalVentas), verde),
          if (d.gastos != null) bloque('Gastos', _monto(d.totalGastos), azul),
          if (d.fiados != null)
            bloque('Fiado pendiente', _monto(d.totalFiado), PdfColor.fromInt(0xFFF2A93B)),
        ],
      ),
    );
  }

  pw.Widget _tituloPdf(String texto, PdfColor azul) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(texto,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: azul)),
      );

  pw.Widget _tablaPdf(List<String> encabezados, List<List<String>> filas, PdfColor verde) {
    if (filas.isEmpty) {
      return pw.Text('Sin movimientos en el período.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700));
    }
    return pw.TableHelper.fromTextArray(
      headers: encabezados,
      data: filas,
      cellStyle: const pw.TextStyle(fontSize: 9),
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: verde),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {encabezados.length - 1: pw.Alignment.centerRight},
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
    );
  }

  String _monto(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  /// Las fuentes que trae el PDF por defecto son Latin-1: un emoji sale como
  /// carácter roto y las etiquetas de método de pago y categoría los llevan.
  String _sinEmoji(String s) =>
      s.replaceAll(RegExp(r'[^ -ÿ]'), '').trim();
}
