import 'package:cuentaclara/features/fiados/domain/cliente_fiado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClienteFiado', () {
    test('constructor y getters', () {
      final c = ClienteFiado(
        id: 'c1',
        nombre: 'Juan Pérez',
        saldoUSD: 50.0,
        actualizadoEn: _fecha,
      );
      expect(c.id, 'c1');
      expect(c.nombre, 'Juan Pérez');
      expect(c.saldoUSD, 50.0);
    });

    group('iniciales', () {
      test('nombre completo da dos iniciales', () {
        final c = ClienteFiado(
          id: 'c1', nombre: 'Juan Pérez',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(c.iniciales, 'JP');
      });

      test('nombre unico da una inicial', () {
        final c = ClienteFiado(
          id: 'c2', nombre: 'María',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(c.iniciales, 'M');
      });

      test('nombre vacio da ?', () {
        final c = ClienteFiado(
          id: 'c3', nombre: '',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(c.iniciales, '?');
      });

      test('nombre con espacios extra', () {
        final c = ClienteFiado(
          id: 'c4', nombre: '  ana  lopez  ',
          saldoUSD: 0, actualizadoEn: _fecha,
        );
        expect(c.iniciales, 'AL');
      });
    });

    test('toMap serializa', () {
      final c = ClienteFiado(
        id: 'c1', nombre: 'Juan Pérez',
        telefono: '04121234567',
        saldoUSD: 50.0,
        actualizadoEn: _fecha,
      );
      final map = c.toMap();
      expect(map['nombre'], 'Juan Pérez');
      expect(map['telefono'], '04121234567');
      expect(map['saldoUSD'], 50.0);
    });

    test('toMap sin telefono', () {
      final c = ClienteFiado(
        id: 'c2', nombre: 'Solo Nombre',
        saldoUSD: 0, actualizadoEn: _fecha,
      );
      expect(c.toMap()['telefono'], null);
    });
  });

  group('TipoMovimientoFiado', () {
    test('fromId', () {
      expect(TipoMovimientoFiado.fromId('fiado'), TipoMovimientoFiado.fiado);
      expect(TipoMovimientoFiado.fromId('abono'), TipoMovimientoFiado.abono);
      expect(TipoMovimientoFiado.fromId('inventado'), TipoMovimientoFiado.fiado);
      expect(TipoMovimientoFiado.fromId(null), TipoMovimientoFiado.fiado);
    });
  });

  group('MovimientoFiado', () {
    test('toMap serializa', () {
      final m = MovimientoFiado(
        id: 'm1', tipo: TipoMovimientoFiado.fiado,
        montoUSD: 30.0, concepto: 'Fió pollo',
        fecha: _fecha, registradoPor: 'usr1',
        negocioId: 'n1',
      );
      final map = m.toMap();
      expect(map['tipo'], 'fiado');
      expect(map['montoUSD'], 30.0);
      expect(map['concepto'], 'Fió pollo');
      expect(map['negocioId'], 'n1');
    });

    test('negocioId default vacio', () {
      final m = MovimientoFiado(
        id: 'm2', tipo: TipoMovimientoFiado.abono,
        montoUSD: 10.0, concepto: 'Abonó',
        fecha: _fecha, registradoPor: 'usr1',
      );
      expect(m.negocioId, '');
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
