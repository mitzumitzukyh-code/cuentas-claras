/// Capa de configuración por tipo de negocio.
///
/// La app tiene **un solo core**: no hay pantallas ni carpetas por vertical.
/// Lo que cambia entre una bodega y una tienda de ropa es el vocabulario, las
/// unidades que se ofrecen, los campos extra y los atajos del Inicio — todo
/// eso vive en un [BusinessProfile] que la UI lee como dato.
///
/// El perfil cuelga 1:1 del [Rubro] que el negocio eligió en el onboarding: no
/// hay un segundo eje que mantener sincronizado ni un mapeo que fuerce a un
/// rubro a comportarse como otro. Un rubro, un perfil.
///
/// Regla dura: ningún widget hace `switch` por rubro. Si hace falta un
/// `switch`, va en `business_presets.dart`.
library;

import '../../features/onboarding/domain/rubro.dart';

/// Cómo se captura un [ExtraField] en el formulario.
enum ExtraFieldType { text, date, number, select }

/// Un campo propio del rubro que se guarda dentro del producto, en el mapa
/// `extras` — nunca como columna fija del documento.
class ExtraField {
  const ExtraField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options,
    this.allowsCustom = false,
    this.suffix,
  });

  /// Clave dentro de `producto.extras` ('vencimiento', 'talla', 'color', …).
  final String key;

  /// Texto que ve el usuario.
  final String label;

  final ExtraFieldType type;

  final bool required;

  /// Opciones de un [ExtraFieldType.select].
  final List<String>? options;

  /// `true` = además de [options], el usuario puede escribir un valor libre.
  /// Las tallas no se acaban en XXL: hay negocios que manejan 38, 40, "Talla
  /// única". Sin esto el select sería una jaula.
  final bool allowsCustom;

  /// Sufijo de un [ExtraFieldType.number] ('min', 'cm'). Solo presentación.
  final String? suffix;
}

/// Cómo se le habla al usuario de lo que vende.
class Vocabulary {
  const Vocabulary({
    required this.itemSingular,
    required this.itemPlural,
    required this.inventoryLabel,
    required this.addItemCta,
  });

  /// 'producto' | 'prenda' | 'repuesto'
  final String itemSingular;

  /// 'productos' | 'prendas' | 'repuestos'
  final String itemPlural;

  /// Título de la pantalla y label del tab: 'Mercancía' | 'Catálogo'.
  final String inventoryLabel;

  /// CTA del botón de alta: 'Agregar producto'.
  final String addItemCta;
}

/// Un atajo del grid del Inicio.
class HomeShortcut {
  const HomeShortcut({
    required this.id,
    required this.label,
    required this.iconKey,
    required this.route,
    this.enabled = true,
    this.permiso,
  });

  /// 'cobrar' | 'fiados' | 'merma' | 'tallas' | 'cotizar' | 'buscar_codigo'
  final String id;

  final String label;

  /// Ruta del SVG del paquete de marca, tomada de `AppAssets`. Se guarda la
  /// constante (no un `IconData` suelto, ni un string a resolver en runtime)
  /// para que el compilador avise si el asset desaparece.
  final String iconKey;

  /// Path de go_router, de `Routes`.
  final String route;

  /// Permiso que exige la pantalla de destino (`Permisos.*`), o `null` si
  /// cualquiera puede entrar. El Inicio no dibuja atajos que llevan a una
  /// pantalla que le va a decir que no: un botón que solo sirve para ser
  /// rechazado es peor que no tener el botón.
  final String? permiso;

  /// `false` = el atajo está definido pero todavía no tiene pantalla que lo
  /// respalde, así que no se dibuja. Un botón que no lleva a ninguna parte se
  /// siente como una app rota; se prefiere que no exista hasta que exista.
  final bool enabled;
}

/// Configuración completa de un rubro. Siempre es una constante de
/// `business_presets.dart` — nunca se construye desde Firestore.
///
/// El nombre visible, el ícono y el color no están aquí: son del [Rubro]
/// (`rubro.etiqueta`, `rubro.icono`, `rubro.color`), que es quien manda.
class BusinessProfile {
  const BusinessProfile({
    required this.rubro,
    required this.defaultUnit,
    required this.allowedUnits,
    required this.extraFields,
    required this.vocab,
    required this.shortcuts,
    this.usaVariantes = false,
    this.usaUnidadMedida = false,
    this.usaReceta = false,
    this.usaSerial = false,
    this.vendePorPeso = false,
    this.fotoObligatoria = false,
    this.etiquetasVariante = const [],
  });

  final Rubro rubro;

  /// 'unidad' | 'kg' | 'ración'
  final String defaultUnit;

  /// Unidades que ofrece el formulario de producto.
  final List<String> allowedUnits;

  /// Campos propios del rubro. **En la Fase 3 esta lista es la única fuente de
  /// qué campos extra pinta el formulario** (ver `CLAUDE.md` §8.b).
  final List<ExtraField> extraFields;

  final Vocabulary vocab;

  final List<HomeShortcut> shortcuts;

  // ── Capacidades del formulario de producto ────────────────────────────
  //
  // Vivían en `RubroConfig`. Son decisiones de *cómo se captura* el producto,
  // que es justo lo que define un perfil; en el rubro quedó solo lo que
  // describe *qué se vende* y viaja al Worker.
  //
  // Las que se podían expresar como [extraFields] ya se eliminaron: el
  // vencimiento es hoy un `ExtraField` de tipo fecha, no una bandera. Las que
  // quedan encienden bloques enteros del formulario (un editor de variantes,
  // una receta, un serial), no un campo suelto, así que no son expresables
  // como `ExtraField` sin inventarle al modelo un tipo por cada bloque.

  /// Producto con tallas/tonos/capacidades y stock por variante.
  final bool usaVariantes;

  /// Insumos con unidad de medida.
  final bool usaUnidadMedida;

  /// Receta de insumos por producto.
  final bool usaReceta;

  /// El producto se identifica por un serial y puede llevar garantía.
  final bool usaSerial;

  /// El producto se puede vender a granel, con el precio calculado por kilo.
  final bool vendePorPeso;

  /// Foto obligatoria al crear producto.
  final bool fotoObligatoria;

  /// Cómo se rotulan las dos dimensiones de variante: `['Talla', 'Color']`.
  /// Va junto a [usaVariantes]: la bandera y sus etiquetas sin separar, porque
  /// leerlas de dos objetos distintos era garantía de desincronizarlas.
  final List<String> etiquetasVariante;

  /// Lo que el grid del Inicio debe dibujar. La lista completa [shortcuts]
  /// queda para el día que se agreguen las pantallas que faltan.
  List<HomeShortcut> get atajosVisibles =>
      [for (final a in shortcuts) if (a.enabled) a];
}
