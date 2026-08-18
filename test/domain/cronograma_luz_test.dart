import 'package:cuentaclara/features/luz/domain/cronograma_luz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un cronograma de juguete con la misma forma que el del Worker: dos días
/// con corte, cuatro bloques, una franja cada uno.
Map<String, dynamic> _json() => {
      'estado': 'barinas',
      'version': '2026-08',
      'desde': '2026-08-03',
      'hasta': '2026-08-04',
      'franjas': [
        {'id': '03-08', 'desde': 3, 'hasta': 8},
        {'id': '08-13', 'desde': 8, 'hasta': 13},
        {'id': '13-18', 'desde': 13, 'hasta': 18},
        {'id': '18-23', 'desde': 18, 'hasta': 23},
      ],
      'sectores': {
        'A': ['Centro', 'Sur'],
        'B': ['Carolina'],
        'C': ['Estadio'],
        'D': ['Industrial'],
      },
      'dias': {
        '2026-08-03': {'A': '08-13', 'B': '13-18', 'C': '18-23', 'D': '03-08'},
        '2026-08-04': {'A': '03-08', 'B': '08-13', 'C': '13-18', 'D': '18-23'},
      },
    };

void main() {
  group('hora12', () {
    // Nadie en una bodega dice «de dieciocho a veintitrés».
    test('escribe la hora como la dice la gente', () {
      expect(hora12(3), '3:00 am');
      expect(hora12(8), '8:00 am');
      expect(hora12(13), '1:00 pm');
      expect(hora12(18), '6:00 pm');
      expect(hora12(23), '11:00 pm');
    });

    test('el mediodía y la medianoche no salen como 0', () {
      expect(hora12(0), '12:00 am');
      expect(hora12(12), '12:00 pm');
      expect(hora12(24), '12:00 am');
    });
  });

  group('FranjaCorte', () {
    test('se lee entera y sin hora militar', () {
      const f = FranjaCorte(desde: 18, hasta: 23);
      expect(f.comoTexto, '6:00 pm a 11:00 pm');
    });
  });

  group('CronogramaLuz', () {
    final c = CronogramaLuz.fromJson(_json());

    test('lee la tabla que manda el Worker', () {
      expect(c.estado, 'barinas');
      expect(c.version, '2026-08');
      expect(c.bloques, ['A', 'B', 'C', 'D']);
      expect(c.sectores['A'], contains('Centro'));
    });

    test('da la franja del bloque en la fecha', () {
      expect(
        c.franja(DateTime(2026, 8, 3), 'A'),
        const FranjaCorte(desde: 8, hasta: 13),
      );
      expect(
        c.franja(DateTime(2026, 8, 4), 'a'),
        const FranjaCorte(desde: 3, hasta: 8),
      );
    });

    // El caso que decidimos con el usuario: sin tabla, silencio.
    test('fuera del rango no inventa una franja', () {
      expect(c.cubre(DateTime(2026, 8, 5)), isFalse);
      expect(c.franja(DateTime(2026, 8, 5), 'A'), isNull);
      expect(c.franja(DateTime(2026, 8, 2), 'A'), isNull);
    });

    test('un bloque que no existe no revienta', () {
      expect(c.franja(DateTime(2026, 8, 3), 'Z'), isNull);
    });

    test('los próximos cortes se acaban cuando se acaba el cronograma', () {
      final proximos =
          c.proximosCortes('A', desdeFecha: DateTime(2026, 8, 3), dias: 7);
      expect(proximos, hasLength(2));
      expect(proximos.first.franja.desde, 8);
      expect(proximos.last.fecha, DateTime(2026, 8, 4));
    });

    test('empezar a media semana no arrastra los días ya pasados', () {
      final proximos =
          c.proximosCortes('A', desdeFecha: DateTime(2026, 8, 4), dias: 7);
      expect(proximos, hasLength(1));
      expect(proximos.single.fecha, DateTime(2026, 8, 4));
    });
  });

  group('los textos de los avisos', () {
    const franja = FranjaCorte(desde: 18, hasta: 23);

    test('el aviso previo lleva las dos horas', () {
      final a = avisoAntesDelCorte(franja);
      expect(a.titulo, contains('6:00 pm'));
      expect(a.cuerpo, contains('6:00 pm a 11:00 pm'));
    });

    // La app no puede saber si la luz volvió: prometerlo es mentir.
    test('el aviso de vuelta dice «debería», no «volvió»', () {
      final a = avisoAlVolver(franja);
      expect(a.titulo, contains('debería'));
      expect(a.cuerpo, contains('11:00 pm'));
    });

    test('ningún texto se le escapa en hora militar', () {
      for (final texto in [
        avisoAntesDelCorte(franja).titulo,
        avisoAntesDelCorte(franja).cuerpo,
        avisoAlVolver(franja).titulo,
        avisoAlVolver(franja).cuerpo,
        franja.comoTexto,
      ]) {
        expect(texto, isNot(matches(RegExp(r'\b(1[3-9]|2[0-4]):'))));
      }
    });
  });
}
