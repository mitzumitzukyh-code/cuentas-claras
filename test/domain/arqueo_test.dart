import 'package:cuentaclara/features/ventas/domain/venta.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suma por método de pago tal como la calcula el arqueo de caja.
///
/// Réplica de la lógica de `arqueo_caja_screen`: se aísla aquí para poder
/// fijar la regla que más plata puede costar — qué entra y qué no en el
/// efectivo esperado.
Map<String, double> esperadoPorMetodo(List<Venta> ventas) {
  final metodos = <String, double>{};
  for (final v in ventas.where((v) => !v.esFiada)) {
    metodos[v.metodoPago.id] = (metodos[v.metodoPago.id] ?? 0) + v.totalUSD;
  }
  return metodos;
}

Venta _venta({
  required double total,
  MetodoPago metodo = MetodoPago.efectivo,
  String? fiadoA,
}) =>
    Venta(
      id: 'v',
      items: const [],
      totalUSD: total,
      totalBs: 0,
      tasaBcvUsada: 1,
      vendidoPor: 'u',
      fecha: DateTime.now(),
      metodoPago: metodo,
      fiadoClienteId: fiadoA,
      fiadoClienteNombre: fiadoA == null ? null : 'Cliente',
    );

void main() {
  group('Efectivo esperado en el arqueo', () {
    test('suma las ventas en efectivo', () {
      final r = esperadoPorMetodo([
        _venta(total: 10),
        _venta(total: 5),
      ]);
      expect(r[MetodoPago.efectivo.id], 15);
    });

    test('separa cada método', () {
      final r = esperadoPorMetodo([
        _venta(total: 10),
        _venta(total: 7, metodo: MetodoPago.pagoMovil),
      ]);
      expect(r[MetodoPago.efectivo.id], 10);
      expect(r[MetodoPago.pagoMovil.id], 7);
    });

    test('una venta fiada NO entra en lo esperado', () {
      // Es el bug que descuadraba la caja: la plata fiada todavía no llegó,
      // así que el dueño contaba el efectivo y le faltaba justo eso.
      final r = esperadoPorMetodo([
        _venta(total: 10),
        _venta(total: 50, fiadoA: 'c1'),
      ]);
      expect(r[MetodoPago.efectivo.id], 10);
    });

    test('un día entero de fiado deja el efectivo esperado en cero', () {
      final r = esperadoPorMetodo([
        _venta(total: 20, fiadoA: 'c1'),
        _venta(total: 30, fiadoA: 'c2'),
      ]);
      expect(r[MetodoPago.efectivo.id], isNull);
    });
  });

  test('Venta.esFiada solo con cliente asignado', () {
    expect(_venta(total: 1).esFiada, isFalse);
    expect(_venta(total: 1, fiadoA: 'c1').esFiada, isTrue);
  });
}
