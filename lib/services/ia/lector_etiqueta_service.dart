import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/firebase_providers.dart';
import '../../core/utils/numero_ve.dart';
import '../../shared/utils/errores.dart';

const String _baseUrl = 'https://cuenta-clara-tasa.mitzumitzukyhs.workers.dev';

/// Sugerencia que la IA extrajo de la foto de un producto.
class SugerenciaEtiqueta {
  const SugerenciaEtiqueta({
    required this.nombre,
    required this.confianza,
    this.categoria,
    this.presentacion,
  });

  final String nombre;

  /// Categoría sugerida. Solo llega si coincide con una de las categorías de
  /// la tienda (el Worker descarta las inventadas), así que se puede
  /// seleccionar el chip directamente.
  final String? categoria;

  /// "1kg", "2L", "12 uds"… o `null` si la foto no la muestra.
  final String? presentacion;

  /// `alta` | `media` | `baja`. Se usa para avisar cuando conviene revisar
  /// bien antes de aceptar la sugerencia, nunca para bloquearla.
  final String confianza;
}

/// Qué tan segura viene una lectura. Por campo, no por documento: en una foto
/// se lee el nombre perfecto y el precio a medias, y decir "confianza media"
/// del documento entero no ayuda a saber qué revisar.
enum Confianza { alta, media, baja }

Confianza _confianzaDe(Object? crudo) => switch (crudo) {
  'alta' => Confianza.alta,
  'baja' => Confianza.baja,
  _ => Confianza.media,
};

/// Qué clase de papel se fotografió.
///
/// Una factura de compra trae precios de COSTO, no de venta: cargarlos como
/// precio de venta sin avisar deja al dueño vendiendo a lo que le costó.
enum TipoDocumento { inventario, facturaCompra, desconocido }

TipoDocumento _tipoDocumentoDe(Object? crudo) => switch (crudo) {
  'inventario' => TipoDocumento.inventario,
  'factura_compra' => TipoDocumento.facturaCompra,
  _ => TipoDocumento.desconocido,
};

/// Una fila leída de la foto de una libreta o lista de inventario.
class FilaLibreta {
  const FilaLibreta({
    required this.nombre,
    this.precio,
    this.cantidad,
    this.codigo,
    this.talla,
    this.color,
    this.confianzaPrecio = Confianza.media,
    this.confianzaCantidad = Confianza.media,
  });

  final String nombre;

  /// `null` = no se pudo leer. **Nunca 0**: un cero se cobra.
  final double? precio;
  final double? cantidad;

  /// Código del artículo si la lista trae columna de código. Es la clave por la
  /// que se unen las filas repetidas en bodega y repuestos.
  final String? codigo;

  /// Solo si la lista trae columna de talla o color: entonces dos filas con el
  /// mismo nombre no son un duplicado, son dos variantes.
  final String? talla;
  final String? color;

  final Confianza confianzaPrecio;
  final Confianza confianzaCantidad;

  /// `true` si algo de esta fila hay que mirarlo antes de guardar.
  bool get dudosa =>
      precio == null ||
      cantidad == null ||
      confianzaPrecio == Confianza.baja ||
      confianzaCantidad == Confianza.baja;

  /// Lo que distingue a esta fila de otra: código si lo hay, si no el nombre
  /// normalizado, más la variante cuando la lista la declara.
  String get clave {
    final base = (codigo != null && codigo!.trim().isNotEmpty)
        ? 'cod:${codigo!.trim().toLowerCase()}'
        : 'nom:${nombre.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
    final variante = [
      if ((talla ?? '').trim().isNotEmpty) talla!.trim().toLowerCase(),
      if ((color ?? '').trim().isNotEmpty) color!.trim().toLowerCase(),
    ].join('/');
    return variante.isEmpty ? base : '$base|$variante';
  }

  FilaLibreta copyCon({double? precio, double? cantidad}) => FilaLibreta(
        nombre: nombre,
        precio: precio ?? this.precio,
        cantidad: cantidad ?? this.cantidad,
        codigo: codigo,
        talla: talla,
        color: color,
        confianzaPrecio: confianzaPrecio,
        confianzaCantidad: confianzaCantidad,
      );
}

