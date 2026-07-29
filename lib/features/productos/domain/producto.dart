import 'package:cloud_firestore/cloud_firestore.dart';

import 'insumo.dart';
import 'variante.dart';

/// Cómo se gestiona el inventario de este producto.
enum TipoProducto {
  simple,
  variantes,
  serial;

  String get id => name;

  static TipoProducto fromId(String? id) => switch (id) {
        'variantes' => TipoProducto.variantes,
        'serial' => TipoProducto.serial,
        _ => TipoProducto.simple,
      };
}

/// Producto del inventario (CLAUDE.md §4: `negocios/{id}/productos/{id}`).
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.precio,
    this.costo,
    required this.cantidad,
    this.fotoUrl,
    this.variantes = const [],
    this.alertaEn,
    this.fechaVencimiento,
    this.codigoBarras,
    this.vendidoPorPeso = false,
    this.tipo = TipoProducto.simple,
    this.bloquearAlAgotarse = false,
    this.precioAnterior,
    this.enOferta = false,
    this.garantiaMeses,
    this.receta = const [],
  });

  final String id;
  final String nombre;
  final String categoria;

  /// Precio en USD (CLAUDE.md §6: los precios se capturan en USD).
  final double precio;

  /// Lo que costó reponer una unidad (o un kilo), en USD. `null` si el dueño
  /// no lo ha registrado: la ganancia de ese producto no se puede calcular y
  /// se dice así, en vez de inventar que costó cero.
  final double? costo;

  /// Stock disponible. Si hay [variantes], es la suma de sus cantidades.
  ///
  /// Es decimal porque los productos [vendidoPorPeso] se descuentan en kilos
  /// fraccionados (medio kilo de arroz deja 49,5 y no 49).
  final double cantidad;
  final String? fotoUrl;
  final List<Variante> variantes;

  /// Umbral de stock bajo para alertas.
  final int? alertaEn;

  /// Solo belleza.
  final DateTime? fechaVencimiento;

  /// Código de barras escaneado al dar de alta el producto (pantalla 6).
  final String? codigoBarras;

  /// Se vende por kilogramos: al cobrar se pide el peso y el precio se calcula
  /// como `precio × kg` en vez de por unidad.
  final bool vendidoPorPeso;

  /// Cómo se gestiona el inventario: simple, con variantes, o con serial.
  final TipoProducto tipo;

  /// Si `true`, no permite vender este producto cuando el stock llegue a 0.
  final bool bloquearAlAgotarse;

  /// Precio anterior (tachado) cuando está en oferta. `null` si no aplica.
  final double? precioAnterior;

  /// `true` cuando el producto tiene un precio promocional vigente.
  final bool enOferta;

  /// Meses de garantía (solo Electrónica). `null` = sin garantía.
  final int? garantiaMeses;

  /// Qué insumos consume una unidad de este producto (solo los rubros que
  /// cocinan o arman). Al vender se descuentan del inventario de insumos.
  final List<LineaReceta> receta;

  bool get tieneReceta => receta.isNotEmpty;

  /// Porcentaje de descuento derivado, para pintar "−16 %".
  int? get descuentoPct {
    if (!enOferta || precioAnterior == null || precioAnterior == 0) return null;
    return ((precioAnterior! - precio) / precioAnterior! * 100).round();
  }

  /// `true` si el precio de oferta es el vigente (el getter `precio` siempre
  /// es el vigente; `precioAnterior` es el tachado).
  bool get tieneOferta => enOferta && precioAnterior != null;

  bool get tieneVariantes => variantes.isNotEmpty;

  /// `true` si el stock está en o por debajo del umbral configurado.
  bool get stockBajo => alertaEn != null && cantidad <= alertaEn!;

  /// Stock listo para pintar: "23" si es entero, "1,5 kg" si se vende por peso.
  String get cantidadLabel => formatearCantidad(cantidad, vendidoPorPeso);

  /// Oculta los decimales cuando no aportan nada ("23" en vez de "23,0").
  static String formatearCantidad(double valor, bool porPeso) {
    final texto = valor == valor.roundToDouble()
        ? valor.toStringAsFixed(0)
        : valor.toStringAsFixed(2).replaceAll('.', ',');
    return porPeso ? '$texto kg' : texto;
  }

  factory Producto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Producto(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      categoria: (data['categoria'] as String?) ?? '',
      precio: (data['precio'] as num?)?.toDouble() ?? 0,
      costo: (data['costo'] as num?)?.toDouble(),
      cantidad: (data['cantidad'] as num?)?.toDouble() ?? 0,
      fotoUrl: data['fotoUrl'] as String?,
      variantes: ((data['variantes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Variante.fromMap)
          .toList(),
      alertaEn: (data['alertaEn'] as num?)?.toInt(),
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      codigoBarras: data['codigoBarras'] as String?,
      vendidoPorPeso: (data['vendidoPorPeso'] as bool?) ?? false,
      tipo: TipoProducto.fromId(data['tipo'] as String?),
      bloquearAlAgotarse: (data['bloquearAlAgotarse'] as bool?) ?? false,
      precioAnterior: (data['precioAnterior'] as num?)?.toDouble(),
      enOferta: (data['enOferta'] as bool?) ?? false,
      garantiaMeses: (data['garantiaMeses'] as num?)?.toInt(),
      receta: ((data['receta'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LineaReceta.fromMap)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'categoria': categoria,
        'precio': precio,
        'costo': costo,
        'cantidad': cantidad,
        'fotoUrl': fotoUrl,
        'variantes': variantes.map((v) => v.toMap()).toList(),
        'alertaEn': alertaEn,
        'fechaVencimiento': fechaVencimiento == null
            ? null
            : Timestamp.fromDate(fechaVencimiento!),
        'codigoBarras': codigoBarras,
        'vendidoPorPeso': vendidoPorPeso,
        'tipo': tipo.id,
        'bloquearAlAgotarse': bloquearAlAgotarse,
        'precioAnterior': precioAnterior,
        'enOferta': enOferta,
        'garantiaMeses': garantiaMeses,
        'receta': receta.map((l) => l.toMap()).toList(),
      };
}
