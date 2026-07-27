import 'package:cuentaclara/core/utils/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormatter.convertirABs', () {
    const tasa = 36.5;

    test('sin redondeo conserva los decimales', () {
      expect(MoneyFormatter.convertirABs(2, tasa), 73.0);
      expect(MoneyFormatter.convertirABs(1.5, tasa), 54.75);
    });

    test('redondea al bolívar más cercano', () {
      expect(
        MoneyFormatter.convertirABs(
          1.5,
          tasa,
          redondeo: RedondeoBs.bolivarCercano,
        ),
        55.0,
      );
    });

    test('redondea al múltiplo de 5 más cercano', () {
      expect(
        MoneyFormatter.convertirABs(1.5, tasa, redondeo: RedondeoBs.multiplo5),
        55.0,
      );
      expect(
        MoneyFormatter.convertirABs(1, tasa, redondeo: RedondeoBs.multiplo5),
        35.0,
      );
    });
  });

  test('MoneyFormatter.usd formatea en dolares con formato es-VE', () {
    expect(MoneyFormatter.usd(12.5), r'$12,50');
    expect(MoneyFormatter.usd(1284590.50), r'$1.284.590,50');
  });
}
