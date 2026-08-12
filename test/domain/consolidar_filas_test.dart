import 'package:cuentaclara/core/utils/confianza.dart';
import 'package:cuentaclara/services/ia/lector_etiqueta_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('consolidarFilas', () {
    test('bodega y repuestos: el mismo código en dos filas suma existencias',
        () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Filtro de aceite', codigo: 'FO-12', cantidad: 3, precio: 5),
        FilaLibreta(nombre: 'Filtro aceite', codigo: 'FO-12', cantidad: 2),
      ]);
      expect(r.length, 1);
      expect(r.first.cantidad, 5);
      expect(r.first.precio, 5);
    });

    test('sin código, une por nombre normalizado', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Harina PAN 1kg', cantidad: 10),
        FilaLibreta(nombre: '  harina   pan 1KG ', cantidad: 5),
      ]);
      expect(r.length, 1);
      expect(r.first.cantidad, 15);
    });

    test('ropa: mismo nombre con distinta talla son DOS variantes', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Franela cuello V', talla: 'M', cantidad: 3),
        FilaLibreta(nombre: 'Franela cuello V', talla: 'L', cantidad: 4),
      ]);
      // Unirlas perdería el stock por talla, que es justo lo que una tienda de
      // ropa necesita saber.
      expect(r.length, 2);
      expect(r[0].cantidad, 3);
      expect(r[1].cantidad, 4);
    });

    test('el color también separa', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Blusa', talla: 'M', color: 'Negro', cantidad: 2),
        FilaLibreta(nombre: 'Blusa', talla: 'M', color: 'Blanco', cantidad: 1),
      ]);
      expect(r.length, 2);
    });

    test('misma talla sí se une', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Blusa', talla: 'M', cantidad: 2),
        FilaLibreta(nombre: 'Blusa', talla: 'M', cantidad: 1),
      ]);
      expect(r.length, 1);
      expect(r.first.cantidad, 3);
    });

    test('el precio que sí se leyó no se pierde al unir', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Arroz', cantidad: 4),
        FilaLibreta(nombre: 'Arroz', cantidad: 6, precio: 1.8),
      ]);
      expect(r.first.precio, 1.8);
      expect(r.first.cantidad, 10);
    });

    test('si ninguna trae existencia, no se inventa un cero', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'Café'),
        FilaLibreta(nombre: 'Café'),
      ]);
      expect(r.length, 1);
      expect(r.first.cantidad, isNull);
    });

    test('conserva el orden de aparición', () {
      final r = consolidarFilas(const [
        FilaLibreta(nombre: 'B'),
        FilaLibreta(nombre: 'A'),
        FilaLibreta(nombre: 'B'),
      ]);
      expect(r.map((f) => f.nombre), ['B', 'A']);
    });
  });

  group('FilaLibreta.dudosa', () {
    test('sin precio es dudosa', () {
      expect(const FilaLibreta(nombre: 'x', cantidad: 1).dudosa, true);
    });

    test('confianza baja es dudosa aunque haya cifras', () {
      const f = FilaLibreta(
        nombre: 'x',
        precio: 1,
        cantidad: 1,
        confianzaPrecio: Confianza.baja,
      );
      expect(f.dudosa, true);
    });

    test('todo leído y con confianza no es dudosa', () {
      const f = FilaLibreta(
        nombre: 'x',
        precio: 1,
        cantidad: 1,
        confianzaPrecio: Confianza.alta,
        confianzaCantidad: Confianza.alta,
      );
      expect(f.dudosa, false);
    });
  });
}
