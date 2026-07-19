import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../core/utils/money_formatter.dart';
import '../../features/negocio/domain/negocio.dart';
import '../../features/ventas/domain/venta.dart';

/// Arma el ticket en comandos ESC/POS.
///
/// Es deliberadamente independiente del transporte: los mismos bytes valen
/// para una impresora Bluetooth o una WiFi. Solo cambia por dónde se envían.
abstract final class TicketEscPos {
  const TicketEscPos._();

  /// Genera el ticket de una [venta].
  ///
  /// [ancho] es el papel: 58 mm es el rollo común de las térmicas baratas,
  /// 80 mm el de las de mostrador.
  static Future<List<int>> generar({
    required Venta venta,
    required Negocio negocio,
    PaperSize ancho = PaperSize.mm58,
  }) async {
    final perfil = await CapabilityProfile.load();
    final g = Generator(ancho, perfil);
    final bytes = <int>[];

    // --- Encabezado ---
    bytes.addAll(g.text(
      negocio.nombre,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));
    bytes.addAll(g.text(
      _fechaHora(venta.fecha),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.text(
      'Recibo ${_numeroRecibo(venta.id)}',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(g.hr());

    // --- Líneas ---
    for (final item in venta.items) {
      bytes.addAll(g.text(
        item.nombre,
        styles: const PosStyles(bold: true),
      ));
      bytes.addAll(g.row([
        PosColumn(
          text: '${item.cantidadLabel} x '
              '${MoneyFormatter.usd(item.precioUnitario)}',
          width: 8,
        ),
        PosColumn(
          text: MoneyFormatter.usd(item.subtotal),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]));
    }
    bytes.addAll(g.hr());

    // --- Totales ---
    if (venta.descuentoPct > 0) {
      bytes.addAll(_fila(g, 'Subtotal', MoneyFormatter.usd(venta.subtotalUSD)));
      bytes.addAll(_fila(
        g,
        'Descuento ${venta.descuentoPct}%',
        '-${MoneyFormatter.usd(venta.descuentoUSD)}',
      ));
    }
    if (venta.ivaUSD > 0) {
      bytes.addAll(_fila(g, 'IVA 16%', MoneyFormatter.usd(venta.ivaUSD)));
    }

    bytes.addAll(g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: MoneyFormatter.usd(venta.totalUSD),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]));

    // El monto en bolívares es lo que el cliente realmente paga en efectivo.
    bytes.addAll(_fila(g, 'Total Bs', MoneyFormatter.bs(venta.totalBs)));
    bytes.addAll(_fila(g, 'Tasa BCV', MoneyFormatter.bs(venta.tasaBcvUsada)));
    bytes.addAll(_fila(g, 'Pago', venta.metodoPago.etiquetaCorta));

    if (venta.anulada) {
      bytes.addAll(g.hr());
      bytes.addAll(g.text(
        '*** VENTA ANULADA ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ));
    }

    // --- Pie ---
    bytes.addAll(g.hr());
    if (negocio.reciboMensaje.trim().isNotEmpty) {
      bytes.addAll(g.text(
        negocio.reciboMensaje,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }
    bytes.addAll(g.text(
      'Hecho con Cuenta Clara',
      styles: const PosStyles(align: PosAlign.center),
    ));

    bytes.addAll(g.feed(2));
    bytes.addAll(g.cut());
    return bytes;
  }

  static List<int> _fila(Generator g, String izq, String der) {
    return g.row([
      PosColumn(text: izq, width: 6),
      PosColumn(
        text: der,
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  static String _fechaHora(DateTime f) {
    final h = f.hour.toString().padLeft(2, '0');
    final m = f.minute.toString().padLeft(2, '0');
    return '${f.day}/${f.month}/${f.year}  $h:$m';
  }

  static String _numeroRecibo(String id) =>
      '#${id.substring(0, id.length.clamp(0, 6)).toUpperCase()}';
}
