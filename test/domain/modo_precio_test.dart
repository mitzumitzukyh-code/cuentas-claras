import 'package:cuentaclara/features/negocio/domain/modo_precio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModoPrecio.fromId', () {
    test('reconoce los ids canónicos', () {
      expect(ModoPrecio.fromId('USD'), ModoPrecio.usd);
      expect(ModoPrecio.fromId('VES'), ModoPrecio.ves);
      expect(ModoPrecio.fromId('AMBAS'), ModoPrecio.ambas);
    });

    test('tolera el "Bs" que escribía el onboarding viejo', () {
      expect(ModoPrecio.fromId('Bs'), ModoPrecio.ves);
      expect(ModoPrecio.fromId('BS'), ModoPrecio.ves);
    });

    test('un valor desconocido o nulo cae en dólares', () {
      // Es el aspecto que la app tuvo siempre: ningún negocio existente
      // cambia de cara al aparecer este ajuste.
      expect(ModoPrecio.fromId(null), ModoPrecio.usd);
      expect(ModoPrecio.fromId(''), ModoPrecio.usd);
      expect(ModoPrecio.fromId('EUR'), ModoPrecio.usd);
    });

    test('ida y vuelta por el id', () {
      for (final modo in ModoPrecio.values) {
        expect(ModoPrecio.fromId(modo.id), modo);
      }
    });
  });

  group('ModoPrecio.montos', () {
    test('usd deja los dólares arriba y los bolívares de referencia', () {
      final (principal, secundario) = ModoPrecio.usd.montos(10, 50);
      expect(principal, r'$10,00');
      expect(secundario, 'Bs 500,00');
    });

    test('ves invierte el orden: manda el bolívar', () {
      final (principal, secundario) = ModoPrecio.ves.montos(10, 50);
      expect(principal, 'Bs 500,00');
      expect(secundario, r'$10,00');
    });

    test('ambas junta los dos arriba y no deja segundo monto', () {
      // La pantalla los pinta del mismo tamaño sin tener que saber del modo:
      // por eso el segundo viene en null y no repetido.
      final (principal, secundario) = ModoPrecio.ambas.montos(10, 50);
      expect(principal, r'$10,00 · Bs 500,00');
      expect(secundario, isNull);
    });

    test('sin tasa solo hay dólares, en los tres modos', () {
      for (final modo in ModoPrecio.values) {
        final (principal, secundario) = modo.montos(10, null);
        expect(principal, r'$10,00', reason: 'modo $modo');
        expect(secundario, isNull, reason: 'modo $modo');
      }
    });

    test('formatea en es-VE: punto para miles, coma para decimales', () {
      final (principal, secundario) = ModoPrecio.ves.montos(1234.5, 40);
      expect(principal, 'Bs 49.380,00');
      expect(secundario, r'$1.234,50');
    });

    test('un monto negativo conserva el signo en las dos monedas', () {
      final (principal, secundario) = ModoPrecio.ves.montos(-3, 50);
      expect(principal, 'Bs -150,00');
      expect(secundario, r'$-3,00');
    });
  });

  group('ModoPrecio banderas', () {
    test('principalEnBs solo con ves', () {
      expect(ModoPrecio.usd.principalEnBs, isFalse);
      expect(ModoPrecio.ves.principalEnBs, isTrue);
      expect(ModoPrecio.ambas.principalEnBs, isFalse);
    });

    test('sinJerarquia solo con ambas', () {
      expect(ModoPrecio.usd.sinJerarquia, isFalse);
      expect(ModoPrecio.ves.sinJerarquia, isFalse);
      expect(ModoPrecio.ambas.sinJerarquia, isTrue);
    });
  });
}
