import 'package:cuentaclara/core/utils/telefono_ve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarTelefonoVE', () {
    test('las cuatro formas en que el dueño anota el mismo número', () {
      const esperado = '584145100255';
      expect(normalizarTelefonoVE('04145100255'), esperado);
      expect(normalizarTelefonoVE('0414-510-0255'), esperado);
      expect(normalizarTelefonoVE('+58 414 5100255'), esperado);
      expect(normalizarTelefonoVE('414 5100255'), esperado);
    });

    test('aguanta paréntesis, puntos y espacios de más', () {
      expect(normalizarTelefonoVE('(0414) 510 02 55'), '584145100255');
      expect(normalizarTelefonoVE(' 0414.510.02.55 '), '584145100255');
      expect(normalizarTelefonoVE('+58-414-510-02-55'), '584145100255');
    });

    test('el prefijo de salida internacional también vale', () {
      expect(normalizarTelefonoVE('005804145100255'), '584145100255');
      expect(normalizarTelefonoVE('00584145100255'), '584145100255');
    });

    test('58 con el cero nacional pegado: sobra el cero', () {
      expect(normalizarTelefonoVE('5804145100255'), '584145100255');
    });

    test('todas las operadoras móviles', () {
      for (final op in operadorasMovilesVE) {
        expect(normalizarTelefonoVE('0${op}5100255'), '58${op}5100255');
      }
    });

    test('un fijo de Caracas también se normaliza', () {
      expect(normalizarTelefonoVE('0212-5551234'), '582125551234');
    });

    test('lo que no es un número devuelve null, no algo a medias', () {
      expect(normalizarTelefonoVE(null), isNull);
      expect(normalizarTelefonoVE(''), isNull);
      expect(normalizarTelefonoVE('   '), isNull);
      expect(normalizarTelefonoVE('no tiene'), isNull);
      expect(normalizarTelefonoVE('---'), isNull);
    });

    test('largos que no cuadran devuelven null', () {
      expect(normalizarTelefonoVE('0414510025'), isNull); // uno de menos
      expect(normalizarTelefonoVE('041451002556'), isNull); // uno de más
      expect(normalizarTelefonoVE('123'), isNull);
    });

    test('un número que no puede ser venezolano devuelve null', () {
      // Empieza en 1: ni móvil ni fijo de Venezuela. Sin este filtro, un
      // número de otro país pegado sin prefijo abriría el chat de un extraño.
      expect(normalizarTelefonoVE('1145100255'), isNull);
      expect(normalizarTelefonoVE('9145100255'), isNull);
    });

    test('normalizar dos veces da lo mismo que una', () {
      final una = normalizarTelefonoVE('0414-510-0255');
      expect(normalizarTelefonoVE(una), una);
    });
  });

  group('esMovilVE', () {
    test('distingue móvil de fijo', () {
      expect(esMovilVE(normalizarTelefonoVE('04145100255')), true);
      expect(esMovilVE(normalizarTelefonoVE('04125100255')), true);
      expect(esMovilVE(normalizarTelefonoVE('0212-5551234')), false);
    });

    test('null no es móvil', () {
      expect(esMovilVE(null), false);
      expect(esMovilVE('58414'), false);
    });
  });
}
