import 'package:flutter/material.dart';

/// Rubro del negocio (CLAUDE.md §4). Determina qué campos/pantallas se muestran.
enum Rubro {
  bodega,
  ropa,
  belleza,
  quincalleria,
  comidaRapida,
  electronica,
  otro;

  /// ID persistido en Firestore (coincide con el enum del brief).
  String get id => switch (this) {
        Rubro.bodega => 'bodega',
        Rubro.ropa => 'ropa',
        Rubro.belleza => 'belleza',
        Rubro.quincalleria => 'quincalleria',
        Rubro.comidaRapida => 'comida_rapida',
        Rubro.electronica => 'electronica',
        Rubro.otro => 'otro',
      };

  static Rubro fromId(String? id) => Rubro.values.firstWhere(
        (r) => r.id == id,
        orElse: () => Rubro.otro,
      );

  String get etiqueta => switch (this) {
        Rubro.bodega => 'Bodega / Abasto',
        Rubro.ropa => 'Ropa',
        Rubro.belleza => 'Belleza',
        Rubro.quincalleria => 'Quincallería',
        Rubro.comidaRapida => 'Comida rápida',
        Rubro.electronica => 'Electrónica',
        Rubro.otro => 'Otro',
      };

  IconData get icono => switch (this) {
        Rubro.bodega => Icons.storefront_outlined,
        Rubro.ropa => Icons.checkroom_outlined,
        Rubro.belleza => Icons.brush_outlined,
        Rubro.quincalleria => Icons.handyman_outlined,
        Rubro.comidaRapida => Icons.lunch_dining_outlined,
        Rubro.electronica => Icons.phone_android_outlined,
        Rubro.otro => Icons.category_outlined,
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
        Rubro.ropa => const RubroConfig(
            usaVariantes: true,
            fotoObligatoria: true,
            etiquetasVariante: ['Talla', 'Color'],
            categoriasSugeridas: ['Damas', 'Caballeros', 'Niños', 'Accesorios'],
          ),
        Rubro.belleza => const RubroConfig(
            usaVariantes: true,
            usaFechaVencimiento: true,
            fotoObligatoria: true,
            etiquetasVariante: ['Tono', 'Color'],
            categoriasSugeridas: [
              'Maquillaje',
              'Cabello',
              'Cuidado de piel',
              'Uñas',
            ],
          ),
        Rubro.quincalleria => const RubroConfig(
            fotoObligatoria: true,
            categoriasSugeridas: [
              'Ferretería',
              'Hogar',
              'Eléctricos',
              'Papelería',
            ],
          ),
        Rubro.comidaRapida => const RubroConfig(
            usaUnidadMedida: true,
            usaReceta: true,
            categoriasSugeridas: [
              'Hamburguesas',
              'Perros',
              'Bebidas',
              'Adicionales',
            ],
          ),
        Rubro.electronica => const RubroConfig(
            usaVariantes: true,
            categoriasSugeridas: [
              'Teléfonos',
              'Tablets',
              'Audífonos',
              'Cargadores',
              'Accesorios',
            ],
          ),
        Rubro.otro => const RubroConfig(
            categoriasSugeridas: ['General'],
          ),
      };
}

/// Configuración derivada del rubro (persistida en `negocio.configuracion`).
class RubroConfig {
  const RubroConfig({
    this.usaVariantes = false,
    this.usaFechaVencimiento = false,
    this.usaUnidadMedida = false,
    this.usaReceta = false,
    this.fotoObligatoria = false,
    this.etiquetasVariante = const [],
    this.categoriasSugeridas = const [],
  });

  /// Producto con tallas/tonos/colores (ropa, belleza).
  final bool usaVariantes;

  /// Fecha de vencimiento por producto (solo belleza).
  final bool usaFechaVencimiento;

  /// Insumos con unidad de medida (solo comida rápida).
  final bool usaUnidadMedida;

  /// Receta de insumos por producto (solo comida rápida).
  final bool usaReceta;

  /// Foto obligatoria al crear producto (ropa, belleza, quincallería).
  final bool fotoObligatoria;

  /// Etiquetas de las dimensiones de variante, ej: ["Talla", "Color"].
  final List<String> etiquetasVariante;

  /// Categorías precargadas para acelerar el alta de productos.
  final List<String> categoriasSugeridas;

  Map<String, dynamic> toMap() => {
        'usaVariantes': usaVariantes,
        'usaFechaVencimiento': usaFechaVencimiento,
        'usaUnidadMedida': usaUnidadMedida,
        'etiquetasVariante': etiquetasVariante,
      };
}
