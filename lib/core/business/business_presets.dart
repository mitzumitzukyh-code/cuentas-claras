/// Un perfil por rubro. Ocho rubros, ocho entradas.
///
/// Este archivo es el **único** lugar donde puede haber un mapa o un `switch`
/// por rubro. Agregar un rubro = agregar el valor al enum [Rubro] y una
/// entrada a [businessPresets]. Nada más.
///
/// Sin I/O: nada aquí toca Firestore ni `SharedPreferences`.
library;

import '../../app/router/routes.dart';
import '../../features/onboarding/domain/rubro.dart';
import '../../shared/presentation/permiso_requerido.dart' show Permisos;
import '../theme/app_assets.dart';
import 'business_profile.dart';

// ── Vocabularios ────────────────────────────────────────────────────────────
//
// La mayoría de los rubros vende "productos" y su inventario es la "Mercancía".
// Solo se aparta el que de verdad usa otra palabra en el mostrador.

const _vocabProducto = Vocabulary(
  itemSingular: 'producto',
  itemPlural: 'productos',
  inventoryLabel: 'Mercancía',
  addItemCta: 'Agregar producto',
);

const _vocabPrenda = Vocabulary(
  itemSingular: 'prenda',
  itemPlural: 'prendas',
  inventoryLabel: 'Catálogo',
  addItemCta: 'Agregar prenda',
);

// ── Atajos reutilizables ────────────────────────────────────────────────────
//
// `merma`, `cotizar` y `buscar_codigo` no tienen pantalla propia: reutilizan
// una existente que hace el trabajo. `tallas` sí necesitaría una que todavía
// no existe, así que va con `enabled: false` y el grid no lo dibuja.

const _cobrar = HomeShortcut(
  id: 'cobrar',
  label: 'Cobrar',
  iconKey: AppAssets.accEfectivo,
  route: Routes.cobrar,
);

const _fiados = HomeShortcut(
  id: 'fiados',
  label: 'Fiados',
  iconKey: AppAssets.accPendiente,
  route: Routes.fiados,
);

/// Lo que se dañó o se venció se anota como gasto de mercancía.
const _merma = HomeShortcut(
  id: 'merma',
  label: 'Merma',
  iconKey: AppAssets.accAlerta,
  route: Routes.nuevoGasto,
  permiso: Permisos.registrarGastos,
);

/// Apagado: un cuadro de existencias por talla no existe todavía. Mandarlo a
/// la lista de mercancía sería mentir.
const _tallas = HomeShortcut(
  id: 'tallas',
  label: 'Tallas',
  iconKey: AppAssets.catRopa,
  route: Routes.productos,
  enabled: false,
);

/// Una cotización se arma con el mismo carrito de Cobrar, en su segmentado.
const _cotizar = HomeShortcut(
  id: 'cotizar',
  label: 'Cotizar',
  iconKey: AppAssets.accExportar,
  route: Routes.cobrarCotizacion,
);

/// Abre Cobrar con el escáner ya levantado: se apunta a la pieza y aparece.
const _buscarCodigo = HomeShortcut(
  id: 'buscar_codigo',
  label: 'Buscar código',
  iconKey: AppAssets.accEscanear,
  route: Routes.cobrarEscanear,
);

// ── Atajos universales ──────────────────────────────────────────────────────
//
// No dependen del rubro: los tiene cualquier negocio. Existen para que el
// Inicio no dependa de cuántos atajos propios traiga el perfil — con solo los
// del rubro, media docena de perfiles se quedaba en uno o dos.

const _reportes = HomeShortcut(
  id: 'reportes',
  label: 'Reportes',
  iconKey: AppAssets.navReportes,
  route: Routes.reportes,
  permiso: Permisos.verReportes,
);

const _agregarProducto = HomeShortcut(
  id: 'agregar_producto',
  label: 'Agregar',
  iconKey: AppAssets.accAgregar,
  route: Routes.nuevoProducto,
  permiso: Permisos.editarInventario,
);

const _clientes = HomeShortcut(
  id: 'clientes',
  label: 'Clientes',
  iconKey: AppAssets.navClientes,
  route: Routes.fiados,
);

/// Los tres de arriba, en el orden en que se dibujan detrás de los del rubro.
const List<HomeShortcut> atajosUniversales = [
  _reportes,
  _agregarProducto,
  _clientes,
];

