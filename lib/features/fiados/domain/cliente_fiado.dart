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
    this.eliminado = false,
    this.eliminadoEn,
  });

  final String id;
  final String nombre;
  final String? telefono;

  /// Deuda pendiente en USD. `0` = al día.
  final double saldoUSD;
  final DateTime actualizadoEn;

  /// Quitado de la lista, pero no destruido.
  ///
  /// El borrado es lógico por dos razones: sus movimientos son un libro mayor
  /// que las reglas de Firestore prohíben borrar —un borrado físico del
  /// cliente los dejaría huérfanos, sin dueño ni forma de auditarlos— y quitar
  /// a alguien que debía plata es justo lo que hay que poder revisar después.
  final bool eliminado;
  final DateTime? eliminadoEn;

  /// Iniciales para el avatar, máximo dos letras.
  /// Céntimo de tolerancia: `saldoUSD` sale de sumar y restar `double`s, y
  /// una cuenta que quedó en cero puede guardarse como 0,0000001. Comparar
  /// contra 0 exacto dejaría cuentas "casi saldadas" que nunca se celebran.
  static const double _tolerancia = 0.005;

  /// La cuenta está al día: no debe nada.
  bool get saldada => saldoUSD < _tolerancia;

  /// Abonó de más y le queda crédito a favor.
  ///
  /// Se distingue de [saldada] porque no es lo mismo "no me debes" que "te
  /// debo": mostrarlo como una deuda negativa (−$3,00) es la forma más rápida
  /// de que el dueño crea que la app se equivocó.
  bool get aFavor => saldoUSD < -_tolerancia;

  /// Cuánto tiene a favor, en positivo. `0` si no tiene.
  double get saldoAFavorUSD => aFavor ? -saldoUSD : 0;

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
      eliminado: (data['eliminado'] as bool?) ?? false,
      eliminadoEn: (data['eliminadoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'saldoUSD': saldoUSD,
        'actualizadoEn': Timestamp.fromDate(actualizadoEn),
        'eliminado': eliminado,
        'eliminadoEn':
            eliminadoEn == null ? null : Timestamp.fromDate(eliminadoEn!),
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
    this.importado = false,
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

  /// Este movimiento vino del cuaderno de papel, no de una venta de hoy.
  ///
  /// La deuda es real y suma al saldo como cualquier otra, pero **no es plata
  /// que se fió hoy**: se anotó hoy y ya existía. Sin distinguirlo, copiar un
  /// cuaderno con veinte deudas viejas hacía que el Resumen del día declarara
  /// cientos de dólares de fiado otorgado esa tarde y el arqueo saliera
  /// descuadrado por un dinero que nunca pasó por la caja.
  final bool importado;

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
      importado: (data['importado'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.id,
        'montoUSD': montoUSD,
        'negocioId': negocioId,
        'concepto': concepto,
        'fecha': Timestamp.fromDate(fecha),
        'registradoPor': registradoPor,
        'importado': importado,
      };
}
