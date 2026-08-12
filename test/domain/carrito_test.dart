import 'package:cuentaclara/features/ventas/data/carrito_provider.dart';
import 'package:cuentaclara/features/ventas/domain/item_carrito.dart';
import 'package:flutter_test/flutter_test.dart';

ItemCarrito _item(
  String id, {
  double precio = 1.5,
  int cantidad = 1,
  String? valor,
  String? color,
}) =>
    ItemCarrito(
      productoId: id,
      nombre: 'Producto $id',
      precioUnitario: precio,
      cantidad: cantidad,
      varianteValor: valor,
      varianteColor: color,
    );

void main() {
  group('ItemCarrito', () {
    test('subtotal es precio × cantidad', () {
      expect(_item('a', precio: 2.5, cantidad: 3).subtotal, 7.5);
    });

    test('nombreCompleto sin variante es solo el nombre', () {
      expect(_item('a').nombreCompleto, 'Producto a');
    });

    test('nombreCompleto con valor y color', () {
      expect(
        _item('a', valor: 'M', color: 'Rojo').nombreCompleto,
        'Producto a · M / Rojo',
      );
    });
  });

  group('CarritoNotifier', () {
    test('agregar el mismo producto incrementa, no duplica la fila', () {
      final c = CarritoNotifier()
        ..agregar(_item('a'))
        ..agregar(_item('a'));

      expect(c.state.length, 1);
      expect(c.state.first.cantidad, 2);
      expect(c.cantidad, 2);
    });

    test('dos variantes del mismo producto son filas distintas', () {
      final c = CarritoNotifier()
        ..agregar(_item('a', valor: 'M'))
        ..agregar(_item('a', valor: 'L'));

      expect(c.state.length, 2);
    });

    test('quitar baja una unidad y elimina la fila al llegar a cero', () {
      final c = CarritoNotifier()..agregar(_item('a', cantidad: 2));

      c.quitar(0);
      expect(c.state.single.cantidad, 1);

      c.quitar(0);
      expect(c.state, isEmpty);
    });

    test('quitar con índice fuera de rango no rompe', () {
      final c = CarritoNotifier()..agregar(_item('a'));
      c.quitar(7);
      expect(c.state.length, 1);
    });

    test('total suma los subtotales de todas las líneas', () {
      final c = CarritoNotifier()
        ..agregar(_item('a', precio: 2, cantidad: 3))
        ..agregar(_item('b', precio: 0.5));

      expect(c.total, 6.5);
    });

    test('ponerCantidad en 0 elimina la línea', () {
      final c = CarritoNotifier()..agregar(_item('a', cantidad: 4));
      c.ponerCantidad(0, 0);
      expect(c.state, isEmpty);
    });

    test('vaciar deja el carrito en cero', () {
      final c = CarritoNotifier()
        ..agregar(_item('a'))
        ..agregar(_item('b'))
        ..vaciar();

      expect(c.state, isEmpty);
      expect(c.total, 0);
    });
  });

  _pruebasDePeso();
}

// ── Venta por peso ────────────────────────────────────────────────────────
//
// El carrito era el único eslabón de la cadena que trabajaba en enteros:
// `ItemVenta.cantidad` y `Producto.cantidad` siempre fueron `double`. Cobrar
// preguntaba «¿cuántos kg?» y guardaba la respuesta con `.round()`.

ItemCarrito _porPeso(String id, {double precio = 8, required double kg}) =>
    ItemCarrito(
      productoId: id,
      nombre: 'Queso $id',
      precioUnitario: precio,
      pesoKg: kg,
    );


void _pruebasDePeso() {
  group('ItemCarrito por peso', () {
    test('cobra el peso exacto, no el redondeado', () {
      // 2,5 kg de queso a $8: $20. Con `.round()` se cobraban 3 kg = $24.
      expect(_porPeso('q', kg: 2.5).subtotal, 20);
    });

    test('un peso menor a medio kilo se cobra, no se regala', () {
      // 0,4 kg redondeaba a 0 y la línea entraba en $0,00.
      final i = _porPeso('q', kg: 0.4);
      expect(i.cantidadCobrada, 0.4);
      expect(i.subtotal, closeTo(3.2, 0.001));
    });

    test('cantidadCobrada usa unidades cuando no hay peso', () {
      expect(_item('a', cantidad: 3).cantidadCobrada, 3);
      expect(_item('a', cantidad: 3).porPeso, isFalse);
    });

    test('la etiqueta lleva kg solo si se vende por peso', () {
      expect(_porPeso('q', kg: 2.5).cantidadLabel, '2,50 kg');
      expect(_porPeso('q', kg: 3).cantidadLabel, '3 kg');
      expect(_item('a', cantidad: 3).cantidadLabel, '3');
    });
  });

  group('CarritoNotifier con peso', () {
    test('pesar dos veces el mismo producto suma kilos, no unidades', () {
      final c = CarritoNotifier()
        ..agregar(_porPeso('q', kg: 0.5))
        ..agregar(_porPeso('q', kg: 0.3));
      expect(c.state, hasLength(1));
      expect(c.state.single.pesoKg, closeTo(0.8, 0.001));
      expect(c.state.single.subtotal, closeTo(6.4, 0.001));
    });

    test('quitar una línea por peso la saca entera', () {
      // "Una unidad menos" de 2,5 kg no significa nada.
      final c = CarritoNotifier()..agregar(_porPeso('q', kg: 2.5));
      c.quitar(0);
      expect(c.state, isEmpty);
    });

    test('quitar en una línea por unidades sigue descontando de a una', () {
      final c = CarritoNotifier()..agregar(_item('a', cantidad: 3));
      c.quitar(0);
      expect(c.state.single.cantidad, 2);
    });
  });
}
