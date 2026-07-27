import 'package:cuentaclara/features/cierre/domain/cierre_caja.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CierreCaja', () {
    final base = CierreCaja(
      id: '2026-07-26',
      ventasUSD: 500,
      gastosUSD: 100,
      fiadoOtorgadoUSD: 50,
      abonosUSD: 30,
      metodosEsperados: {'efectivo': 300, 'pagomovil': 200},
      efectivoEsperado: 300,
      efectivoContado: 310,
      cerradoPor: 'usr1',
      cerradaEn: _fecha,
    );

    test('descuadreUSD = efectivoContado - efectivoEsperado', () {
      expect(base.descuadreUSD, 10);
    });

    test('descuadreUSD negativo si falta efectivo', () {
      final cierre = CierreCaja(
        id: '2026-07-25',
        ventasUSD: 0,
        gastosUSD: 0,
        fiadoOtorgadoUSD: 0,
        abonosUSD: 0,
        metodosEsperados: {},
        efectivoEsperado: 300,
        efectivoContado: 280,
        cerradoPor: 'usr1',
        cerradaEn: _fecha,
      );
      expect(cierre.descuadreUSD, -20);
    });

    test('netoUSD = ventas - gastos - fiado + abonos', () {
      // 500 - 100 - 50 + 30 = 380
      expect(base.netoUSD, 380);
    });

    test('toMap serializa campos principales', () {
      final map = base.toMap();
      expect(map['ventasUSD'], 500);
      expect(map['gastosUSD'], 100);
      expect(map['fiadoOtorgadoUSD'], 50);
      expect(map['abonosUSD'], 30);
      expect(map['metodosEsperados'], {'efectivo': 300, 'pagomovil': 200});
      expect(map['efectivoEsperado'], 300);
      expect(map['efectivoContado'], 310);
      expect(map['cerradoPor'], 'usr1');
    });

    test('netoUSD negativo si gastos > ventas', () {
      final cierre = CierreCaja(
        id: '2026-07-24',
        ventasUSD: 100,
        gastosUSD: 200,
        fiadoOtorgadoUSD: 0,
        abonosUSD: 0,
        metodosEsperados: {},
        efectivoEsperado: 100,
        efectivoContado: 100,
        cerradoPor: 'usr1',
        cerradaEn: _fecha,
      );
      expect(cierre.netoUSD, -100);
    });
  });

  group('CierreCaja.idDe', () {
    test('formatea fecha como yyyy-MM-dd', () {
      expect(CierreCaja.idDe(DateTime(2026, 7, 26)), '2026-07-26');
      expect(CierreCaja.idDe(DateTime(2026, 1, 5)), '2026-01-05');
      expect(CierreCaja.idDe(DateTime(2025, 12, 31)), '2025-12-31');
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
