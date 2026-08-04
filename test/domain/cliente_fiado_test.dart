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

  group('ClienteFiado · saldada y a favor', () {
    ClienteFiado con(double saldo) => ClienteFiado(
          id: 'c1',
          nombre: 'Jose',
          saldoUSD: saldo,
          actualizadoEn: _fecha,
        );

    test('con deuda no está saldada', () {
      expect(con(20).saldada, false);
      expect(con(20).aFavor, false);
      expect(con(20).saldoAFavorUSD, 0);
    });

    test('en cero está saldada y no tiene saldo a favor', () {
      expect(con(0).saldada, true);
      expect(con(0).aFavor, false);
      expect(con(0).saldoAFavorUSD, 0);
    });

    test('un residuo de coma flotante cuenta como saldada', () {
      // 25 − 5 − 20 no siempre da 0 exacto en double.
      final residuo = 25.0 - 5.0 - 20.0 + 0.0000001;
      expect(con(residuo).saldada, true);
    });

    test('abonó de más: a favor, y el monto se muestra en positivo', () {
      final c = con(-3);
      expect(c.saldada, true);
      expect(c.aFavor, true);
      expect(c.saldoAFavorUSD, 3);
    });
  });

  group('ClienteFiado · quitar sin destruir', () {
    test('por defecto no está eliminado', () {
      final c = ClienteFiado(
        id: 'c1',
        nombre: 'Jose',
        saldoUSD: 0,
        actualizadoEn: _fecha,
      );
      expect(c.eliminado, false);
      expect(c.eliminadoEn, isNull);
      expect(c.toMap()['eliminado'], false);
    });

    test('un cliente quitado conserva su saldo y su nombre', () {
      final c = ClienteFiado(
        id: 'c2',
        nombre: 'Jose',
        saldoUSD: 5.5,
        actualizadoEn: _fecha,
        eliminado: true,
        eliminadoEn: DateTime(2026, 8, 4),
      );
      final map = c.toMap();
      // El borrado es lógico: sus movimientos son un libro mayor que las
      // reglas de Firestore prohíben borrar.
      expect(map['eliminado'], true);
      expect(map['eliminadoEn'], isNotNull);
      expect(map['saldoUSD'], 5.5);
      expect(map['nombre'], 'Jose');
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
