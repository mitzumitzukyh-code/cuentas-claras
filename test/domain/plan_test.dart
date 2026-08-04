import 'package:cuentaclara/features/planes/domain/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('premiumForzado', () {
    test('está apagado salvo que se compile con la bandera', () {
      // Si esto falla en CI o en un build normal, alguien dejó
      // `--dart-define=PREMIUM_FORZADO=true` puesto donde no debía y todo el
      // mundo tendría Premium gratis.
      expect(premiumForzado, isFalse);
    });
  });

  group('Plan.fromId', () {
    test('reconoce los dos planes', () {
      expect(Plan.fromId('gratis'), Plan.gratis);
      expect(Plan.fromId('premium'), Plan.premium);
    });

    test('lo desconocido, lo vacío y lo nulo caen en gratis', () {
      // Si no consta que alguien pagó, no pagó. Cualquier otra lectura sería
      // regalar Premium por un dato corrupto.
      expect(Plan.fromId(null), Plan.gratis);
      expect(Plan.fromId(''), Plan.gratis);
      expect(Plan.fromId('PREMIUM'), Plan.gratis);
      expect(Plan.fromId('plus'), Plan.gratis);
    });

    test('ida y vuelta por el id', () {
      for (final p in Plan.values) {
        expect(Plan.fromId(p.id), p);
      }
    });
  });

  group('topes del plan gratis', () {
    test('son los del brief', () {
      expect(Plan.gratis.maxNegocios, 1);
      expect(Plan.gratis.maxProductos, 50);
      expect(Plan.gratis.maxUsuarios, 1);
      expect(Plan.gratis.diasHistorial, 30);
    });

    test('premium no tiene ninguno', () {
      expect(Plan.premium.maxNegocios, isNull);
      expect(Plan.premium.maxProductos, isNull);
      expect(Plan.premium.maxUsuarios, isNull);
      expect(Plan.premium.diasHistorial, isNull);
    });
  });

  group('marca de agua', () {
    test('va en gratis y no en premium', () {
      expect(Plan.gratis.marcaDeAgua, isTrue);
      expect(Plan.premium.marcaDeAgua, isFalse);
    });

    test('esPremium solo para premium', () {
      expect(Plan.gratis.esPremium, isFalse);
      expect(Plan.premium.esPremium, isTrue);
    });
  });

  group('LimitePlan.cabeUnoMas', () {
    test('sin tope siempre cabe', () {
      final r = LimitePlan.cabeUnoMas(
        actuales: 9999,
        tope: null,
        mensaje: 'no debería verse',
      );
      expect(r.permitido, isTrue);
      expect(r.mensaje, isNull);
    });

    test('por debajo del tope cabe', () {
      expect(
        LimitePlan.cabeUnoMas(actuales: 49, tope: 50, mensaje: 'x').permitido,
        isTrue,
      );
    });

    test('justo en el tope ya no cabe', () {
      final r = LimitePlan.cabeUnoMas(
        actuales: 50,
        tope: 50,
        mensaje: 'Llegaste al tope',
      );
      expect(r.permitido, isFalse);
      expect(r.mensaje, 'Llegaste al tope');
    });

    test('por encima del tope tampoco, y no rompe', () {
      // El caso de quien ya tenía 60 productos antes de que existiera el
      // límite: no puede añadir más, pero nada explota ni se le esconde nada.
      final r = LimitePlan.cabeUnoMas(actuales: 60, tope: 50, mensaje: 'x');
      expect(r.permitido, isFalse);
    });
  });
}
