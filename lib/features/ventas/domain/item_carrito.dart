/// Un producto en el carrito de cobro.
class ItemCarrito {
  const ItemCarrito({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    this.cantidad = 1,
    this.varianteId,
    this.pesoKg,
    this.fotoUrl,
    this.precioAnterior,
  });

  final String productoId;
  final String nombre;
  final double precioUnitario;
  final int cantidad;
  final String? varianteId;
  final double? pesoKg;
  final String? fotoUrl;
  final double? precioAnterior;

  double get subtotal => precioUnitario * cantidad;

  bool get tieneVariante => varianteId != null;

  ItemCarrito copyWith({int? cantidad}) {
    return ItemCarrito(
      productoId: productoId,
      nombre: nombre,
      precioUnitario: precioUnitario,
      cantidad: cantidad ?? this.cantidad,
      varianteId: varianteId,
      pesoKg: pesoKg,
      fotoUrl: fotoUrl,
      precioAnterior: precioAnterior,
    );
  }
}
