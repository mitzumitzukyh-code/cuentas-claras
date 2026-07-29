/// Un producto en el carrito de cobro.
///
/// La variante se guarda como valor + color (los mismos dos campos que lleva
/// [ItemVenta]) y no como un id sintético: es lo que el repositorio necesita
/// para encontrar la casilla que hay que descontar dentro del arreglo
/// `variantes` del producto.
class ItemCarrito {
  const ItemCarrito({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    this.cantidad = 1,
    this.varianteValor,
    this.varianteColor,
    this.pesoKg,
    this.fotoUrl,
    this.precioAnterior,
  });

  final String productoId;
  final String nombre;
  final double precioUnitario;
  final int cantidad;
  final String? varianteValor;
  final String? varianteColor;
  final double? pesoKg;
  final String? fotoUrl;
  final double? precioAnterior;

  double get subtotal => precioUnitario * cantidad;

  bool get tieneVariante => varianteValor != null;

  /// "Franela" o "Franela · M / Rojo".
  String get nombreCompleto {
    if (varianteValor == null || varianteValor!.isEmpty) return nombre;
    final color = varianteColor == null || varianteColor!.isEmpty
        ? ''
        : ' / $varianteColor';
    return '$nombre · $varianteValor$color';
  }

  ItemCarrito copyWith({int? cantidad}) {
    return ItemCarrito(
      productoId: productoId,
      nombre: nombre,
      precioUnitario: precioUnitario,
      cantidad: cantidad ?? this.cantidad,
      varianteValor: varianteValor,
      varianteColor: varianteColor,
      pesoKg: pesoKg,
      fotoUrl: fotoUrl,
      precioAnterior: precioAnterior,
    );
  }
}
