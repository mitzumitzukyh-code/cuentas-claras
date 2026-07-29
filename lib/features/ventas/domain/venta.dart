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
    this.costoUnitario,
    this.varianteValor,
    this.varianteColor,
    this.vendidoPorPeso = false,
    this.fotoUrl,
  });

  final String productoId;
  final String nombre;

  /// Foto del producto al momento de la venta. Se congela aquí (igual que
  /// [costoUnitario]) para que el detalle de una venta vieja siga mostrando
  /// la foto aunque el producto la haya cambiado o se haya borrado después.
  final String? fotoUrl;

  /// Unidades, o kilos si [vendidoPorPeso].
  final double cantidad;

  /// Precio unitario (o por kilo) en USD al momento de la venta.
  final double precioUnitario;

  /// Costo unitario en USD al momento de la venta. Se congela aquí para que
  /// la ganancia histórica no cambie cuando el dueño actualice el costo del
  /// producto. `null` = el producto no tenía costo registrado.
  final double? costoUnitario;

  /// Variante vendida (talla/tono y color), si el producto las tiene.
  final String? varianteValor;
  final String? varianteColor;

  final bool vendidoPorPeso;

  double get subtotal => cantidad * precioUnitario;

  String get cantidadLabel =>
      Producto.formatearCantidad(cantidad, vendidoPorPeso);

  /// "Franela" o "Franela · M / Rojo" si es una variante.
  String get nombreCompleto {
    if (varianteValor == null || varianteValor!.isEmpty) return nombre;
    final color = varianteColor == null || varianteColor!.isEmpty
        ? ''
        : ' / $varianteColor';
    return '$nombre · $varianteValor$color';
  }

  factory ItemVenta.fromMap(Map<String, dynamic> map) => ItemVenta(
        productoId: (map['productoId'] as String?) ?? '',
        nombre: (map['nombre'] as String?) ?? '',
        cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0,
        precioUnitario: (map['precioUnitario'] as num?)?.toDouble() ?? 0,
        costoUnitario: (map['costoUnitario'] as num?)?.toDouble(),
        varianteValor: map['varianteValor'] as String?,
        varianteColor: map['varianteColor'] as String?,
        vendidoPorPeso: (map['vendidoPorPeso'] as bool?) ?? false,
        fotoUrl: map['fotoUrl'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'productoId': productoId,
        'nombre': nombre,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
        'costoUnitario': costoUnitario,
        'varianteValor': varianteValor,
        'varianteColor': varianteColor,
        'vendidoPorPeso': vendidoPorPeso,
        'fotoUrl': fotoUrl,
      };

  ItemVenta copyWith({double? cantidad}) => ItemVenta(
        productoId: productoId,
        nombre: nombre,
        cantidad: cantidad ?? this.cantidad,
        precioUnitario: precioUnitario,
        costoUnitario: costoUnitario,
        varianteValor: varianteValor,
        varianteColor: varianteColor,
        vendidoPorPeso: vendidoPorPeso,
        fotoUrl: fotoUrl,
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
    this.fiadoClienteId,
    this.fiadoClienteNombre,
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

  /// Cliente al que se le fió esta venta, si se cobró con la pastilla "Fiado"
  /// (Lote B · P0). El movimiento que sube su deuda vive en
  /// `clientes/{id}/movimientos`; esto es solo la contraparte en la venta,
  /// para que el historial pueda decir "fiado · María" sin cruzar colecciones.
  ///
  /// Deliberadamente NO es un valor de [MetodoPago]: el fiado no es una forma
  /// de pago que se configure en Ajustes ni que entre en el efectivo esperado
  /// del cierre de caja — es plata que todavía no entró.
  final String? fiadoClienteId;
  final String? fiadoClienteNombre;

  bool get esFiada => fiadoClienteId != null && fiadoClienteId!.isNotEmpty;

  /// Suma de las líneas, antes de descuento e IVA.
  double get subtotalUSD => items.fold<double>(0, (s, i) => s + i.subtotal);

  double get descuentoUSD => subtotalUSD * descuentoPct / 100;

  /// Ganancia en USD de las líneas con costo conocido: lo cobrado (con el
  /// descuento aplicado, sin el IVA — eso es del fisco) menos lo que costó.
  ///
  /// Las líneas sin costo no suman ni restan: mejor una ganancia parcial y
  /// honesta ([itemsSinCosto] lo delata) que una inflada asumiendo costo cero.
  double get gananciaUSD {
    final factorDescuento = 1 - descuentoPct / 100;
    return items
        .where((i) => i.costoUnitario != null)
        .fold<double>(0, (s, i) {
      return s +
          (i.precioUnitario * factorDescuento - i.costoUnitario!) * i.cantidad;
    });
  }

  /// Cuántas líneas quedaron fuera de [gananciaUSD] por no tener costo.
  int get itemsSinCosto =>
      items.where((i) => i.costoUnitario == null).length;

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
      fiadoClienteId: data['fiadoClienteId'] as String?,
      fiadoClienteNombre: data['fiadoClienteNombre'] as String?,
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
        if (fiadoClienteId != null) 'fiadoClienteId': fiadoClienteId,
        if (fiadoClienteNombre != null)
          'fiadoClienteNombre': fiadoClienteNombre,
      };
}
