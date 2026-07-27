import 'package:cuentaclara/core/utils/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormatter.usd', () {
    test('formatea valores pequeños', () {
      expect(MoneyFormatter.usd(12.5), r'$12,50');
    });

    test('formatea valores grandes con separadores', () {
      expect(MoneyFormatter.usd(1284590.50), r'$1.284.590,50');
    });

    test('formatea cero', () {
      expect(MoneyFormatter.usd(0), r'$0,00');
    });

    test('formatea enteros con decimales .00', () {
      expect(MoneyFormatter.usd(5), r'$5,00');
    });
  });

  group('MoneyFormatter.convertirABs', () {
    const tasa = 36.5;

    test('sin redondeo conserva los decimales', () {
      expect(MoneyFormatter.convertirABs(2, tasa), 73.0);
      expect(MoneyFormatter.convertirABs(1.5, tasa), 54.75);
      expect(MoneyFormatter.convertirABs(0.33, tasa), closeTo(12.045, 0.001));
    });

    test('redondea al bolívar más cercano', () {
      expect(
        MoneyFormatter.convertirABs(1.5, tasa, redondeo: RedondeoBs.bolivarCercano),
        55.0,
      );
      expect(
        MoneyFormatter.convertirABs(1.0, tasa, redondeo: RedondeoBs.bolivarCercano),
        37.0, // 36.5 → 37
      );
      expect(
        MoneyFormatter.convertirABs(0.5, tasa, redondeo: RedondeoBs.bolivarCercano),
        18.0, // 18.25 → 18
      );
    });

    test('redondea al múltiplo de 5 más cercano', () {
      expect(
        MoneyFormatter.convertirABs(1.5, tasa, redondeo: RedondeoBs.multiplo5),
        55.0, // 54.75 → 55
      );
      expect(
        MoneyFormatter.convertirABs(1, tasa, redondeo: RedondeoBs.multiplo5),
        35.0, // 36.5 → 35
      );
      expect(
        MoneyFormatter.convertirABs(3, tasa, redondeo: RedondeoBs.multiplo5),
        110.0, // 109.5 → 110
      );
    });

    test('con tasa cero da cero', () {
      expect(MoneyFormatter.convertirABs(100, 0), 0);
    });

    test('con tasa alta', () {
      final resultado = MoneyFormatter.convertirABs(1, 1000);
      expect(resultado, 1000);
    });
  });

  group('MoneyFormatter.bs', () {
    test('formatea con decimales', () {
      expect(MoneyFormatter.bs(1250.5), 'Bs 1.250,50');
    });

    test('formatea sin decimales con redondeo', () {
      expect(
        MoneyFormatter.bs(1250.5, redondeo: RedondeoBs.bolivarCercano),
        'Bs 1.251',
      );
    });

    test('formatea cero', () {
      expect(MoneyFormatter.bs(0), 'Bs 0,00');
    });
  });

  group('MoneyFormatter.usdComoBs', () {
    test('convierte y formatea USD a Bs', () {
      final resultado = MoneyFormatter.usdComoBs(2, 36.5);
      expect(resultado, 'Bs 73,00');
    });

    test('con redondeo', () {
      final resultado = MoneyFormatter.usdComoBs(
        1.5, 36.5,
        redondeo: RedondeoBs.multiplo5,
      );
      expect(resultado, 'Bs 55');
    });
  });
}
