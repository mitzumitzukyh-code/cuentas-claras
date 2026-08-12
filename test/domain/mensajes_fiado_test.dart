import 'package:cuentaclara/features/fiados/domain/cliente_fiado.dart';
import 'package:cuentaclara/features/fiados/domain/mensajes_fiado.dart';
import 'package:flutter_test/flutter_test.dart';

MovimientoFiado _mov(
  int dia, {
  required TipoMovimientoFiado tipo,
  required double monto,
  String concepto = '',
}) =>
    MovimientoFiado(
      id: '$dia',
      tipo: tipo,
      montoUSD: monto,
      concepto: concepto,
      fecha: DateTime(2026, 8, dia),
      registradoPor: 'u1',
    );

void main() {
  group('la voz', () {
    // Los dos textos vivían en pantallas distintas y el mismo cliente podía
    // recibir «Le recordamos con cariño su saldo» o «te escribo, ¿puedes
    // pasar?» según por dónde tocara el dueño.
    test('todos tutean, ninguno trata de usted', () {
      final textos = [
        borradorRecordatorio(nombre: 'Ana', negocio: 'la bodega', saldoUSD: 12),
        borradorAbono(
          nombre: 'Ana',
          negocio: 'la bodega',
          abonoUSD: 5,
          saldoRestanteUSD: 7,
        ),
        borradorCuentaSaldada(
          nombre: 'Ana',
          negocio: 'la bodega',
          fechaLarga: '12 de agosto de 2026',
        ),
      ];
      for (final t in textos) {
        expect(t, isNot(contains(' su ')), reason: t);
        expect(t, isNot(contains('Le ')), reason: t);
        expect(t, contains('Hola Ana'), reason: t);
      }
    });

    test('saluda por el primer nombre, no por el completo', () {
      final t = borradorRecordatorio(
        nombre: 'María Alejandra Gonzalez Perez',
        negocio: 'la bodega',
        saldoUSD: 12,
      );
      expect(t, startsWith('Hola María 👋'));
    });

    test('un nombre con espacios de sobra no rompe el saludo', () {
      final t = borradorRecordatorio(
        nombre: '  Ana   Luisa  ',
        negocio: 'la bodega',
        saldoUSD: 1,
      );
      expect(t, startsWith('Hola Ana 👋'));
    });
  });

  group('bolívares', () {
    test('se añaden cuando hay tasa del día', () {
      final t = borradorRecordatorio(
        nombre: 'Ana',
        negocio: 'la bodega',
        saldoUSD: 12,
        tasa: 764.35,
      );
      expect(t, contains(r'$12,00'));
      expect(t, contains('Bs'));
    });

    // Sin tasa se manda solo el dólar. Inventar la conversión en un mensaje
    // que sale hacia un cliente es peor que no darla.
    test('sin tasa el mensaje sale solo en dólares', () {
      final t = borradorRecordatorio(
        nombre: 'Ana',
        negocio: 'la bodega',
        saldoUSD: 12,
      );
      expect(t, contains(r'$12,00'));
      expect(t, isNot(contains('Bs')));
    });
  });

  group('comprobante de abono', () {
    test('dice lo abonado y lo que queda', () {
      final t = borradorAbono(
        nombre: 'Ana',
        negocio: 'la bodega',
        abonoUSD: 5,
        saldoRestanteUSD: 7,
      );
      expect(t, contains(r'abono de $5,00'));
      expect(t, contains(r'Te quedan $7,00'));
    });

    test('si el abono salda la cuenta, no dice que quedan cero', () {
      final t = borradorAbono(
        nombre: 'Ana',
        negocio: 'la bodega',
        abonoUSD: 12,
        saldoRestanteUSD: 0,
      );
      expect(t, contains('quedas al día'));
      expect(t, isNot(contains('Te quedan')));
    });

    // Un céntimo de resto sale de sumar y restar doubles, no de una deuda.
    test('un resto de céntimos cuenta como saldado', () {
      final t = borradorAbono(
        nombre: 'Ana',
        negocio: 'la bodega',
        abonoUSD: 12,
        saldoRestanteUSD: 0.001,
      );
      expect(t, contains('quedas al día'));
    });
  });

  group('cuenta saldada', () {
    test('menciona el saldo a favor si lo hay', () {
      final t = borradorCuentaSaldada(
        nombre: 'Ana',
        negocio: 'la bodega',
        fechaLarga: '12 de agosto de 2026',
        aFavorUSD: 3,
      );
      expect(t, contains('CERO'));
      expect(t, contains(r'$3,00 a favor'));
    });

    test('sin saldo a favor no lo inventa', () {
      final t = borradorCuentaSaldada(
        nombre: 'Ana',
        negocio: 'la bodega',
        fechaLarga: '12 de agosto de 2026',
      );
      expect(t, isNot(contains('a favor')));
    });
  });

  group('estado de cuenta', () {
    final movimientos = [
      _mov(9, tipo: TipoMovimientoFiado.abono, monto: 2.5),
      _mov(2, tipo: TipoMovimientoFiado.fiado, monto: 6.5, concepto: '2 harinas'),
      _mov(7, tipo: TipoMovimientoFiado.fiado, monto: 8, concepto: 'cerveza'),
    ];

    // En pantalla se leen del más nuevo al más viejo; una cuenta se explica al
    // revés, en el orden en que pasó.
    test('va del más viejo al más nuevo', () {
      final t = borradorEstadoCuenta(
        nombre: 'Ana',
        negocio: 'la bodega',
        movimientos: movimientos,
        saldoUSD: 12,
      );
      expect(t.indexOf('2 ago'), lessThan(t.indexOf('7 ago')));
      expect(t.indexOf('7 ago'), lessThan(t.indexOf('9 ago')));
    });

    test('los abonos restan y los fiados suman', () {
      final t = borradorEstadoCuenta(
        nombre: 'Ana',
        negocio: 'la bodega',
        movimientos: movimientos,
        saldoUSD: 12,
      );
      expect(t, contains(r'2 ago — 2 harinas — +$6,50'));
      expect(t, contains(r'9 ago — abono — −$2,50'));
    });

    test('un movimiento sin concepto se nombra por su tipo', () {
      final t = borradorEstadoCuenta(
        nombre: 'Ana',
        negocio: 'la bodega',
        movimientos: [_mov(3, tipo: TipoMovimientoFiado.fiado, monto: 1)],
        saldoUSD: 1,
      );
      expect(t, contains('3 ago — fiado — +\$1,00'));
    });

    // Con un cliente de años, doscientas líneas por WhatsApp no explican nada.
    test('recorta a los últimos movimientos y lo dice', () {
      final muchos = [
        for (var d = 1; d <= 20; d++)
          _mov(d, tipo: TipoMovimientoFiado.fiado, monto: 1),
      ];
      final t = borradorEstadoCuenta(
        nombre: 'Ana',
        negocio: 'la bodega',
        movimientos: muchos,
        saldoUSD: 20,
        maximoLineas: 5,
      );
      expect(t, contains('los últimos 5 movimientos'));
      expect(t, isNot(contains('15 ago')));
      expect(t, contains('20 ago'));
    });

    test('cierra según el saldo: debe, a favor o al día', () {
      String cierre(double saldo) => borradorEstadoCuenta(
            nombre: 'Ana',
            negocio: 'la bodega',
            movimientos: movimientos,
            saldoUSD: saldo,
          );
      expect(cierre(12), contains('Saldo pendiente'));
      expect(cierre(-3), contains('a favor'));
      expect(cierre(0), contains('Estás al día'));
    });
  });
}
