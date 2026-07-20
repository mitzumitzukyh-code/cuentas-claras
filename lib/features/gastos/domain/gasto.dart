import 'package:cloud_firestore/cloud_firestore.dart';

/// Categoría de un gasto (CLAUDE.md pantalla 9).
enum CategoriaGasto {
  mercancia,
  transporte,
  servicios,
  otro;

  /// ID persistido en Firestore (y el que devuelve el OCR del recibo).
  String get id => name;

  static CategoriaGasto fromId(String? id) => CategoriaGasto.values.firstWhere(
        (c) => c.id == id,
        orElse: () => CategoriaGasto.otro,
      );

  String get etiqueta => switch (this) {
        CategoriaGasto.mercancia => '📦 Mercancía',
        CategoriaGasto.transporte => '🚚 Transporte',
        CategoriaGasto.servicios => '💡 Servicios',
        CategoriaGasto.otro => '🧾 Otro',
      };

  /// Subcategorías sugeridas (brief: Transporte y Servicios las tienen).
  List<String> get subcategorias => switch (this) {
        CategoriaGasto.transporte => const ['Flete', 'Gasolina', 'Encomienda'],
        CategoriaGasto.servicios => const [
            'Luz',
            'Agua',
            'Internet',
            'Teléfono',
            'Alquiler',
            'Gas',
          ],
        _ => const [],
      };
}

/// Un gasto del negocio (CLAUDE.md §4: `negocios/{id}/gastos/{id}`).
///
/// Información financiera: solo el dueño los ve y los registra — las reglas
/// de Firestore lo exigen además de la UI.
class Gasto {
  const Gasto({
    required this.id,
    required this.categoria,
    this.subcategoria,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    this.fotoReciboUrl,
  });

  final String id;
  final CategoriaGasto categoria;
  final String? subcategoria;
  final String descripcion;

  /// Monto en USD (los precios de la app se manejan en USD, CLAUDE.md §6).
  final double monto;
  final DateTime fecha;
  final String? fotoReciboUrl;

  /// "Transporte · Flete" o solo "Transporte".
  String get categoriaLabel {
    final base = categoria.etiqueta;
    return subcategoria == null || subcategoria!.isEmpty
        ? base
        : '$base · $subcategoria';
  }

  factory Gasto.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Gasto(
      id: doc.id,
      categoria: CategoriaGasto.fromId(data['categoria'] as String?),
      subcategoria: data['subcategoria'] as String?,
      descripcion: (data['descripcion'] as String?) ?? '',
      monto: (data['monto'] as num?)?.toDouble() ?? 0,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fotoReciboUrl: data['fotoReciboUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'categoria': categoria.id,
        'subcategoria': subcategoria,
        'descripcion': descripcion,
        'monto': monto,
        'fecha': Timestamp.fromDate(fecha),
        'fotoReciboUrl': fotoReciboUrl,
      };
}
