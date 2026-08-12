import 'package:cuentaclara/core/utils/confianza.dart';
import 'package:cuentaclara/features/fiados/domain/fiado_leido.dart';
import 'package:flutter_test/flutter_test.dart';

FiadoLeido _fila(
  String nombre, {
  double? monto,
  int id = 0,
  Confianza confianzaNombre = Confianza.alta,
  Confianza confianzaMonto = Confianza.alta,
}) =>
    FiadoLeido(
      idLocal: id,
      nombre: nombre,
      montoEscrito: monto,
      confianzaNombre: confianzaNombre,
      confianzaMonto: confianzaMonto,
    );

void main() {
  group('montoUSD', () {
    test('en dólares se guarda tal cual, sin necesitar tasa', () {
      expect(
        _fila('Ana', monto: 20).montoUSD(moneda: MonedaCuaderno.usd),
        20,
      );
    });

    test('en bolívares se divide por la tasa', () {
      final usd = _fila('Ana', monto: 7600)
          .montoUSD(moneda: MonedaCuaderno.bs, tasa: 76);
      expect(usd, closeTo(100, 0.001));
    });

    // El caso que multiplica una deuda por setecientos: sin tasa, un cuaderno
    // en bolívares NO puede colar el número en bruto como si fueran dólares.
    test('en bolívares sin tasa devuelve null, no el número crudo', () {
      final fila = _fila('Ana', monto: 15000);
      expect(fila.montoUSD(moneda: MonedaCuaderno.bs), isNull);
      expect(fila.montoUSD(moneda: MonedaCuaderno.bs, tasa: 0), isNull);
    });

    test('sin monto leído devuelve null en cualquier moneda', () {
      expect(_fila('Ana').montoUSD(moneda: MonedaCuaderno.usd), isNull);
      expect(_fila('Ana').montoUSD(moneda: MonedaCuaderno.bs, tasa: 76), isNull);
    });
  });

  group('fiadoDesdeJson', () {
    test('interpreta la cifra venezolana: 1.500 es mil quinientos', () {
      final f = fiadoDesdeJson({'nombre': ' Jose ', 'monto': '1.500'},
          idLocal: 3);
      expect(f.nombre, 'Jose');
      expect(f.montoEscrito, 1500);
      expect(f.idLocal, 3);
    });

    test('monto ilegible queda en null, nunca en 0', () {
      final f = fiadoDesdeJson({'nombre': 'Ana', 'monto': ''}, idLocal: 0);
      expect(f.montoEscrito, isNull);
      expect(f.dudoso, isTrue);
    });

    test('fecha vacía o a medias no se inventa', () {
      expect(
        fiadoDesdeJson({'nombre': 'Ana', 'fecha': ''}, idLocal: 0).fecha,
        isNull,
      );
      expect(
        fiadoDesdeJson({'nombre': 'Ana', 'fecha': '12/3'}, idLocal: 0).fecha,
        isNull,
      );
    });
  });

  group('consolidarFiados', () {
    test('suma los renglones de la misma persona', () {
      final r = consolidarFiados([
        _fila('Ana', monto: 10, id: 0),
        _fila('  ana  ', monto: 5, id: 1),
      ]);
      expect(r, hasLength(1));
      expect(r.single.montoEscrito, 15);
      expect(r.single.nombre, 'Ana');
    });

    // Sumar solo lo legible daría una deuda MENOR que la real: plata perdida.
    test('si a un renglón no se le leyó el monto, el total queda ilegible', () {
      final r = consolidarFiados([
        _fila('Ana', monto: 10, id: 0),
        _fila('Ana', id: 1),
      ]);
      expect(r.single.montoEscrito, isNull);
    });

    test('conserva la confianza peor de las dos', () {
      final r = consolidarFiados([
        _fila('Ana', monto: 10, id: 0),
        _fila('Ana', monto: 5, id: 1, confianzaMonto: Confianza.baja),
      ]);
      expect(r.single.confianzaMonto, Confianza.baja);
    });

    // Fundir a dos personas pasa desapercibido; separar a una se arregla en
    // dos toques. El empate se rompe hacia lo que se nota.
    test('Jose y José quedan separados', () {
      final r = consolidarFiados([
        _fila('Jose', monto: 10, id: 0),
        _fila('José', monto: 5, id: 1),
      ]);
      expect(r, hasLength(2));
    });

    test('descarta los renglones sin nombre', () {
      final r = consolidarFiados([_fila('   ', monto: 10)]);
      expect(r, isEmpty);
    });

    test('respeta el orden de aparición', () {
      final r = consolidarFiados([
        _fila('Beto', monto: 1, id: 0),
        _fila('Ana', monto: 2, id: 1),
        _fila('Beto', monto: 3, id: 2),
      ]);
      expect(r.map((f) => f.nombre), ['Beto', 'Ana']);
    });
  });

  group('copyWith', () {
    test('vaciar la casilla borra el monto en vez de dejar el de la IA', () {
      final f = _fila('Ana', monto: 99).copyWith(sinMonto: true);
      expect(f.montoEscrito, isNull);
    });

    test('editar el nombre no toca el monto y sube su confianza', () {
      final f = _fila('An', monto: 10, confianzaNombre: Confianza.baja)
          .copyWith(nombre: 'Ana');
      expect(f.nombre, 'Ana');
      expect(f.montoEscrito, 10);
      expect(f.confianzaNombre, Confianza.alta);
    });

    test('conserva la identidad del renglón', () {
      expect(_fila('Ana', id: 7).copyWith(nombre: 'Ani').idLocal, 7);
    });
  });
}
