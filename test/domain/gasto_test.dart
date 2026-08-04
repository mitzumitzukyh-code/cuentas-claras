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

  group('Gasto · tasa congelada', () {
    test('montoBs usa la tasa del día en que se registró', () {
      final gasto = Gasto(
        id: 'g5',
        categoria: CategoriaGasto.mercancia,
        descripcion: 'Harina',
        monto: 10,
        fecha: _fecha,
        tasaUsada: 100,
      );
      expect(gasto.montoBs, 1000);
    });

    test('sin tasa guardada no se inventa una conversión', () {
      final gasto = Gasto(
        id: 'g6',
        categoria: CategoriaGasto.mercancia,
        descripcion: 'Viejo',
        monto: 10,
        fecha: _fecha,
      );
      // Los gastos anteriores al campo se muestran solo en USD: convertirlos
      // con la tasa de hoy haría que su monto en Bs cambiara cada mañana.
      expect(gasto.montoBs, isNull);
      expect(gasto.toMap()['tasaUsada'], isNull);
    });

    test('editar no reescribe la tasa ni las marcas de borrado', () {
      final original = Gasto(
        id: 'g7',
        categoria: CategoriaGasto.mercancia,
        descripcion: 'Antes',
        monto: 10,
        fecha: _fecha,
        tasaUsada: 100,
      );
      final editado = original.copyWith(descripcion: 'Después', monto: 12);
      expect(editado.descripcion, 'Después');
      expect(editado.monto, 12);
      expect(editado.tasaUsada, 100);
      expect(editado.id, 'g7');
    });
  });

  group('Gasto · borrado lógico', () {
    test('por defecto no está eliminado', () {
      final gasto = Gasto(
        id: 'g8',
        categoria: CategoriaGasto.otro,
        descripcion: 'Vivo',
        monto: 5,
        fecha: _fecha,
      );
      expect(gasto.eliminado, false);
      expect(gasto.eliminadoEn, isNull);
      expect(gasto.toMap()['eliminado'], false);
    });

    test('un gasto eliminado conserva sus datos y la marca', () {
      final gasto = Gasto(
        id: 'g9',
        categoria: CategoriaGasto.otro,
        descripcion: 'Borrado',
        monto: 5,
        fecha: _fecha,
        eliminado: true,
        eliminadoEn: DateTime(2026, 8, 3),
      );
      final map = gasto.toMap();
      expect(map['eliminado'], true);
      expect(map['eliminadoEn'], isNotNull);
      // El documento no se destruye: los reportes tienen que poder auditar
      // qué se quitó y cuándo.
      expect(map['monto'], 5);
      expect(map['descripcion'], 'Borrado');
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
