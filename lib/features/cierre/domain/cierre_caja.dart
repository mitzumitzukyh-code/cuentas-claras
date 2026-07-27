import 'package:cloud_firestore/cloud_firestore.dart';

/// Cierre de caja de un día (`Lote H · Cierre y Proveedores`).
///
/// El ID del documento es la fecha en formato `yyyy-MM-dd`: como máximo un
/// cierre por día, y `crearCierre` lo escribe con `create()` (no `set()`)
/// para que un segundo intento de cerrar el mismo día falle en vez de
/// sobrescribir el arqueo ya guardado.
class CierreCaja {
  const CierreCaja({
    required this.id,
    required this.ventasUSD,
    required this.gastosUSD,
    required this.fiadoOtorgadoUSD,
    required this.abonosUSD,
    required this.metodosEsperados,
    required this.efectivoEsperado,
    required this.efectivoContado,
    required this.cerradoPor,
    required this.cerradaEn,
  });

  final String id;
  final double ventasUSD;
  final double gastosUSD;
  final double fiadoOtorgadoUSD;
  final double abonosUSD;

  /// Total esperado por método de pago (id de `MetodoPago` → monto USD).
  final Map<String, double> metodosEsperados;

  final double efectivoEsperado;
  final double efectivoContado;
  final String cerradoPor;
  final DateTime cerradaEn;

  double get descuadreUSD => efectivoContado - efectivoEsperado;

  /// Neto en caja: lo que de verdad quedó a favor del negocio hoy.
  double get netoUSD => ventasUSD - gastosUSD - fiadoOtorgadoUSD + abonosUSD;

  factory CierreCaja.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final metodos = (data['metodosEsperados'] as Map?) ?? const {};
    return CierreCaja(
      id: doc.id,
      ventasUSD: (data['ventasUSD'] as num?)?.toDouble() ?? 0,
      gastosUSD: (data['gastosUSD'] as num?)?.toDouble() ?? 0,
      fiadoOtorgadoUSD: (data['fiadoOtorgadoUSD'] as num?)?.toDouble() ?? 0,
      abonosUSD: (data['abonosUSD'] as num?)?.toDouble() ?? 0,
      metodosEsperados: {
        for (final e in metodos.entries)
          e.key.toString(): (e.value as num?)?.toDouble() ?? 0,
      },
      efectivoEsperado: (data['efectivoEsperado'] as num?)?.toDouble() ?? 0,
      efectivoContado: (data['efectivoContado'] as num?)?.toDouble() ?? 0,
      cerradoPor: (data['cerradoPor'] as String?) ?? '',
      cerradaEn: (data['cerradaEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ventasUSD': ventasUSD,
        'gastosUSD': gastosUSD,
        'fiadoOtorgadoUSD': fiadoOtorgadoUSD,
        'abonosUSD': abonosUSD,
        'metodosEsperados': metodosEsperados,
        'efectivoEsperado': efectivoEsperado,
        'efectivoContado': efectivoContado,
        'cerradoPor': cerradoPor,
        'cerradaEn': Timestamp.fromDate(cerradaEn),
      };

  /// ID de documento para el día de [fecha]: `yyyy-MM-dd`.
  static String idDe(DateTime fecha) {
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '${fecha.year}-$m-$d';
  }
}
