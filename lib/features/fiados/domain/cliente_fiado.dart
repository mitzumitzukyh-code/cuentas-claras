import 'package:cloud_firestore/cloud_firestore.dart';

/// Cliente con cuenta de fiado (`Lote G · Fiados`).
///
/// `saldoUSD` viaja denormalizado en el propio documento (igual que
/// `Producto.cantidad`): así la lista de fiados no tiene que sumar el
/// historial completo de movimientos solo para pintar cada fila.
class ClienteFiado {
  const ClienteFiado({
    required this.id,
    required this.nombre,
    this.telefono,
    required this.saldoUSD,
    required this.actualizadoEn,
  });

  final String id;
  final String nombre;
  final String? telefono;

  /// Deuda pendiente en USD. `0` = al día.
  final double saldoUSD;
  final DateTime actualizadoEn;

  /// Iniciales para el avatar, máximo dos letras.
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.elementAt(1)[0]).toUpperCase();
  }

  factory ClienteFiado.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ClienteFiado(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      telefono: data['telefono'] as String?,
      saldoUSD: (data['saldoUSD'] as num?)?.toDouble() ?? 0,
      actualizadoEn:
          (data['actualizadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'saldoUSD': saldoUSD,
        'actualizadoEn': Timestamp.fromDate(actualizadoEn),
      };
}

/// Tipo de movimiento en la cuenta de un cliente.
enum TipoMovimientoFiado {
  fiado,
  abono;

  String get id => name;

  static TipoMovimientoFiado fromId(String? id) =>
      id == 'abono' ? TipoMovimientoFiado.abono : TipoMovimientoFiado.fiado;
}

/// Un movimiento (fiado o abono) en la cuenta de un cliente — nunca se borra
/// ni se edita, es el libro mayor de esa deuda.
class MovimientoFiado {
  const MovimientoFiado({
    required this.id,
    required this.tipo,
    required this.montoUSD,
    required this.concepto,
    required this.fecha,
    required this.registradoPor,
    this.negocioId = '',
  });

  final String id;
  final TipoMovimientoFiado tipo;

  /// Siempre positivo; el signo lo decide `tipo` al aplicarlo al saldo.
  final double montoUSD;
  final String concepto;
  final DateTime fecha;
  final String registradoPor;

  /// Denormalizado (además de vivir en la ruta) solo para poder filtrar con
  /// `where('negocioId', ...)` en la consulta `collectionGroup` del Resumen
  /// del día (Lote H): una `collectionGroup` no puede filtrar por la ruta del
  /// ancestro, así que sin este campo Firestore intentaría evaluar las reglas
  /// contra los movimientos de TODOS los negocios y la consulta fallaría.
  final String negocioId;

  factory MovimientoFiado.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return MovimientoFiado(
      id: doc.id,
      tipo: TipoMovimientoFiado.fromId(data['tipo'] as String?),
      montoUSD: (data['montoUSD'] as num?)?.toDouble() ?? 0,
      concepto: (data['concepto'] as String?) ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      registradoPor: (data['registradoPor'] as String?) ?? '',
      negocioId: (data['negocioId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.id,
        'montoUSD': montoUSD,
        'negocioId': negocioId,
        'concepto': concepto,
        'fecha': Timestamp.fromDate(fecha),
        'registradoPor': registradoPor,
      };
}
