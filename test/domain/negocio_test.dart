import 'package:cuentaclara/core/business/business_presets.dart';
import 'package:cuentaclara/core/business/business_profile.dart';
import 'package:cuentaclara/features/negocio/domain/metodo_pago_config.dart';
import 'package:cuentaclara/features/negocio/domain/negocio.dart';
import 'package:cuentaclara/features/onboarding/domain/rubro.dart';
import 'package:cuentaclara/features/ventas/domain/venta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rubro', () {
    test('fromId devuelve el enum correcto', () {
      expect(Rubro.fromId('bodega'), Rubro.bodega);
      expect(Rubro.fromId('panaderia'), Rubro.panaderia);
      expect(Rubro.fromId('ropa'), Rubro.ropa);
      expect(Rubro.fromId('belleza'), Rubro.belleza);
      expect(Rubro.fromId('quincalleria'), Rubro.quincalleria);
      expect(Rubro.fromId('comida_rapida'), Rubro.comidaRapida);
      expect(Rubro.fromId('otro'), Rubro.otro);
    });

    test('fromId fallback a otro', () {
      expect(Rubro.fromId('inventado'), Rubro.otro);
      expect(Rubro.fromId(null), Rubro.otro);
    });

    test('etiqueta no vacia', () {
      for (final r in Rubro.values) {
        expect(r.etiqueta.isNotEmpty, true);
      }
    });

    test('bodega tiene categorias sugeridas', () {
      expect(Rubro.bodega.config.categoriasSugeridas, isNotEmpty);
    });

    test('cada rubro trae sus categorias', () {
      for (final r in Rubro.values) {
        expect(r.config.categoriasSugeridas, isNotEmpty);
      }
    });
  });

  // Las capacidades del formulario —variantes, vencimiento, unidad de medida,
  // receta, serial, peso, foto obligatoria— se mudaron de `RubroConfig` al
  // perfil. Se verifican aquí, una entrada por rubro.
  group('perfil del rubro', () {
    test('cada rubro tiene preset propio', () {
      expect(businessPresets.length, Rubro.values.length);
      for (final r in Rubro.values) {
        expect(perfilDe(r).rubro, r);
      }
    });

    test('ropa: variantes Talla/Color, foto obligatoria, habla de prendas', () {
      final p = perfilDe(Rubro.ropa);
      expect(p.usaVariantes, true);
      expect(p.etiquetasVariante, ['Talla', 'Color']);
      expect(p.fotoObligatoria, true);
      expect(p.vocab.itemPlural, 'prendas');
    });

    test('belleza: variantes Tono/Color, vencimiento y habla de productos', () {
      final p = perfilDe(Rubro.belleza);
      expect(p.usaVariantes, true);
      expect(p.etiquetasVariante, ['Tono', 'Color']);
      expect(p.vocab.itemSingular, 'producto');
      // El vencimiento ya no es una bandera: es un campo extra como cualquier
      // otro, y la sección del formulario lo pinta desde aquí.
      expect(p.extraFields.map((c) => c.key), contains('vencimiento'));
    });

    test('panaderia: se vende por kg y vence', () {
      final p = perfilDe(Rubro.panaderia);
      expect(p.defaultUnit, 'kg');
      expect(p.allowedUnits, ['kg', 'unidad', 'docena', 'bandeja']);
      expect(p.extraFields.single.key, 'vencimiento');
      expect(p.extraFields.single.type, ExtraFieldType.date);
      expect(p.vocab.inventoryLabel, 'Mercancía');
      expect(p.atajosVisibles.map((a) => a.id), ['cobrar', 'merma']);
    });

    test('electronica no ofrece pares', () {
      expect(perfilDe(Rubro.electronica).allowedUnits, isNot(contains('par')));
    });

    test('todo select trae opciones', () {
      for (final p in businessPresets.values) {
        for (final campo in p.extraFields) {
          if (campo.type != ExtraFieldType.select) continue;
          expect(campo.options, isNotNull, reason: '${p.rubro.id}/${campo.key}');
          expect(campo.options, isNotEmpty, reason: '${p.rubro.id}/${campo.key}');
        }
      }
    });

    test('no hay claves de campo extra repetidas dentro de un rubro', () {
      for (final p in businessPresets.values) {
        final claves = p.extraFields.map((c) => c.key).toList();
        expect(claves.toSet().length, claves.length, reason: p.rubro.id);
      }
    });

    test('electronica: variantes Capacidad/Color y serial', () {
      final p = perfilDe(Rubro.electronica);
      expect(p.usaVariantes, true);
      expect(p.etiquetasVariante, ['Capacidad', 'Color']);
      expect(p.usaSerial, true);
    });

    test('comida rapida: unidad de medida y receta', () {
      final p = perfilDe(Rubro.comidaRapida);
      expect(p.usaUnidadMedida, true);
      expect(p.usaReceta, true);
    });

    test('bodega y otro venden por peso, sin variantes', () {
      for (final r in [Rubro.bodega, Rubro.otro]) {
        expect(perfilDe(r).vendePorPeso, true);
        expect(perfilDe(r).usaVariantes, false);
      }
    });

    test('la unidad por defecto siempre está entre las ofrecidas', () {
      for (final p in businessPresets.values) {
        expect(p.allowedUnits, contains(p.defaultUnit));
      }
    });

    test('ningun perfil queda con menos de dos atajos visibles', () {
      for (final p in businessPresets.values) {
        expect(p.atajosVisibles.length, greaterThanOrEqualTo(2));
      }
    });

    test('el Inicio dibuja al menos tres atajos sin contar Cobrar', () {
      for (final p in businessPresets.values) {
        final sinCobrar =
            atajosDeInicio(p).where((a) => a.id != 'cobrar').toList();
        expect(sinCobrar.length, greaterThanOrEqualTo(3), reason: p.rubro.id);
      }
    });

    test('los universales no repiten el destino de un atajo del rubro', () {
      for (final p in businessPresets.values) {
        final rutas = atajosDeInicio(p).map((a) => a.route).toList();
        expect(rutas.toSet().length, rutas.length, reason: p.rubro.id);
      }
    });
  });

  group('MetodoPagoConfig', () {
    test('efectivo viene activo por defecto', () {
      final cfg = MetodoPagoConfig.fromMap(MetodoPago.efectivo, {});
      expect(cfg.activo, true);
    });

    test('transferencia viene inactivo por defecto', () {
      final cfg = MetodoPagoConfig.fromMap(MetodoPago.transferencia, {});
      expect(cfg.activo, false);
    });

    test('resumen con datos', () {
      final cfg = MetodoPagoConfig(
        metodo: MetodoPago.pagoMovil,
        activo: true,
        datos: {'telefono': '04121234567', 'banco': 'Banesco'},
      );
      expect(cfg.resumen, contains('📲 Pago móvil'));
      expect(cfg.resumen, contains('04121234567'));
    });

    test('resumen sin datos solo muestra etiqueta', () {
      final cfg = MetodoPagoConfig(metodo: MetodoPago.efectivo, activo: true);
      expect(cfg.resumen, '💵 Efectivo');
    });

    test('copyWith actualiza campos', () {
      final cfg = MetodoPagoConfig(metodo: MetodoPago.zelle, activo: false);
      final activado = cfg.copyWith(activo: true);
      expect(activado.activo, true);
      expect(activado.metodo, MetodoPago.zelle);
    });

    test('listaDesdeMapa incluye todos los metodos', () {
      final lista = MetodoPagoConfig.listaDesdeMapa({});
      expect(lista.length, MetodoPago.values.length);
    });

    test('listaAMapa / listaDesdeMapa roundtrip', () {
      final lista = MetodoPagoConfig.listaDesdeMapa({});
      final mapa = MetodoPagoConfig.listaAMapa(lista);
      final restaurada = MetodoPagoConfig.listaDesdeMapa(mapa);
      expect(restaurada.length, lista.length);
      expect(restaurada.first.activo, lista.first.activo);
    });
  });

  group('Negocio', () {
    const base = Negocio(
      id: 'n1',
      nombre: 'Mi Bodega',
      rubro: Rubro.bodega,
      configuracion: RubroConfig(),
    );

    test('constructor asigna valores basicos', () {
      expect(base.id, 'n1');
      expect(base.nombre, 'Mi Bodega');
      expect(base.rubro, Rubro.bodega);
    });

    test('metodosActivos filtra solo los activos', () {
      final negocio = Negocio(
        id: 'n2',
        nombre: 'Tienda',
        rubro: Rubro.otro,
        configuracion: RubroConfig(),
        metodosPago: [
          MetodoPagoConfig(metodo: MetodoPago.efectivo, activo: true),
          MetodoPagoConfig(metodo: MetodoPago.transferencia, activo: false),
        ],
      );
      expect(negocio.metodosActivos.length, 1);
      expect(negocio.metodosActivos.first.metodo, MetodoPago.efectivo);
    });

    test('tasaIva es 0.16', () {
      expect(Negocio.tasaIva, 0.16);
    });

    test('defaults correctos', () {
      expect(base.moneda, 'USD');
      expect(base.incluirIva, false);
      expect(base.alertaStockActiva, true);
      expect(base.reciboMensaje, 'Gracias por su compra');
    });

    test('toMap serializa campos principales', () {
      final map = base.toMap();
      expect(map['nombre'], 'Mi Bodega');
      expect(map['rubro'], 'bodega');
      expect(map['moneda'], 'USD');
      expect(map['incluirIva'], false);
    });
  });
}
