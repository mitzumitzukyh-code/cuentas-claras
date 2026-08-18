import 'package:cuentaclara/features/catalogo/domain/seleccion_catalogo.dart';
import 'package:cuentaclara/features/productos/domain/producto.dart';
import 'package:flutter/material.dart' show RangeValues;
import 'package:flutter_test/flutter_test.dart';

Producto _p(String nombre, {double? precio, String categoria = 'Víveres'}) =>
    Producto(
      id: nombre,
      nombre: nombre,
      categoria: categoria,
      precio: precio,
      cantidad: 10,
    );

void main() {
  group('rangoDePrecios', () {
    test('sale del catálogo, no de una escala fija', () {
      final (min, max) = rangoDePrecios([
        _p('Harina', precio: 1.20),
        _p('Café', precio: 2.80),
        _p('Aceite', precio: 8),
      ]);
      expect(min, 1);
      expect(max, 9);
    });

    // Sin margen los dos extremos coinciden y el control no se puede mover.
    test('con un solo producto los extremos no se pegan', () {
      final (min, max) = rangoDePrecios([_p('Harina', precio: 3)]);
      expect(max, greaterThan(min));
    });

    test('un catálogo vacío devuelve un rango usable', () {
      final (min, max) = rangoDePrecios([]);
      expect(max, greaterThan(min));
    });
  });

  group('pasaFiltros', () {
    final harina = _p('Harina PAN 1kg', precio: 1.20);

    test('sin filtros pasa todo', () {
      expect(pasaFiltros(harina), isTrue);
    });

    test('la búsqueda encuentra por trozo y sin importar mayúsculas', () {
      expect(pasaFiltros(harina, busqueda: 'pan'), isTrue);
      expect(pasaFiltros(harina, busqueda: 'PAN'), isTrue);
      expect(pasaFiltros(harina, busqueda: '  pan  '), isTrue);
      expect(pasaFiltros(harina, busqueda: 'arroz'), isFalse);
    });

    test('la categoría filtra exacto', () {
      expect(pasaFiltros(harina, categoria: 'Víveres'), isTrue);
      expect(pasaFiltros(harina, categoria: 'Bebidas'), isFalse);
    });

    test('el rango incluye sus extremos', () {
      expect(pasaFiltros(harina, rango: const RangeValues(1.20, 5)), isTrue);
      expect(pasaFiltros(harina, rango: const RangeValues(0, 1.20)), isTrue);
      expect(pasaFiltros(harina, rango: const RangeValues(2, 5)), isFalse);
    });

    // Filtrar por precio a un producto sin precio sería inventarle una cifra.
    test('un producto sin precio no entra en un rango', () {
      expect(
        pasaFiltros(_p('Sin precio'), rango: const RangeValues(0, 100)),
        isFalse,
      );
    });

    test('los filtros se acumulan', () {
      expect(
        pasaFiltros(
          harina,
          categoria: 'Víveres',
          busqueda: 'pan',
          rango: const RangeValues(1, 2),
        ),
        isTrue,
      );
      expect(
        pasaFiltros(harina, categoria: 'Víveres', busqueda: 'cerveza'),
        isFalse,
      );
    });
  });

  group('filtraAlgo', () {
    test('todo el rango no es un filtro', () {
      expect(filtraAlgo(const RangeValues(1, 9), (1, 9)), isFalse);
    });

    test('recortar cualquiera de los dos lados sí lo es', () {
      expect(filtraAlgo(const RangeValues(2, 9), (1, 9)), isTrue);
      expect(filtraAlgo(const RangeValues(1, 8), (1, 9)), isTrue);
    });
  });

  group('resumenSeleccion', () {
    test('dice cuántos y entre qué precios', () {
      final texto = resumenSeleccion([
        _p('Harina', precio: 1.20),
        _p('Aceite', precio: 8),
        _p('Café', precio: 2.80),
      ]);
      expect(texto, '3 productos · \$1,20 a \$8,00');
    });

    test('con un solo precio no repite el rango', () {
      final texto = resumenSeleccion([
        _p('Harina', precio: 2),
        _p('Café', precio: 2),
      ]);
      expect(texto, '2 productos · \$2,00');
    });

    test('usa el singular con un producto', () {
      expect(resumenSeleccion([_p('Harina', precio: 2)]), '1 producto · \$2,00');
    });

    test('sin nada marcado lo dice en palabras', () {
      expect(resumenSeleccion([]), 'No has marcado ningún producto');
    });
  });
}
