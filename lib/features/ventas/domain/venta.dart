import 'package:cloud_firestore/cloud_firestore.dart';

import '../../productos/domain/producto.dart';

/// Forma de pago de una venta (bloque `metodosPago` del diseño).
enum MetodoPago {
  efectivo,
  pagoMovil,
  transferencia,
  zelle,
  biopago,
  puntoDeVenta;

  /// ID persistido en Firestore.
  String get id => switch (this) {
        MetodoPago.efectivo => 'efectivo',
        MetodoPago.pagoMovil => 'pagomovil',
        MetodoPago.transferencia => 'transferencia',
        MetodoPago.zelle => 'zelle',
        MetodoPago.biopago => 'biopago',
        MetodoPago.puntoDeVenta => 'puntos',
      };

  static MetodoPago fromId(String? id) => MetodoPago.values.firstWhere(
        (m) => m.id == id,
        orElse: () => MetodoPago.efectivo,
      );

  String get etiqueta => switch (this) {
        MetodoPago.efectivo => '💵 Efectivo',
        MetodoPago.pagoMovil => '📲 Pago móvil',
        MetodoPago.transferencia => '🏦 Transferencia',
        MetodoPago.zelle => '💰 Zelle',
        MetodoPago.biopago => '👆 BioPago',
        MetodoPago.puntoDeVenta => '💳 Punto de venta',
      };

  /// Versión corta para los chips del carrito, donde no cabe el texto largo.
  String get etiquetaCorta => switch (this) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.pagoMovil => 'Pago móvil',
        MetodoPago.transferencia => 'Transfer.',
        MetodoPago.zelle => 'Zelle',
        MetodoPago.biopago => 'BioPago',
        MetodoPago.puntoDeVenta => 'Punto',
      };
}

/// Una línea del carrito / de una venta (CLAUDE.md §4).
class ItemVenta {
  const ItemVenta({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
    this.vendidoPorPeso = false,
  });

  final String productoId;
  final String nombre;

  /// Unidades, o kilos si [vendidoPorPeso].
  final double cantidad;

  /// Precio unitario (o por kilo) en USD al momento de la venta.
  final double precioUnitario;

  final bool vendidoPorPeso;

  double get subtotal => cantidad * precioUnitario;

  String get cantidadLabel =>
      Producto.formatearCantidad(cantidad, vendidoPorPeso);

  factory ItemVenta.fromMap(Map<String, dynamic> map) => ItemVenta(
        productoId: (map['productoId'] as String?) ?? '',
        nombre: (map['nombre'] as String?) ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
        precioUnitario: (map['precioUnitario'] as num?)?.toDouble() ?? 0,
        vendidoPorPeso: (map['vendidoPorPeso'] as bool?) ?? false,
      );

  Map<String, dynamic> toMap() => {
        'productoId': productoId,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'vendidoPorPeso': vendidoPorPeso,
      };

  ItemVenta copyWith({double? cantidad}) => ItemVenta(
        productoId: productoId,
        nombre: nombre,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario,
        vendidoPorPeso: vendidoPorPeso,
      );
}

/// Una venta registrada (CLAUDE.md §4: `negocios/{id}/ventas/{id}`).
///
/// Nunca se borra: al anular se marca [anulada] = true y se restituye el
/// inventario (CLAUDE.md §6).
class Venta {
  const Venta({
    required this.id,
    required this.items,
    required this.totalUSD,
    required this.totalBs,
    required this.tasaBcvUsada,
    required this.vendidoPor,
    required this.fecha,
    this.anulada = false,
    this.metodoPago = MetodoPago.efectivo,
    this.descuentoPct = 0,
    this.ivaUSD = 0,
    this.pendiente = false,
  });

  final String id;
  final List<ItemVenta> items;

  /// Total finalmente cobrado: subtotal − descuento + IVA.
  final double totalUSD;

  final double totalBs;
  final double tasaBcvUsada;
  final String vendidoPor;
  final DateTime fecha;
  final bool anulada;

  final MetodoPago metodoPago;

  /// Porcentaje de descuento aplicado (0, 5, 10, 15 o 20).
  final int descuentoPct;

  /// IVA cobrado en USD. `0` si el negocio no lo tiene activado.
  final double ivaUSD;

  /// `true` si esta venta todavía vive solo en el teléfono y no se ha
  /// confirmado con el servidor (venta hecha sin señal).
  ///
  /// No se guarda en Firestore: se calcula en cada lectura a partir de
  /// `SnapshotMetadata.hasPendingWrites`, así que es tan real como pueda
  /// serlo — no depende de que nadie lo actualice a mano.
  final bool pendiente;

  /// Suma de las líneas, antes de descuento e IVA.
  double get subtotalUSD => items.fold<double>(0, (s, i) => s + i.subtotal);

  double get descuentoUSD => subtotalUSD * descuentoPct / 100;

  factory Venta.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Venta(
      id: doc.id,
      pendiente: doc.metadata.hasPendingWrites,
      items: ((data['items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ItemVenta.fromMap)
          .toList(),
      totalUSD: (data['totalUSD'] as num?)?.toDouble() ?? 0,
      totalBs: (data['totalBs'] as num?)?.toDouble() ?? 0,
      tasaBcvUsada: (data['tasaBcvUsada'] as num?)?.toDouble() ?? 0,
      vendidoPor: (data['vendidoPor'] as String?) ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      anulada: (data['anulada'] as bool?) ?? false,
      metodoPago: MetodoPago.fromId(data['metodoPago'] as String?),
      descuentoPct: (data['descuentoPct'] as num?)?.toInt() ?? 0,
      ivaUSD: (data['ivaUSD'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'items': items.map((i) => i.toMap()).toList(),
        'totalUSD': totalUSD,
        'totalBs': totalBs,
        'tasaBcvUsada': tasaBcvUsada,
        'vendidoPor': vendidoPor,
        'fecha': Timestamp.fromDate(fecha),
        'anulada': anulada,
        'metodoPago': metodoPago.id,
        'descuentoPct': descuentoPct,
        'ivaUSD': ivaUSD,
      };
}
