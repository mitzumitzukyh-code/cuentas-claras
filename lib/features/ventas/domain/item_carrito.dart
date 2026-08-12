import '../../productos/domain/producto.dart';

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

  /// Unidades enteras. Para lo que se vende por peso manda [pesoKg] y esto
  /// queda en 1 — ver [cantidadCobrada].
  final int cantidad;

  final String? varianteValor;
  final String? varianteColor;

  /// Kilos, cuando el producto se vende por peso. `null` en todo lo demás.
  ///
  /// Existía desde el principio y **no lo escribía ni lo leía nadie**: la
  /// pantalla de Cobrar preguntaba «¿cuántos kg?» y metía la respuesta en
  /// [cantidad] con `.round()`, así que 2,5 kg de queso se cobraban como 3 y
  /// 0,4 kg entraban como 0 — gratis. El resto de la cadena siempre supo de
  /// decimales: `ItemVenta.cantidad` y `Producto.cantidad` son `double`.
  final double? pesoKg;

  final String? fotoUrl;
  final double? precioAnterior;

  /// Se vende por peso.
  bool get porPeso => pesoKg != null;

  /// Lo que de verdad se cobra y se descuenta del inventario: kilos si los
  /// hay, unidades si no. Es la única cifra que debe llegar a [ItemVenta].
  double get cantidadCobrada => pesoKg ?? cantidad.toDouble();

  double get subtotal => precioUnitario * cantidadCobrada;

  /// «3», «2,5 kg». Lo que hay que enseñar en el carrito, en el concepto del
  /// fiado y en la cotización que se manda al cliente: escribir `×1` para una
  /// línea de 2,5 kg de queso es peor que no decir nada.
  String get cantidadLabel =>
      Producto.formatearCantidad(cantidadCobrada, porPeso);

  bool get tieneVariante => varianteValor != null;

  /// "Franela" o "Franela · M / Rojo".
  String get nombreCompleto {
    if (varianteValor == null || varianteValor!.isEmpty) return nombre;
    final color = varianteColor == null || varianteColor!.isEmpty
        ? ''
        : ' / $varianteColor';
    return '$nombre · $varianteValor$color';
  }

  ItemCarrito copyWith({int? cantidad, double? pesoKg}) {
    return ItemCarrito(
      productoId: productoId,
      nombre: nombre,
      precioUnitario: precioUnitario,
      cantidad: cantidad ?? this.cantidad,
      varianteValor: varianteValor,
      varianteColor: varianteColor,
      pesoKg: pesoKg ?? this.pesoKg,
      fotoUrl: fotoUrl,
      precioAnterior: precioAnterior,
    );
  }
}