/// El resultado completo de leer una lista de inventario.
class LecturaInventario {
  const LecturaInventario({
    required this.filas,
    this.tipo = TipoDocumento.inventario,
    this.totalDeclarado,
    this.cuadra = true,
  });

  final List<FilaLibreta> filas;
  final TipoDocumento tipo;

  /// Si la lista declara un total ("Total Artículos: 423"), se guarda para
  /// contrastarlo con la suma de lo leído.
  final double? totalDeclarado;

  /// `false` si el total declarado no coincide con la suma de existencias: la
  /// lectura se quedó corta o leyó de más, y hay que revisarla entera.
  final bool cuadra;

  int get dudosas => filas.where((f) => f.dudosa).length;
}

/// Une las filas que son el mismo artículo.
///
/// La distinción importa y no se puede resolver con una sola regla:
/// - **Bodega y repuestos:** el mismo código en varias filas es el mismo
///   artículo anotado dos veces (o en dos estantes). Se suman las existencias.
/// - **Ropa:** el mismo nombre con distinta talla o color NO es un duplicado,
///   son variantes, y cada una lleva su propio stock.
///
/// La pista es la propia lista: si trae columna de talla o color, esa columna
/// entra en la clave y las filas dejan de unirse.
///
/// El precio del grupo es el primero que se pudo leer: si una fila lo trae y
/// otra no, se conserva el que existe en vez de perderlo.
List<FilaLibreta> consolidarFilas(List<FilaLibreta> filas) {
  final porClave = <String, FilaLibreta>{};
  final orden = <String>[];

  for (final f in filas) {
    final k = f.clave;
    final previa = porClave[k];
    if (previa == null) {
      porClave[k] = f;
      orden.add(k);
      continue;
    }
    final cantidad = (previa.cantidad == null && f.cantidad == null)
        ? null
        : (previa.cantidad ?? 0) + (f.cantidad ?? 0);
    porClave[k] = previa.copyCon(
      cantidad: cantidad,
      precio: previa.precio ?? f.precio,
    );
  }

  return [for (final k in orden) porClave[k]!];
}

/// Datos extraídos de la foto de un recibo de compra.
class DatosRecibo {
  const DatosRecibo({
    this.monto,
    this.moneda = 'USD',
    this.fecha,
    this.descripcion,
    this.categoria,
  });

  final double? monto;

  /// `USD` o `VES`: los recibos venezolanos suelen venir en bolívares y el
  /// gasto se registra en dólares, así que la app convierte con la tasa BCV.
  final String moneda;
  final DateTime? fecha;
  final String? descripcion;

  /// `mercancia` | `transporte` | `servicios` | `otro`, o `null`.
  final String? categoria;
}

/// No se reconoció nada útil en la foto (borrosa, no es lo esperado).
class SinReconocer implements Exception {}

/// Se agotó la cuota diaria de lecturas con IA (el Worker devuelve 429).
class LimiteDiarioIA implements Exception {}

