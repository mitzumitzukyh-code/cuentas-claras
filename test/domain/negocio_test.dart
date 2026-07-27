import 'package:cuentaclara/features/negocio/domain/metodo_pago_config.dart';
import 'package:cuentaclara/features/negocio/domain/negocio.dart';
import 'package:cuentaclara/features/onboarding/domain/rubro.dart';
import 'package:cuentaclara/features/ventas/domain/venta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rubro', () {
    test('fromId devuelve el enum correcto', () {
      expect(Rubro.fromId('bodega'), Rubro.bodega);
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

    test('ropa tiene variantes y foto obligatoria', () {
      expect(Rubro.ropa.config.usaVariantes, true);
      expect(Rubro.ropa.config.fotoObligatoria, true);
      expect(Rubro.ropa.config.etiquetasVariante, contains('Talla'));
    });

    test('comida rapida tiene receta', () {
      expect(Rubro.comidaRapida.config.usaReceta, true);
      expect(Rubro.comidaRapida.config.usaUnidadMedida, true);
    });

    test('belleza tiene fecha de vencimiento', () {
      expect(Rubro.belleza.config.usaFechaVencimiento, true);
      expect(Rubro.belleza.config.fotoObligatoria, true);
    });
  });

  group('RubroConfig', () {
    test('toMap serializa correctamente', () {
      final cfg = RubroConfig(
        usaVariantes: true,
        usaFechaVencimiento: true,
        etiquetasVariante: ['Talla', 'Color'],
      );
      final map = cfg.toMap();
      expect(map['usaVariantes'], true);
      expect(map['usaFechaVencimiento'], true);
      expect(map['etiquetasVariante'], ['Talla', 'Color']);
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
