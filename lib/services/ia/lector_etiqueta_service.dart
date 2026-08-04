import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/providers/firebase_providers.dart';
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

/// Una fila leída de la foto de una libreta de inventario.
class FilaLibreta {
  const FilaLibreta({required this.nombre, this.precio, this.cantidad});

  final String nombre;
  final double? precio;
  final double? cantidad;
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

  /// Lee una libreta de inventario manuscrita y devuelve sus filas.
  Future<List<FilaLibreta>> leerLibreta(File foto) async {
    final datos = await _llamar('/leer-libreta', foto);
    if (datos['reconocido'] != true) throw SinReconocer();

    return ((datos['filas'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((f) => FilaLibreta(
              nombre: (f['nombre'] as String?) ?? '',
              precio: (f['precio'] as num?)?.toDouble(),
              cantidad: (f['cantidad'] as num?)?.toDouble(),
            ))
        .where((f) => f.nombre.isNotEmpty)
        .toList();
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
