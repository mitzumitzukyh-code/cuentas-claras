import 'package:cloud_firestore/cloud_firestore.dart';

/// Proveedor con cuenta por pagar (`Lote H · Cierre y Proveedores`).
class Proveedor {
  const Proveedor({
    required this.id,
    required this.nombre,
    required this.saldoUSD,
    this.proximoVencimiento,
    required this.actualizadoEn,
  });

  final String id;
  final String nombre;

  /// Deuda pendiente en USD. `0` = al día.
  final double saldoUSD;

  /// Vencimiento de la compra a crédito más reciente. Aproximado: no hay un
  /// libro de facturas individuales, así que es la fecha de la última compra
  /// registrada, no la más próxima a vencer entre varias.
  final DateTime? proximoVencimiento;
  final DateTime actualizadoEn;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.elementAt(1)[0]).toUpperCase();
  }

  factory Proveedor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Proveedor(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      saldoUSD: (data['saldoUSD'] as num?)?.toDouble() ?? 0,
      proximoVencimiento: (data['proximoVencimiento'] as Timestamp?)?.toDate(),
      actualizadoEn:
          (data['actualizadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'saldoUSD': saldoUSD,
        'proximoVencimiento': proximoVencimiento == null
            ? null
            : Timestamp.fromDate(proximoVencimiento!),
        'actualizadoEn': Timestamp.fromDate(actualizadoEn),
      };
}

/// Tipo de movimiento en la cuenta de un proveedor.
enum TipoMovimientoProveedor {
  compra,
  pago;

  String get id => name;

  static TipoMovimientoProveedor fromId(String? id) =>
      id == 'pago' ? TipoMovimientoProveedor.pago : TipoMovimientoProveedor.compra;
}

/// Un movimiento (compra a crédito o pago) en la cuenta de un proveedor —
/// nunca se borra ni se edita, es el libro mayor de esa deuda.
class MovimientoProveedor {
  const MovimientoProveedor({
    required this.id,
    required this.tipo,
    required this.montoUSD,
    required this.concepto,
    required this.fecha,
    required this.registradoPor,
    this.vencimiento,
  });

  final String id;
  final TipoMovimientoProveedor tipo;
  final double montoUSD;
  final String concepto;
  final DateTime fecha;
  final String registradoPor;

  /// Solo aplica a `compra`.
  final DateTime? vencimiento;

  factory MovimientoProveedor.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return MovimientoProveedor(
      id: doc.id,
      tipo: TipoMovimientoProveedor.fromId(data['tipo'] as String?),
      montoUSD: (data['montoUSD'] as num?)?.toDouble() ?? 0,
      concepto: (data['concepto'] as String?) ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      registradoPor: (data['registradoPor'] as String?) ?? '',
      vencimiento: (data['vencimiento'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.id,
        'montoUSD': montoUSD,
        'concepto': concepto,
        'fecha': Timestamp.fromDate(fecha),
        'registradoPor': registradoPor,
        'vencimiento': vencimiento == null ? null : Timestamp.fromDate(vencimiento!),
      };
}
