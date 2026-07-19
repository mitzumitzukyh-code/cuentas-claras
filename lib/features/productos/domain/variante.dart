/// Variante de un producto, ej: una talla+color específicos (CLAUDE.md §4).
///
/// `valor` guarda la primera dimensión (Talla o Tono según el rubro) y `color`
/// la segunda. Las etiquetas legibles vienen de `RubroConfig.etiquetasVariante`.
class Variante {
  const Variante({
    required this.valor,
    this.color,
    this.cantidad = 0,
  });

  final String valor;
  final String? color;
  final int cantidad;

  factory Variante.fromMap(Map<String, dynamic> map) => Variante(
        valor: (map['valor'] ?? map['talla'] ?? map['tono'] ?? '').toString(),
        color: map['color'] as String?,
        cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'valor': valor,
        'color': color,
        'cantidad': cantidad,
      };

  Variante copyWith({String? valor, String? color, int? cantidad}) => Variante(
        valor: valor ?? this.valor,
        color: color ?? this.color,
        cantidad: cantidad ?? this.cantidad,
      );
}
