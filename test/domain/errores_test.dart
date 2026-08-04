import 'dart:async';
import 'dart:io';

import 'package:cuentaclara/shared/utils/errores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mensajeDeError', () {
    test('un fallo de red se explica en el idioma del dueño', () {
      final m = mensajeDeError(
        const SocketException("Failed host lookup: 'workers.dev'"),
        accion: 'subir la foto',
      );
      expect(m, contains('Revisa tu internet'));
      // Lo que un bodeguero NO puede ver nunca.
      expect(m, isNot(contains('SocketException')));
      expect(m, isNot(contains('host lookup')));
    });

    test('el ClientException que se vio en dispositivo tampoco se filtra', () {
      final m = mensajeDeError(
        Exception(
          "ClientException with SocketException: Failed host lookup: "
          "'cuenta-clara-tasa.mitzumitzukyhs.workers.dev'",
        ),
        accion: 'leer la foto',
      );
      expect(m, isNot(contains('ClientException')));
      expect(m, contains('internet'));
    });

    test('un timeout se trata como problema de conexión', () {
      final m = mensajeDeError(TimeoutException('x'), accion: 'guardar');
      expect(m, contains('Revisa tu internet'));
    });

    test('cualquier excepción rara cae en una frase genérica y limpia', () {
      final m = mensajeDeError(StateError('Bad state: no element'),
          accion: 'guardar el gasto');
      expect(m, 'No pudimos guardar el gasto. Intenta de nuevo.');
      expect(m, isNot(contains('Bad state')));
    });

    test('nunca devuelve el toString de la excepción', () {
      for (final e in <Object>[
        ArgumentError('detalle interno'),
        FormatException('otro detalle'),
        'un string suelto',
      ]) {
        final m = mensajeDeError(e, accion: 'guardar');
        expect(m, isNot(contains('detalle')));
        expect(m.endsWith('.'), true);
      }
    });
  });

  group('conReintentos', () {
    test('devuelve al primer intento si no falla', () async {
      var veces = 0;
      final r = await conReintentos(() async {
        veces++;
        return 'listo';
      });
      expect(r, 'listo');
      expect(veces, 1);
    });

    test('reintenta un fallo de red y termina bien', () async {
      var veces = 0;
      final r = await conReintentos(
        () async {
          veces++;
          if (veces < 3) throw const SocketException('cayó');
          return 'listo';
        },
        esperaInicial: const Duration(milliseconds: 1),
      );
      expect(r, 'listo');
      expect(veces, 3);
    });

    test('se rinde tras los intentos y propaga el error', () async {
      var veces = 0;
      await expectLater(
        conReintentos(
          () async {
            veces++;
            throw const SocketException('sigue caída');
          },
          esperaInicial: const Duration(milliseconds: 1),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(veces, 3);
    });

    test('lo que no mejora esperando no se reintenta', () async {
      var veces = 0;
      await expectLater(
        conReintentos(
          () async {
            veces++;
            throw ArgumentError('archivo inválido');
          },
          esperaInicial: const Duration(milliseconds: 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
      // Un argumento inválido falla igual las tres veces: gastar dos esperas
      // más solo alarga el fallo.
      expect(veces, 1);
    });
  });
}
