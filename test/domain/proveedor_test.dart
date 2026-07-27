import 'package:cuentaclara/features/proveedores/domain/proveedor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Proveedor', () {
    test('constructor y getters', () {
      final p = Proveedor(
        id: 'prov1', nombre: 'Distribuidora XYZ',
        saldoUSD: 200.0, actualizadoEn: _fecha,
      );
      expect(p.id, 'prov1');
      expect(p.nombre, 'Distribuidora XYZ');
      expect(p.saldoUSD, 200.0);
    });

    group('iniciales', () {
      test('nombre completo da dos iniciales', () {
        final p = Proveedor(
          id: 'p1', nombre: 'Distribuidora XYZ',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(p.iniciales, 'DX');
      });

      test('nombre unico da una inicial', () {
        final p = Proveedor(
          id: 'p2', nombre: 'PepsiCo',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(p.iniciales, 'P');
      });

      test('nombre vacio da ?', () {
        final p = Proveedor(
          id: 'p3', nombre: '',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(p.iniciales, '?');
      });
    });

    test('toMap serializa', () {
      final p = Proveedor(
        id: 'prov1', nombre: 'Distribuidora XYZ',
        saldoUSD: 200.0, actualizadoEn: _fecha,
      );
      final map = p.toMap();
      expect(map['nombre'], 'Distribuidora XYZ');
      expect(map['saldoUSD'], 200.0);
    });
  });

  group('TipoMovimientoProveedor', () {
    test('fromId', () {
      expect(TipoMovimientoProveedor.fromId('compra'), TipoMovimientoProveedor.compra);
      expect(TipoMovimientoProveedor.fromId('pago'), TipoMovimientoProveedor.pago);
      expect(TipoMovimientoProveedor.fromId(null), TipoMovimientoProveedor.compra);
    });
  });

  group('MovimientoProveedor', () {
    test('toMap serializa', () {
      final m = MovimientoProveedor(
        id: 'm1', tipo: TipoMovimientoProveedor.compra,
        montoUSD: 150.0, concepto: 'Compra mayo',
        fecha: _fecha, registradoPor: 'usr1',
      );
      final map = m.toMap();
      expect(map['tipo'], 'compra');
      expect(map['montoUSD'], 150.0);
      expect(map['concepto'], 'Compra mayo');
    });

    test('vencimiento se serializa', () {
      final venc = DateTime(2026, 8, 26);
      final m = MovimientoProveedor(
        id: 'm2', tipo: TipoMovimientoProveedor.compra,
        montoUSD: 100.0, concepto: 'X',
        fecha: _fecha, registradoPor: 'usr1',
        vencimiento: venc,
      );
      expect(m.toMap()['vencimiento'], isNotNull);
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
