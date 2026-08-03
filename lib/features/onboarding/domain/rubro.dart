import 'package:flutter/material.dart';

import '../../../core/theme/app_assets.dart';

/// Rubro del negocio (CLAUDE.md §4). Determina qué campos/pantallas se muestran.
enum Rubro {
  bodega,
  panaderia,
  ropa,
  belleza,
  quincalleria,
  comidaRapida,
  electronica,
  otro;

  /// ID persistido en Firestore (coincide con el enum del brief).
  String get id => switch (this) {
    Rubro.bodega => 'bodega',
    Rubro.panaderia => 'panaderia',
    Rubro.ropa => 'ropa',
    Rubro.belleza => 'belleza',
    Rubro.quincalleria => 'quincalleria',
    Rubro.comidaRapida => 'comida_rapida',
    Rubro.electronica => 'electronica',
    Rubro.otro => 'otro',
  };

  static Rubro fromId(String? id) =>
      Rubro.values.firstWhere((r) => r.id == id, orElse: () => Rubro.otro);

  String get etiqueta => switch (this) {
    Rubro.bodega => 'Bodega / Abasto',
    Rubro.panaderia => 'Panadería',
    Rubro.ropa => 'Ropa',
    Rubro.belleza => 'Belleza',
    Rubro.quincalleria => 'Quincallería',
    Rubro.comidaRapida => 'Comida rápida',
    Rubro.electronica => 'Electrónica',
    Rubro.otro => 'Otro',
  };

  /// Color de la pastilla del icono en la selección de rubro (`Lote F · P0`).
  ///
  /// Cada rubro tiene el suyo: la cuadrícula se recorre por color antes que
  /// por texto, y dos bodegas seguidas en verde no se distinguirían.
  Color get color => switch (this) {
    Rubro.bodega => const Color(0xFF0E9F6E),
    Rubro.panaderia => const Color(0xFFC08A3E),
    Rubro.ropa => const Color(0xFFC1503A),
    Rubro.belleza => const Color(0xFFB5527C),
    Rubro.quincalleria => const Color(0xFFB07D1E),
    Rubro.comidaRapida => const Color(0xFFD9722F),
    Rubro.electronica => const Color(0xFF3D6CA8),
    Rubro.otro => const Color(0xFF8A9A96),
  };

  /// Ícono de categoría del paquete de marca. El trazo de 1.7 y las esquinas
  /// redondeadas del paquete son los que hacen que la cuadrícula de rubros se
  /// lea como un set y no como siete íconos prestados de Material.
  ///
  /// El paquete trae once categorías y el negocio maneja ocho: quincallería
  /// toma el de ferretería y electrónica el de tecnología, que es el mismo
  /// dibujo con otro nombre.
  String get icono => switch (this) {
    Rubro.bodega => AppAssets.catBodega,
    Rubro.panaderia => AppAssets.catPanaderia,
    Rubro.ropa => AppAssets.catRopa,
    Rubro.belleza => AppAssets.catBelleza,
    Rubro.quincalleria => AppAssets.catFerreteria,
    Rubro.comidaRapida => AppAssets.catComida,
    Rubro.electronica => AppAssets.catTecnologia,
    Rubro.otro => AppAssets.catOtros,
  };

  RubroConfig get config => switch (this) {
    Rubro.bodega => const RubroConfig(
      categoriasSugeridas: [
        'Víveres',
        'Bebidas',
        'Limpieza',
        'Golosinas',
        'Otros',
      ],
    ),
    Rubro.panaderia => const RubroConfig(
      categoriasSugeridas: ['Panes', 'Dulces', 'Charcutería', 'Bebidas'],
    ),
    Rubro.ropa => const RubroConfig(
      categoriasSugeridas: ['Damas', 'Caballeros', 'Niños', 'Accesorios'],
    ),
    Rubro.belleza => const RubroConfig(
      categoriasSugeridas: ['Maquillaje', 'Cabello', 'Cuidado de piel', 'Uñas'],
    ),
    Rubro.quincalleria => const RubroConfig(
      categoriasSugeridas: ['Ferretería', 'Hogar', 'Eléctricos', 'Papelería'],
    ),
    Rubro.comidaRapida => const RubroConfig(
      categoriasSugeridas: ['Hamburguesas', 'Perros', 'Bebidas', 'Adicionales'],
    ),
    Rubro.electronica => const RubroConfig(
      categoriasSugeridas: [
        'Teléfonos',
        'Tablets',
        'Audífonos',
        'Cargadores',
        'Accesorios',
      ],
    ),
    Rubro.otro => const RubroConfig(categoriasSugeridas: ['General']),
  };
}

/// Qué **vende** un rubro. Solo las categorías sugeridas.
///
/// Cómo se *captura* el producto —variantes, vencimiento, unidad de medida,
/// receta, serial, peso, foto obligatoria— ya no vive aquí: se mudó a
/// `BusinessProfile` (`lib/core/business/`), que es la capa que configura el
/// formulario. Aquí queda lo que describe el negocio hacia afuera: el
/// [Rubro.id] y la [Rubro.etiqueta] del enum, y estas categorías.
///
/// Se deriva entera del enum [Rubro]. Ya no se lee del documento de Firestore:
/// ver la nota en `Negocio.fromDoc`.
class RubroConfig {
  const RubroConfig({this.categoriasSugeridas = const []});

  /// Categorías precargadas para acelerar el alta de productos.
  final List<String> categoriasSugeridas;

  /// Lo que se escribe en `negocio.configuracion`.
  ///
  /// Nadie lo lee —ni la app, que lo deriva del rubro, ni el Worker— pero se
  /// sigue escribiendo porque los documentos ya creados lo tienen y borrarlo
  /// sería una migración. Es un espejo de solo escritura.
  Map<String, dynamic> toMap() => {
    'categoriasSugeridas': categoriasSugeridas,
  };
}
