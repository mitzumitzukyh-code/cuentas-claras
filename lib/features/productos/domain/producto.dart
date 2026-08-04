import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/money_formatter.dart';
import 'insumo.dart';
import 'variante.dart';

/// Cómo se gestiona el inventario de este producto.
enum TipoProducto {
  simple,
  variantes,
  serial;

  String get id => name;

  static TipoProducto fromId(String? id) => switch (id) {
        'variantes' => TipoProducto.variantes,
        'serial' => TipoProducto.serial,
        _ => TipoProducto.simple,
      };
}

/// Producto del inventario (CLAUDE.md §4: `negocios/{id}/productos/{id}`).
class Producto {
  const Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    this.precio,
    this.costo,
    required this.cantidad,
    this.fotoUrl,
    this.variantes = const [],
    this.alertaEn,
    this.fechaVencimiento,
    this.codigoBarras,
    this.vendidoPorPeso = false,
    this.tipo = TipoProducto.simple,
    this.bloquearAlAgotarse = false,
    this.precioAnterior,
    this.enOferta = false,
    this.garantiaMeses,
    this.receta = const [],
    this.unidad,
    this.extras = const {},
    this.requiereRevision = false,
  });

  final String id;
  final String nombre;
  final String categoria;

  /// Precio en USD (CLAUDE.md §6). **Puede ser `null`.**
  ///
  /// `null` = no se sabe cuánto cuesta, no "cuesta cero". Pasa cuando la
  /// lectura de una foto de inventario no pudo leer la cifra: antes se
  /// guardaba `0`, y un producto en $0,00 se puede cobrar — se regala la
  /// mercancía sin que nadie lo note. Un producto sin precio no entra al
  /// carrito (ver [sePuedeVender]).
  final double? precio;

  /// Algo de este producto lo puso una lectura automática y nadie lo confirmó.
  ///
  /// Se marca al importar cuando un campo vino ilegible o ausente. Mientras
  /// esté en `true`, el producto se muestra señalado en la mercancía.
  final bool requiereRevision;

  /// `false` si no se le puede poner precio a la venta.
  bool get sePuedeVender => precio != null && precio! > 0;

  /// Lo que costó reponer una unidad (o un kilo), en USD. `null` si el dueño
  /// no lo ha registrado: la ganancia de ese producto no se puede calcular y
  /// se dice así, en vez de inventar que costó cero.
  final double? costo;

  /// Stock disponible. Si hay [variantes], es la suma de sus cantidades.
  ///
  /// Es decimal porque los productos [vendidoPorPeso] se descuentan en kilos
  /// fraccionados (medio kilo de arroz deja 49,5 y no 49).
  final double cantidad;
  final String? fotoUrl;
  final List<Variante> variantes;

  /// Umbral de stock bajo para alertas.
  final int? alertaEn;

  /// Solo belleza.
  final DateTime? fechaVencimiento;

  /// Código de barras escaneado al dar de alta el producto (pantalla 6).
  final String? codigoBarras;

  /// Se vende por kilogramos: al cobrar se pide el peso y el precio se calcula
  /// como `precio × kg` en vez de por unidad.
  final bool vendidoPorPeso;

  /// Cómo se gestiona el inventario: simple, con variantes, o con serial.
  final TipoProducto tipo;

  /// Si `true`, no permite vender este producto cuando el stock llegue a 0.
  final bool bloquearAlAgotarse;

  /// Precio anterior (tachado) cuando está en oferta. `null` si no aplica.
  final double? precioAnterior;

  /// `true` cuando el producto tiene un precio promocional vigente.
  final bool enOferta;

  /// Meses de garantía (solo Electrónica). `null` = sin garantía.
  final int? garantiaMeses;

  /// Qué insumos consume una unidad de este producto (solo los rubros que
  /// cocinan o arman). Al vender se descuentan del inventario de insumos.
  final List<LineaReceta> receta;

  /// Unidad en que se vende ('unidad', 'kg', 'docena', 'bandeja'…).
  ///
  /// Sale de `BusinessProfile.allowedUnits`. `null` en los productos creados
  /// antes de que el campo existiera: se muestran con la unidad por defecto
  /// del perfil, que es lo que ya se asumía.
  final String? unidad;

  /// Campos propios del rubro, por clave (`BusinessProfile.extraFields`).
  ///
  /// Bolsa abierta a propósito: agregar un campo a un rubro no debe obligar a
  /// migrar el documento ni a tocar este modelo.
  ///
  /// Lo que tiene columna propia aquí **no** se guarda además en `extras`: el
  /// formulario hace de puente (la regla, en `CLAUDE.md` §8.b). Hoy el único
  /// caso es `vencimiento` → [fechaVencimiento].
  final Map<String, dynamic> extras;

  bool get tieneReceta => receta.isNotEmpty;

  /// Porcentaje de descuento derivado, para pintar "−16 %".
  int? get descuentoPct {
    final actual = precio;
    if (!enOferta || actual == null || precioAnterior == null ||
        precioAnterior == 0) {
      return null;
    }
    return ((precioAnterior! - actual) / precioAnterior! * 100).round();
  }

  /// El precio listo para pintar.
  ///
  /// "Sin precio" y no "\$0,00": un cero se lee como "es gratis" y es
  /// exactamente lo que hacía que se regalara mercancía.
  String get precioLabel =>
      precio == null ? 'Sin precio' : MoneyFormatter.usd(precio!);

  /// `true` si el precio de oferta es el vigente (el getter `precio` siempre
  /// es el vigente; `precioAnterior` es el tachado).
  bool get tieneOferta => enOferta && precioAnterior != null && precio != null;

  bool get tieneVariantes => variantes.isNotEmpty;

  /// `true` si el stock está en o por debajo del umbral configurado.
  bool get stockBajo => alertaEn != null && cantidad <= alertaEn!;

  /// Stock listo para pintar: "23" si es entero, "1,5 kg" si se vende por peso.
  String get cantidadLabel => formatearCantidad(cantidad, vendidoPorPeso);

  /// Stock con su unidad: "12,5 kg", "3 docenas", "23".
  ///
  /// [unidadPorDefecto] es la del perfil del negocio: los productos creados
  /// antes de que existiera [unidad] no la traen, y mostrarlos sin unidad
  /// mientras los nuevos sí la tienen se vería como un error de datos.
  ///
  /// "unidad" no se escribe —"quedan 12 unidad" no lo dice nadie— y ahí manda
  /// [cantidadLabel], que ya sabe poner "kg" si el producto se pesa.
  String cantidadCon(String? unidadPorDefecto) {
    final propia = unidad?.trim();
    final u = (propia != null && propia.isNotEmpty)
        ? propia
        : unidadPorDefecto?.trim();
    if (u == null || u.isEmpty || u == 'unidad') return cantidadLabel;
    return '${formatearCantidad(cantidad, false)} ${_plural(u)}';
  }

  /// Plural de la unidad, solo para las que terminan en vocal: "docenas",
  /// "bandejas", "litros". Las que terminan en consonante se dejan como están
  /// —"kg" y "ml" no pluralizan— a costa de que "par" y "ración" queden en
  /// singular; un pluralizador de español completo no vale lo que cuesta.
  static String _plural(String unidad) {
    if (!'aeiou'.contains(unidad.substring(unidad.length - 1))) return unidad;
    return '${unidad}s';
  }

  /// Oculta los decimales cuando no aportan nada ("23" en vez de "23,0").
  static String formatearCantidad(double valor, bool porPeso) {
    final texto = valor == valor.roundToDouble()
        ? valor.toStringAsFixed(0)
        : valor.toStringAsFixed(2).replaceAll('.', ',');
    return porPeso ? '$texto kg' : texto;
  }

  factory Producto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Producto(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      categoria: (data['categoria'] as String?) ?? '',
      // Sin `?? 0`: un documento sin precio es un producto sin precio.
      precio: (data['precio'] as num?)?.toDouble(),
      costo: (data['costo'] as num?)?.toDouble(),
      cantidad: (data['cantidad'] as num?)?.toDouble() ?? 0,
      fotoUrl: data['fotoUrl'] as String?,
      variantes: ((data['variantes'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Variante.fromMap)
          .toList(),
      alertaEn: (data['alertaEn'] as num?)?.toInt(),
      fechaVencimiento: (data['fechaVencimiento'] as Timestamp?)?.toDate(),
      codigoBarras: data['codigoBarras'] as String?,
      vendidoPorPeso: (data['vendidoPorPeso'] as bool?) ?? false,
      tipo: TipoProducto.fromId(data['tipo'] as String?),
      bloquearAlAgotarse: (data['bloquearAlAgotarse'] as bool?) ?? false,
      precioAnterior: (data['precioAnterior'] as num?)?.toDouble(),
      enOferta: (data['enOferta'] as bool?) ?? false,
      garantiaMeses: (data['garantiaMeses'] as num?)?.toInt(),
      receta: ((data['receta'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LineaReceta.fromMap)
          .toList(),
      unidad: data['unidad'] as String?,
      requiereRevision: (data['requiereRevision'] as bool?) ?? false,
      extras: Map<String, dynamic>.from(
        (data['extras'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'categoria': categoria,
        'precio': precio,
        'costo': costo,
        'cantidad': cantidad,
        'fotoUrl': fotoUrl,
        'variantes': variantes.map((v) => v.toMap()).toList(),
        'alertaEn': alertaEn,
        'fechaVencimiento': fechaVencimiento == null
            ? null
            : Timestamp.fromDate(fechaVencimiento!),
        'codigoBarras': codigoBarras,
        'vendidoPorPeso': vendidoPorPeso,
        'tipo': tipo.id,
        'bloquearAlAgotarse': bloquearAlAgotarse,
        'precioAnterior': precioAnterior,
        'enOferta': enOferta,
        'garantiaMeses': garantiaMeses,
        'receta': receta.map((l) => l.toMap()).toList(),
        'unidad': unidad,
        'requiereRevision': requiereRevision,
        'extras': extras,
      };
}
