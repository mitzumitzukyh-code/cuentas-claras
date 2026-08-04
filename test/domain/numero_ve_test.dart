import 'package:cuentaclara/core/utils/numero_ve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarNumeroVE', () {
    test('el caso del enunciado', () {
      expect(normalizarNumeroVE('4.500,80'), 4500.80);
    });

    test('coma decimal sin miles', () {
      expect(normalizarNumeroVE('4500,80'), 4500.80);
      expect(normalizarNumeroVE('1,20'), 1.20);
      expect(normalizarNumeroVE('0,50'), 0.50);
    });

    test('punto con tres cifras detrás son miles', () {
      expect(normalizarNumeroVE('1.200'), 1200);
      expect(normalizarNumeroVE('12.500'), 12500);
      expect(normalizarNumeroVE('1.234.567'), 1234567);
    });

    test('punto con una o dos cifras detrás es decimal', () {
      expect(normalizarNumeroVE('1.20'), 1.20);
      expect(normalizarNumeroVE('3.5'), 3.5);
    });

    test('escrito a la gringa también se entiende', () {
      expect(normalizarNumeroVE('4,500.80'), 4500.80);
      expect(normalizarNumeroVE('1,234,567.89'), 1234567.89);
    });

    test('se ignoran símbolos de moneda y unidades', () {
      expect(normalizarNumeroVE(r'$4,50'), 4.50);
      expect(normalizarNumeroVE('Bs 4.500,80'), 4500.80);
      expect(normalizarNumeroVE('12 uds'), 12);
      expect(normalizarNumeroVE('  1.200  '), 1200);
    });

    test('un número ya numérico pasa tal cual', () {
      expect(normalizarNumeroVE(4500.8), 4500.8);
      expect(normalizarNumeroVE(12), 12);
    });

    test('lo ilegible devuelve null, nunca cero', () {
      // Un cero inventado en un precio es mercancía regalada.
      for (final basura in <Object?>[null, '', '   ', 'ilegible', '—', '-', ',']) {
        expect(normalizarNumeroVE(basura), isNull, reason: '$basura');
      }
    });

    test('negativos se conservan', () {
      expect(normalizarNumeroVE('-1.200'), -1200);
      expect(normalizarNumeroVE('-3,50'), -3.50);
    });
  });

  group('normalizarPositivoVE', () {
    test('sirve para precios y existencias', () {
      expect(normalizarPositivoVE('4.500,80'), 4500.80);
      expect(normalizarPositivoVE('12'), 12);
    });

    test('cero y negativos se descartan', () {
      // En una lectura automática, un 0 casi siempre es "no se pudo leer".
      expect(normalizarPositivoVE('0'), isNull);
      expect(normalizarPositivoVE('0,00'), isNull);
      expect(normalizarPositivoVE('-5'), isNull);
    });

    test('lo ilegible sigue siendo null', () {
      expect(normalizarPositivoVE('ilegible'), isNull);
      expect(normalizarPositivoVE(null), isNull);
    });
  });
}