/// Lo que el Inicio dibuja: los atajos del rubro y detrás los universales.
///
/// Un universal que lleve al mismo sitio que uno del rubro se descarta: en una
/// bodega, "Clientes" y "Fiados" son la misma pantalla, y dos pastillas al
/// mismo destino con distinto nombre confunden más de lo que ayudan. Gana el
/// del rubro, que es el que habla su idioma.
///
/// No filtra por permisos —eso necesita el negocio activo— ni excluye nada:
/// de eso se encarga `GridAtajos`.
List<HomeShortcut> atajosDeInicio(BusinessProfile perfil) {
  final propios = perfil.atajosVisibles;
  final rutas = {for (final a in propios) a.route};
  return [
    ...propios,
    for (final a in atajosUniversales)
      if (a.enabled && !rutas.contains(a.route)) a,
  ];
}

// ── Presets ─────────────────────────────────────────────────────────────────

const BusinessProfile _bodega = BusinessProfile(
  rubro: Rubro.bodega,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'kg', 'litro', 'paquete'],
  extraFields: [],
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _fiados],
  vendePorPeso: true,
);

const BusinessProfile _panaderia = BusinessProfile(
  rubro: Rubro.panaderia,
  defaultUnit: 'kg',
  allowedUnits: ['kg', 'unidad', 'docena', 'bandeja'],
  extraFields: [
    ExtraField(
      key: 'vencimiento',
      label: 'Vence el',
      type: ExtraFieldType.date,
    ),
  ],
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _merma],
);

const BusinessProfile _ropa = BusinessProfile(
  rubro: Rubro.ropa,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'par'],
  // Sin campos extra: talla y color no son metadata plana, son las dos
  // dimensiones del editor de variantes —cada combinación lleva su propio
  // stock—. Declararlas también aquí pintaría dos veces el mismo dato, una de
  // ellas sin poder contar existencias.
  extraFields: [],
  vocab: _vocabPrenda,
  // `tallas` está apagado, así que sin `fiados` este perfil se quedaría con un
  // solo atajo visible.
  shortcuts: [_cobrar, _fiados, _tallas],
  usaVariantes: true,
  etiquetasVariante: ['Talla', 'Color'],
  fotoObligatoria: true,
);

const BusinessProfile _belleza = BusinessProfile(
  rubro: Rubro.belleza,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'ml', 'gramo', 'paquete'],
  // El tono va en el editor de variantes, como la talla en ropa.
  extraFields: [
    ExtraField(
      key: 'vencimiento',
      label: 'Vence el',
      type: ExtraFieldType.date,
    ),
  ],
  // Un labial no es una prenda: aquí se habla de productos, aunque comparta
  // con la ropa el editor de variantes.
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _fiados],
  usaVariantes: true,
  etiquetasVariante: ['Tono', 'Color'],
  fotoObligatoria: true,
);

const BusinessProfile _quincalleria = BusinessProfile(
  rubro: Rubro.quincalleria,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'par', 'juego', 'docena'],
  extraFields: [],
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _buscarCodigo],
  fotoObligatoria: true,
);

const BusinessProfile _comidaRapida = BusinessProfile(
  rubro: Rubro.comidaRapida,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'ración', 'combo', 'litro'],
  extraFields: [],
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _merma],
  usaUnidadMedida: true,
  usaReceta: true,
);

const BusinessProfile _electronica = BusinessProfile(
  rubro: Rubro.electronica,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'juego'],
  // La garantía la pinta el bloque de serial, con su propia columna
  // (`producto.garantiaMeses`); repetirla como campo extra la partiría en dos.
  extraFields: [],
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _buscarCodigo],
  usaVariantes: true,
  etiquetasVariante: ['Capacidad', 'Color'],
  usaSerial: true,
);

/// El cajón de sastre: no se sabe qué vende, así que se le deja disponible lo
/// que no estorba —peso y cotización— en vez de negárselo.
const BusinessProfile _otro = BusinessProfile(
  rubro: Rubro.otro,
  defaultUnit: 'unidad',
  allowedUnits: ['unidad', 'kg', 'litro', 'hora'],
  extraFields: [],
  vocab: _vocabProducto,
  shortcuts: [_cobrar, _fiados, _cotizar],
  vendePorPeso: true,
);

/// Todos los perfiles, indexados por rubro.
const Map<Rubro, BusinessProfile> businessPresets = {
  Rubro.bodega: _bodega,
  Rubro.panaderia: _panaderia,
  Rubro.ropa: _ropa,
  Rubro.belleza: _belleza,
  Rubro.quincalleria: _quincalleria,
  Rubro.comidaRapida: _comidaRapida,
  Rubro.electronica: _electronica,
  Rubro.otro: _otro,
};

/// Perfil al que cae un negocio que todavía no cargó, o cuyo rubro no se
/// reconoce. Es el mismo cajón de sastre al que cae `Rubro.fromId(null)`.
const BusinessProfile perfilPorDefecto = _otro;

/// El perfil de un rubro. Nunca lanza.
BusinessProfile perfilDe(Rubro rubro) =>
    businessPresets[rubro] ?? perfilPorDefecto;
