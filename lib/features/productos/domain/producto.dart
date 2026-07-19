import 'package:cloud_firestore/cloud_firestore.dart';

import 'variante.dart';

/// Producto del inventario (CLAUDE.md §4: `negocios/{id}/productos/{id}`).
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.precio,
    required this.cantidad,
    this.fotoUrl,
    this.variantes = const [],
    this.alertaEn,
    this.fechaVencimiento,
    this.codigoBarras,
    this.vendidoPorPeso = false,
  });

  final String id;
  final String nombre;
  final String categoria;

  /// Precio en USD (CLAUDE.md §6: los precios se capturan en USD).
  final double precio;

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
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'categoria': categoria,
        'precio': precio,
        'cantidad': cantidad,
        'fotoUrl': fotoUrl,
        'variantes': variantes.map((v) => v.toMap()).toList(),
        'alertaEn': alertaEn,
        'fechaVencimiento': fechaVencimiento == null
            ? null
            : Timestamp.fromDate(fechaVencimiento!),
        'codigoBarras': codigoBarras,
        'vendidoPorPeso': vendidoPorPeso,
      };
}
