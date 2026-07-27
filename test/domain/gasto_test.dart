import 'package:cuentaclara/features/gastos/domain/gasto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoriaGasto', () {
    test('fromId devuelve el enum correcto', () {
      expect(CategoriaGasto.fromId('mercancia'), CategoriaGasto.mercancia);
      expect(CategoriaGasto.fromId('transporte'), CategoriaGasto.transporte);
      expect(CategoriaGasto.fromId('servicios'), CategoriaGasto.servicios);
      expect(CategoriaGasto.fromId('otro'), CategoriaGasto.otro);
    });

    test('fromId fallback a otro', () {
      expect(CategoriaGasto.fromId('inventado'), CategoriaGasto.otro);
      expect(CategoriaGasto.fromId(null), CategoriaGasto.otro);
    });

    test('etiqueta no vacia', () {
      for (final c in CategoriaGasto.values) {
        expect(c.etiqueta.isNotEmpty, true);
      }
    });

    test('transporte tiene subcategorias', () {
      expect(CategoriaGasto.transporte.subcategorias, isNotEmpty);
    });

    test('servicios tiene subcategorias', () {
      expect(CategoriaGasto.servicios.subcategorias, isNotEmpty);
    });

    test('mercancia no tiene subcategorias', () {
      expect(CategoriaGasto.mercancia.subcategorias, isEmpty);
    });

    test('otro no tiene subcategorias', () {
      expect(CategoriaGasto.otro.subcategorias, isEmpty);
    });
  });

  group('Gasto', () {
    final base = Gasto(
      id: 'g1',
      categoria: CategoriaGasto.mercancia,
      descripcion: 'Compra de inventario',
      monto: 150.0,
      fecha: _fecha,
    );

    test('constructor y getters basicos', () {
      expect(base.id, 'g1');
      expect(base.categoria, CategoriaGasto.mercancia);
      expect(base.descripcion, 'Compra de inventario');
      expect(base.monto, 150.0);
    });

    test('categoriaLabel sin subcategoria', () {
      expect(base.categoriaLabel, '📦 Mercancía');
    });

    test('categoriaLabel con subcategoria', () {
      final gasto = Gasto(
        id: 'g2',
        categoria: CategoriaGasto.transporte,
        subcategoria: 'Flete',
        descripcion: 'Envío',
        monto: 25.0,
        fecha: _fecha,
      );
      expect(gasto.categoriaLabel, '🚚 Transporte · Flete');
    });

    test('toMap serializa campos principales', () {
      final map = base.toMap();
      expect(map['categoria'], 'mercancia');
      expect(map['descripcion'], 'Compra de inventario');
      expect(map['monto'], 150.0);
      expect(map['subcategoria'], null);
    });

    test('toMap con fotoReciboUrl', () {
      final gasto = Gasto(
        id: 'g3',
        categoria: CategoriaGasto.otro,
        descripcion: 'Algo',
        monto: 10.0,
        fecha: _fecha,
        fotoReciboUrl: 'https://foto.com/recibo.jpg',
      );
      final map = gasto.toMap();
      expect(map['fotoReciboUrl'], 'https://foto.com/recibo.jpg');
    });

    test('toMap con subcategoria', () {
      final gasto = Gasto(
        id: 'g4',
        categoria: CategoriaGasto.servicios,
        subcategoria: 'Luz',
        descripcion: 'Factura',
        monto: 30.0,
        fecha: _fecha,
      );
      final map = gasto.toMap();
      expect(map['subcategoria'], 'Luz');
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
