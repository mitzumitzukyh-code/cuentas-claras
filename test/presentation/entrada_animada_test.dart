import 'package:cuentaclara/shared/presentation/entrada_animada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envuelve el widget bajo prueba, con la opción de pedir "reducir
/// movimiento" como lo hace el sistema operativo.
Widget _app(Widget hijo, {bool sinAnimaciones = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: sinAnimaciones),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: hijo,
    ),
  );
}

double _opacidad(WidgetTester tester) {
  return tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;
}

Offset _desplazamiento(WidgetTester tester) {
  final t = tester.widget<Transform>(find.byType(Transform)).transform;
  return Offset(t.getTranslation().x, t.getTranslation().y);
}

void main() {
  group('EntradaAnimada', () {
    testWidgets('empieza invisible y empujado, y termina en su sitio',
        (tester) async {
      await tester.pumpWidget(_app(const EntradaAnimada(child: Text('hola'))));

      // Primer fotograma: el hijo ya existe en el árbol —el texto se puede
      // encontrar y leer un lector de pantalla— pero todavía no se ve.
      expect(find.text('hola'), findsOneWidget);
      expect(_opacidad(tester), 0);
      expect(_desplazamiento(tester).dy, 14);

      await tester.pumpAndSettle();
      expect(_opacidad(tester), 1);
      expect(_desplazamiento(tester).dy, 0);
    });

    testWidgets('con "reducir movimiento" aparece de una vez', (tester) async {
      await tester.pumpWidget(
        _app(const EntradaAnimada(child: Text('hola')), sinAnimaciones: true),
      );
      // El post-frame callback es el que lee la preferencia.
      await tester.pump();

      expect(_opacidad(tester), 1);
      expect(_desplazamiento(tester).dy, 0);

      // Y no queda ninguna animación corriendo que atender.
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('el retardo escalona la entrada', (tester) async {
      await tester.pumpWidget(
        _app(
          const EntradaAnimada(
            retardo: Duration(milliseconds: 200),
            child: Text('hola'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacidad(tester), 0, reason: 'todavía no le toca');

      // En este fotograma vence el retardo y el controller ARRANCA, así que
      // su valor sigue siendo 0: lo que mide una animación es el tiempo
      // transcurrido desde que empezó. El avance se ve en el siguiente.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacidad(tester), greaterThan(0));

      await tester.pumpAndSettle();
      expect(_opacidad(tester), 1);
    });

    // Un `CurvedAnimation` por `build` deja oyentes enganchados al controller
    // que nadie desengancha. Se crea una sola vez, así que rehacer el árbol no
    // multiplica nada.
    testWidgets('reconstruir no crea una curva nueva cada vez', (tester) async {
      final clave = GlobalKey();
      await tester.pumpWidget(
        _app(EntradaAnimada(key: clave, child: const Text('hola'))),
      );
      final primera = tester
          .widget<AnimatedBuilder>(find.byType(AnimatedBuilder))
          .listenable;

      await tester.pump(const Duration(milliseconds: 100));
      tester.element(find.text('hola')).markNeedsBuild();
      await tester.pump();

      final segunda = tester
          .widget<AnimatedBuilder>(find.byType(AnimatedBuilder))
          .listenable;
      expect(identical(primera, segunda), isTrue);

      await tester.pumpAndSettle();
    });

    // Desmontar a media animación no debe reventar: el `Future.delayed` del
    // retardo sigue vivo aunque el widget ya no esté.
    testWidgets('se puede desmontar a mitad de la entrada', (tester) async {
      await tester.pumpWidget(
        _app(
          const EntradaAnimada(
            retardo: Duration(milliseconds: 200),
            child: Text('hola'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    });
  });
}
