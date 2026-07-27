import 'package:cuentaclara/features/ventas/domain/venta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MetodoPago', () {
    test('fromId devuelve el enum correcto', () {
      expect(MetodoPago.fromId('efectivo'), MetodoPago.efectivo);
      expect(MetodoPago.fromId('pagomovil'), MetodoPago.pagoMovil);
      expect(MetodoPago.fromId('transferencia'), MetodoPago.transferencia);
      expect(MetodoPago.fromId('zelle'), MetodoPago.zelle);
      expect(MetodoPago.fromId('biopago'), MetodoPago.biopago);
      expect(MetodoPago.fromId('puntos'), MetodoPago.puntoDeVenta);
    });

    test('fromId fallback a efectivo', () {
      expect(MetodoPago.fromId('inventado'), MetodoPago.efectivo);
      expect(MetodoPago.fromId(null), MetodoPago.efectivo);
    });

    test('id roundtrip', () {
      for (final m in MetodoPago.values) {
        expect(MetodoPago.fromId(m.id), m);
      }
    });

    test('etiqueta no es vacia', () {
      for (final m in MetodoPago.values) {
        expect(m.etiqueta.isNotEmpty, true);
        expect(m.etiquetaCorta.isNotEmpty, true);
      }
    });
  });

  group('ItemVenta', () {
    const base = ItemVenta(
      productoId: 'p1',
      nombre: 'Arroz',
      cantidad: 2,
      precioUnitario: 1.5,
    );

    test('subtotal es cantidad * precioUnitario', () {
      expect(base.subtotal, 3.0);
    });

    test('cantidadLabel entero', () {
      expect(base.cantidadLabel, '2');
    });

    test('cantidadLabel decimal', () {
      const item = ItemVenta(
        productoId: 'p1',
        nombre: 'Queso',
        cantidad: 1.5,
        precioUnitario: 4.0,
        vendidoPorPeso: true,
      );
      expect(item.cantidadLabel, '1,50 kg');
    });

    group('nombreCompleto', () {
      test('sin variante es solo el nombre', () {
        expect(base.nombreCompleto, 'Arroz');
      });

      test('con varianteValor', () {
        const item = ItemVenta(
          productoId: 'p2',
          nombre: 'Camisa',
          cantidad: 1,
          precioUnitario: 15,
          varianteValor: 'M',
        );
        expect(item.nombreCompleto, 'Camisa · M');
      });

      test('con varianteValor y varianteColor', () {
        const item = ItemVenta(
          productoId: 'p2',
          nombre: 'Camisa',
          cantidad: 1,
          precioUnitario: 15,
          varianteValor: 'M',
          varianteColor: 'Rojo',
        );
        expect(item.nombreCompleto, 'Camisa · M / Rojo');
      });
    });

    test('toMap / fromMap roundtrip', () {
      const item = ItemVenta(
        productoId: 'p1',
        nombre: 'Arroz',
        cantidad: 2,
        precioUnitario: 1.5,
        costoUnitario: 1.0,
        fotoUrl: 'https://foto.com/img.jpg',
      );
      final map = item.toMap();
      final restored = ItemVenta.fromMap(map);
      expect(restored.productoId, item.productoId);
      expect(restored.nombre, item.nombre);
      expect(restored.cantidad, item.cantidad);
      expect(restored.precioUnitario, item.precioUnitario);
      expect(restored.costoUnitario, item.costoUnitario);
      expect(restored.fotoUrl, item.fotoUrl);
    });

    test('copyWith actualiza solo el campo indicado', () {
      final modificado = base.copyWith(cantidad: 5);
      expect(modificado.cantidad, 5);
      expect(modificado.productoId, base.productoId);
    });
  });

  group('Venta', () {
    const items = [
      ItemVenta(
        productoId: 'p1',
        nombre: 'Arroz',
        cantidad: 2,
        precioUnitario: 1.5,
        costoUnitario: 1.0,
      ),
      ItemVenta(
        productoId: 'p2',
        nombre: 'Azúcar',
        cantidad: 1,
        precioUnitario: 2.0,
        costoUnitario: 1.2,
      ),
    ];

    final base = Venta(
      id: 'v1',
      items: items,
      totalUSD: 5.0,
      totalBs: 182.5,
      tasaBcvUsada: 36.5,
      vendidoPor: 'usr1',
      fecha: _fecha,
    );

    test('subtotalUSD suma de los subtotales', () {
      expect(base.subtotalUSD, closeTo(5.0, 0.001));
    });

    test('descuentoUSD 0 sin descuento', () {
      expect(base.descuentoUSD, 0);
    });

    test('descuentoUSD con descuento', () {
      final conDto = Venta(
        id: 'v2',
        items: [ItemVenta(productoId: 'p1', nombre: 'X', cantidad: 1, precioUnitario: 100)],
        totalUSD: 90,
        totalBs: 3285,
        tasaBcvUsada: 36.5,
        vendidoPor: 'usr1',
        fecha: _fecha,
        descuentoPct: 10,
      );
      expect(conDto.descuentoUSD, 10);
    });

    test('gananciaUSD solo considera items con costo', () {
      // Arroz: (1.5 - 1.0) * 2 = 1.0
      // Azúcar: (2.0 - 1.2) * 1 = 0.8
      // Total: 1.8
      expect(base.gananciaUSD, closeTo(1.8, 0.001));
    });

    test('itemsSinCosto cuenta los que no tienen costoUnitario', () {
      final conSinCosto = Venta(
        id: 'v3',
        items: [
          ItemVenta(productoId: 'p1', nombre: 'X', cantidad: 1, precioUnitario: 5),
          ItemVenta(
            productoId: 'p2',
            nombre: 'Y',
            cantidad: 1,
            precioUnitario: 10,
            costoUnitario: 6,
          ),
        ],
        totalUSD: 15,
        totalBs: 547.5,
        tasaBcvUsada: 36.5,
        vendidoPor: 'usr1',
        fecha: _fecha,
      );
      expect(conSinCosto.itemsSinCosto, 1);
    });

    test('toMap serializa campos principales', () {
      final map = base.toMap();
      expect(map['totalUSD'], 5.0);
      expect(map['tasaBcvUsada'], 36.5);
      expect(map['vendidoPor'], 'usr1');
      expect(map['anulada'], false);
      expect(map['metodoPago'], 'efectivo');
      expect(map['items'], isA<List>());
      expect((map['items'] as List).length, 2);
    });

    test('anulada se serializa correctamente', () {
      final anulada = Venta(
        id: 'v4',
        items: [],
        totalUSD: 0,
        totalBs: 0,
        tasaBcvUsada: 0,
        vendidoPor: 'usr1',
        fecha: _fecha,
        anulada: true,
      );
      final map = anulada.toMap();
      expect(map['anulada'], true);
    });

    test('IVA se serializa correctamente', () {
      final conIva = Venta(
        id: 'v5',
        items: [ItemVenta(productoId: 'p1', nombre: 'X', cantidad: 1, precioUnitario: 100)],
        totalUSD: 116,
        totalBs: 4234,
        tasaBcvUsada: 36.5,
        vendidoPor: 'usr1',
        fecha: _fecha,
        ivaUSD: 16,
      );
      expect(conIva.ivaUSD, 16);
      expect(conIva.toMap()['ivaUSD'], 16);
    });
  });
}

final _fecha = DateTime(2026, 7, 26);