/// Lecturas con IA (vía el Worker; la clave de Gemini nunca viaja en el APK).
///
/// La sugerencia NUNCA se guarda sola: solo rellena campos para que el dueño
/// los revise y confirme al guardar, igual que si los hubiera tecleado él
/// mismo. Un modelo de visión se equivoca con fotos borrosas, en mal ángulo o
/// con letra difícil, y un registro con datos inventados es peor que uno
/// vacío.
class LectorEtiquetaService {
  LectorEtiquetaService(this._auth, {http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _cliente;

  /// Lee la etiqueta de un producto: nombre, presentación y categoría.
  /// [rubro] es el `Rubro.id` del negocio. El Worker lo usa para elegir qué
  /// mirar en la foto: en una bodega busca marca y gramaje, en ropa el tipo de
  /// prenda y el color, en quincallería la medida. Sin él, una blusa volvía
  /// con nombre genérico y una presentación inventada.
  Future<SugerenciaEtiqueta> leer(
    File foto, {
    List<String> categorias = const [],
    String rubro = '',
  }) async {
    final datos = await _llamar('/leer-etiqueta', foto, extras: {
      'categorias': categorias,
      'rubro': rubro,
    });
    if (datos['reconocido'] != true) throw SinReconocer();

    return SugerenciaEtiqueta(
      nombre: datos['nombreSugerido'] as String,
      categoria: datos['categoriaSugerida'] as String?,
      presentacion: datos['presentacion'] as String?,
      confianza: datos['confianza'] as String? ?? 'media',
    );
  }

  /// Lee una lista de inventario (impresa o manuscrita) y devuelve sus filas
  /// ya normalizadas y consolidadas.
  ///
  /// Los números llegan como texto y se interpretan aquí con
  /// [normalizarPositivoVE]: `4.500,80` es determinista y no hace falta un
  /// modelo para resolverlo — pedírselo a Gemini daba a veces `4.5` y a veces
  /// `450080`, sin forma de saber cuál había pasado.
  Future<LecturaInventario> leerLibreta(File foto) async {
    final datos = await _llamar('/leer-libreta', foto);
    if (datos['reconocido'] != true) throw SinReconocer();

    final filas = ((datos['filas'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((f) => FilaLibreta(
              nombre: ((f['nombre'] as String?) ?? '').trim(),
              precio: normalizarPositivoVE(f['precio']),
              cantidad: normalizarPositivoVE(f['cantidad']),
              codigo: (f['codigo'] as String?)?.trim(),
              talla: (f['talla'] as String?)?.trim(),
              color: (f['color'] as String?)?.trim(),
              confianzaPrecio: _confianzaDe(f['confianzaPrecio']),
              confianzaCantidad: _confianzaDe(f['confianzaCantidad']),
            ))
        .where((f) => f.nombre.isNotEmpty)
        .toList();

    final consolidadas = consolidarFilas(filas);
    final total = normalizarPositivoVE(datos['totalDeclarado']);

    // Validación cruzada: si la lista dice "Total Artículos: 423" y lo leído
    // suma otra cosa, la lectura se quedó corta o leyó de más. No se corrige
    // sola — se avisa, que es lo único honesto.
    final sumaLeida = consolidadas.fold<double>(
      0,
      (s, f) => s + (f.cantidad ?? 0),
    );
    final cuadra = total == null || (total - sumaLeida).abs() < 0.5;

    return LecturaInventario(
      filas: consolidadas,
      tipo: _tipoDocumentoDe(datos['tipoDocumento']),
      totalDeclarado: total,
      cuadra: cuadra,
    );
  }

  /// Lee un recibo de compra: monto, moneda, fecha, descripción y categoría.
  Future<DatosRecibo> leerRecibo(File foto) async {
    final datos = await _llamar('/leer-recibo', foto);
    if (datos['reconocido'] != true) throw SinReconocer();

    return DatosRecibo(
      monto: (datos['monto'] as num?)?.toDouble(),
      moneda: datos['moneda'] == 'VES' ? 'VES' : 'USD',
      fecha: DateTime.tryParse((datos['fecha'] as String?) ?? ''),
      descripcion: datos['descripcion'] as String?,
      categoria: datos['categoria'] as String?,
    );
  }

  Future<Map<String, dynamic>> _llamar(
    String ruta,
    File foto, {
    Map<String, Object?> extras = const {},
  }) async {
    final usuario = _auth.currentUser;
    if (usuario == null) {
      throw StateError('Sin sesión: no se puede pedir la lectura con IA.');
    }
    final idToken = await usuario.getIdToken();

    final bytes = await foto.readAsBytes();
    final extension = foto.path.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    // Mismo criterio que la subida de fotos: un bache de red no puede costarle
    // al dueño volver a tomar la foto.
    final respuesta = await conReintentos(
      () => _cliente
          .post(
            Uri.parse('$_baseUrl$ruta'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'imagenBase64': base64Encode(bytes),
              'mimeType': mimeType,
              ...extras,
            }),
          )
          .timeout(const Duration(seconds: 30)),
    );

    if (respuesta.statusCode == 429) throw LimiteDiarioIA();
    if (respuesta.statusCode != 200) {
      throw Exception(
        'No se pudo leer la foto (código ${respuesta.statusCode}).',
      );
    }

    return jsonDecode(respuesta.body) as Map<String, dynamic>;
  }
}

final lectorEtiquetaServiceProvider = Provider<LectorEtiquetaService>((ref) {
  return LectorEtiquetaService(ref.watch(firebaseAuthProvider));
});
