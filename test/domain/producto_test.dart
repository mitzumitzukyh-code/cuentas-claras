import 'package:cuentaclara/features/productos/domain/producto.dart';
import 'package:cuentaclara/features/productos/domain/variante.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Variante', () {
    test('fromMap con todas las claves', () {
      final v = Variante.fromMap({'valor': 'M', 'color': 'Rojo', 'cantidad': 10});
      expect(v.valor, 'M');
      expect(v.color, 'Rojo');
      expect(v.cantidad, 10);
    });

    test('fromMap acepta talla/tono como alias de valor', () {
      final v1 = Variante.fromMap({'talla': 'XL', 'cantidad': 5});
      expect(v1.valor, 'XL');
      final v2 = Variante.fromMap({'tono': 'Oscuro', 'cantidad': 3});
      expect(v2.valor, 'Oscuro');
    });

    test('fromMap defaults for missing keys', () {
      final v = Variante.fromMap({});
      expect(v.valor, '');
      expect(v.color, null);
      expect(v.cantidad, 0);
    });

    test('toMap roundtrip', () {
      final v = Variante(valor: 'S', color: 'Azul', cantidad: 7);
      final map = v.toMap();
      expect(map['valor'], 'S');
      expect(map['color'], 'Azul');
      expect(map['cantidad'], 7);
      final v2 = Variante.fromMap(map);
      expect(v2.valor, v.valor);
      expect(v2.color, v.color);
      expect(v2.cantidad, v.cantidad);
    });

    test('copyWith preserves unchanged fields', () {
      final v = Variante(valor: 'M', color: 'Verde', cantidad: 3);
      final v2 = v.copyWith(cantidad: 5);
      expect(v2.valor, 'M');
      expect(v2.color, 'Verde');
      expect(v2.cantidad, 5);
    });
  });

  group('Producto', () {
    const base = Producto(
      id: 'p1',
      nombre: 'Arroz',
      categoria: 'Víveres',
      precio: 1.5,
      cantidad: 50,
    );

    test('constructor y getters basicos', () {
      expect(base.id, 'p1');
      expect(base.nombre, 'Arroz');
      expect(base.precio, 1.5);
      expect(base.cantidad, 50);
      expect(base.tieneVariantes, false);
    });

    test('stockBajo con alerta activa', () {
      final p = Producto(
        id: 'p2',
        nombre: 'Leche',
        categoria: 'Víveres',
        precio: 2.0,
        cantidad: 5,
        alertaEn: 10,
      );
      expect(p.stockBajo, true);
    });

    test('stockBajo false si cantidad > alerta', () {
      final p = Producto(
        id: 'p3',
        nombre: 'Leche',
        categoria: 'Víveres',
        precio: 2.0,
        cantidad: 15,
        alertaEn: 10,
      );
      expect(p.stockBajo, false);
    });

    test('stockBajo false si no hay alertaEn', () {
      expect(base.stockBajo, false);
    });

    test('tieneVariantes true si hay variantes', () {
      final p = Producto(
        id: 'p4',
        nombre: 'Camisa',
        categoria: 'Ropa',
        precio: 15.0,
        cantidad: 20,
        variantes: [Variante(valor: 'M', cantidad: 10)],
      );
      expect(p.tieneVariantes, true);
    });

    group('cantidadLabel', () {
      test('entero sin peso', () {
        final p = Producto(
          id: 'p1',
          nombre: 'Prod',
          categoria: 'X',
          precio: 1,
          cantidad: 23,
        );
        expect(p.cantidadLabel, '23');
      });

      test('con decimales sin peso', () {
        final p = Producto(
          id: 'p1',
          nombre: 'Prod',
          categoria: 'X',
          precio: 1,
          cantidad: 1.5,
        );
        expect(p.cantidadLabel, '1,50');
      });

      test('entero por peso', () {
        final p = Producto(
          id: 'p1',
          nombre: 'Prod',
          categoria: 'X',
          precio: 1,
          cantidad: 10,
          vendidoPorPeso: true,
        );
        expect(p.cantidadLabel, '10 kg');
      });

      test('decimal por peso', () {
        final p = Producto(
          id: 'p1',
          nombre: 'Prod',
          categoria: 'X',
          precio: 1,
          cantidad: 1.5,
          vendidoPorPeso: true,
        );
        expect(p.cantidadLabel, '1,50 kg');
      });
    });

    group('formatearCantidad', () {
      test('entero sin peso', () {
        expect(Producto.formatearCantidad(23, false), '23');
      });

      test('decimal sin peso', () {
        expect(Producto.formatearCantidad(1.5, false), '1,50');
      });

      test('entero con peso', () {
        expect(Producto.formatearCantidad(10, true), '10 kg');
      });
    });

    group('toMap serialization', () {
      test('serializa campos basicos', () {
        final map = base.toMap();
        expect(map['nombre'], 'Arroz');
        expect(map['categoria'], 'Víveres');
        expect(map['precio'], 1.5);
        expect(map['cantidad'], 50);
        expect(map['variantes'], []);
        expect(map['vendidoPorPeso'], false);
      });

      test('serializa con campos opcionales', () {
        final p = Producto(
          id: 'p5',
          nombre: 'Shampoo',
          categoria: 'Belleza',
          precio: 5.0,
          costo: 3.0,
          cantidad: 30,
          fotoUrl: 'https://foto.com/img.jpg',
          variantes: [Variante(valor: '200ml', cantidad: 15)],
          alertaEn: 5,
          codigoBarras: '123456789',
          vendidoPorPeso: false,
        );
        final map = p.toMap();
        expect(map['costo'], 3.0);
        expect(map['fotoUrl'], 'https://foto.com/img.jpg');
        expect(map['alertaEn'], 5);
        expect(map['codigoBarras'], '123456789');
        expect(map['variantes'], isA<List>());
        expect((map['variantes'] as List).length, 1);
      });

      test('serializa fechaVencimiento', () {
        final fecha = DateTime(2026, 12, 31);
        final p = Producto(
          id: 'p6',
          nombre: 'Crema',
          categoria: 'Belleza',
          precio: 8.0,
          cantidad: 10,
          fechaVencimiento: fecha,
        );
        final map = p.toMap();
        expect(map['fechaVencimiento'], isNotNull);
      });
    });
  });
}
