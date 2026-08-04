import 'package:cuentaclara/shared/utils/csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('celdaCsv', () {
    test('un texto normal va sin comillas', () {
      expect(celdaCsv('Harina PAN 1kg'), 'Harina PAN 1kg');
    });

    test('dobla las comillas de dentro y entrecomilla la celda', () {
      // El caso que rompía la exportación de inventario: en una ferretería,
      // las pulgadas se escriben con comillas.
      expect(celdaCsv('Tornillo 1/2"'), '"Tornillo 1/2"""');
    });

    test('entrecomilla si hay una coma', () {
      expect(celdaCsv('Aceite, girasol'), '"Aceite, girasol"');
    });

    test('entrecomilla si hay punto y coma o saltos de línea', () {
      expect(celdaCsv('uno;dos'), '"uno;dos"');
      expect(celdaCsv('uno\ndos'), '"uno\ndos"');
      expect(celdaCsv('uno\r\ndos'), '"uno\r\ndos"');
    });

    test('null es una celda vacía, no la palabra "null"', () {
      // Los productos sin precio escribían literalmente `null` en la celda.
      expect(celdaCsv(null), '');
    });

    test('los números salen tal cual', () {
      expect(celdaCsv(3.5), '3.5');
      expect(celdaCsv(22), '22');
    });
  });

  group('tablaCsv', () {
    test('encabezados y filas, una línea por fila', () {
      final csv = tablaCsv(
        ['Nombre', 'Precio USD', 'Stock'],
        [
          ['Harina PAN 1kg', 1.2, 35],
          ['Atún', 1.75, 44],
        ],
      );
      expect(csv, 'Nombre,Precio USD,Stock\nHarina PAN 1kg,1.2,35\nAtún,1.75,44\n');
    });

    test('una fila con comillas y comas no desplaza las columnas', () {
      final csv = tablaCsv(
        ['Nombre', 'Categoria', 'Precio USD', 'Stock'],
        [
          ['Tornillo 1/2"', 'Ferretería, tornillos', null, 100],
        ],
      );
      // Cuatro columnas siguen siendo cuatro: las comas de dentro están
      // protegidas por las comillas.
      final fila = csv.split('\n')[1];
      expect(fila, '"Tornillo 1/2""","Ferretería, tornillos",,100');
    });

    test('los encabezados también se escapan', () {
      final csv = tablaCsv(['Precio, USD'], []);
      expect(csv, '"Precio, USD"\n');
    });
  });
}
