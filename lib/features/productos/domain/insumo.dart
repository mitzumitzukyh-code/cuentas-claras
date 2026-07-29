import 'package:cloud_firestore/cloud_firestore.dart';

/// Unidad en la que se lleva un insumo.
///
/// Son pocas y fijas a propósito: si cada quien escribe la suya ("gr", "grs",
/// "gramos") la receta deja de poder descontar nada.
enum UnidadInsumo {
  gramo,
  kilo,
  mililitro,
  litro,
  unidad;

  String get id => name;

  static UnidadInsumo fromId(String? id) => UnidadInsumo.values.firstWhere(
        (u) => u.id == id,
        orElse: () => UnidadInsumo.unidad,
      );

  /// Abreviatura para las listas ("500 g", "4 uds").
  String get corta => switch (this) {
        UnidadInsumo.gramo => 'g',
        UnidadInsumo.kilo => 'kg',
        UnidadInsumo.mililitro => 'ml',
        UnidadInsumo.litro => 'L',
        UnidadInsumo.unidad => 'uds',
      };

  String get etiqueta => switch (this) {
        UnidadInsumo.gramo => 'Gramos',
        UnidadInsumo.kilo => 'Kilos',
        UnidadInsumo.mililitro => 'Mililitros',
        UnidadInsumo.litro => 'Litros',
        UnidadInsumo.unidad => 'Unidades',
      };
}

/// Materia prima del negocio (CLAUDE.md §4: `negocios/{id}/insumos/{id}`).
///
/// Solo lo usan los rubros que cocinan o arman lo que venden: la harina no se
/// vende, se convierte en tortas.
class Insumo {
  const Insumo({
    required this.id,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    this.alertaEn,
  });

  final String id;
  final String nombre;

  /// Existencia actual, en [unidad]. Decimal porque medio kilo es medio kilo.
  final double cantidad;
  final UnidadInsumo unidad;

  /// Umbral de aviso, en la misma unidad. `null` = sin aviso.
  final double? alertaEn;

  bool get stockBajo => alertaEn != null && cantidad <= alertaEn!;

  /// "500 g", "2,5 kg".
  String get cantidadLabel => '${numero(cantidad)} ${unidad.corta}';

  static String numero(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');

  factory Insumo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Insumo(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      cantidad: (data['cantidad'] as num?)?.toDouble() ?? 0,
      unidad: UnidadInsumo.fromId(data['unidad'] as String?),
      alertaEn: (data['alertaEn'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'cantidad': cantidad,
        'unidad': unidad.id,
        'alertaEn': alertaEn,
      };

  Insumo copyWith({String? nombre, double? cantidad, UnidadInsumo? unidad, double? alertaEn}) =>
      Insumo(
        id: id,
        nombre: nombre ?? this.nombre,
        cantidad: cantidad ?? this.cantidad,
        unidad: unidad ?? this.unidad,
        alertaEn: alertaEn ?? this.alertaEn,
      );
}

/// Una línea de la receta de un producto: cuánto de un insumo se consume al
/// vender una unidad (CLAUDE.md §4: `productos/{id}.receta[]`).
///
/// Guarda el nombre y la unidad además del id porque la receta se lee al
/// pintar el producto y cruzar la colección de insumos por cada línea saldría
/// carísimo. El id manda a la hora de descontar.
class LineaReceta {
  const LineaReceta({
    required this.insumoId,
    required this.nombre,
    required this.cantidadUsada,
    required this.unidad,
  });

  final String insumoId;
  final String nombre;
  final double cantidadUsada;
  final UnidadInsumo unidad;

  String get cantidadLabel => '${Insumo.numero(cantidadUsada)} ${unidad.corta}';

  factory LineaReceta.fromMap(Map<String, dynamic> map) => LineaReceta(
        insumoId: (map['insumoId'] as String?) ?? '',
        nombre: (map['nombre'] as String?) ?? '',
        cantidadUsada: (map['cantidadUsada'] as num?)?.toDouble() ?? 0,
        unidad: UnidadInsumo.fromId(map['unidad'] as String?),
      );

  Map<String, dynamic> toMap() => {
        'insumoId': insumoId,
        'nombre': nombre,
        'cantidadUsada': cantidadUsada,
        'unidad': unidad.id,
      };
}
