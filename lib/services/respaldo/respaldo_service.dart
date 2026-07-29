import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/firestore_paths.dart';
import '../../core/providers/firebase_providers.dart';

/// Exporta el negocio completo a un `.zip` de CSV (`Lote E · P3`).
///
/// CSV y no un formato propio: el dueño se lo manda al contador, que lo abre
/// en Excel sin instalar nada. Un respaldo que solo esta app puede leer no es
/// un respaldo — es un rehén.
class RespaldoService {
  const RespaldoService(this._db);

  final FirebaseFirestore _db;

  /// Comillas dobles y saltos de línea rompen un CSV si se escriben crudos.
  static String _celda(Object? valor) {
    final texto = (valor ?? '').toString();
    if (!texto.contains(RegExp(r'[",\n\r;]'))) return texto;
    return '"${texto.replaceAll('"', '""')}"';
  }

  static String _fecha(Object? valor) {
    if (valor is Timestamp) return valor.toDate().toIso8601String();
    return _celda(valor);
  }

  static String _csv(List<String> encabezados, List<List<Object?>> filas) {
    final buffer = StringBuffer()..writeln(encabezados.join(','));
    for (final fila in filas) {
      buffer.writeln(fila.map(_celda).join(','));
    }
    return buffer.toString();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _todos(
    String negocioId,
    String coleccion,
  ) async {
    final snap = await _db
        .collection(FirestorePaths.negocios)
        .doc(negocioId)
        .collection(coleccion)
        .get();
    return snap.docs;
  }

  /// Genera el zip y devuelve el archivo temporal listo para compartir.
  Future<File> exportarZip(String negocioId, String nombreNegocio) async {
    final archivo = Archive();

    void agregar(String nombre, String contenido) {
      final bytes = contenido.codeUnits;
      archivo.addFile(ArchiveFile(nombre, bytes.length, bytes));
    }

    // --- Ventas: una fila por línea de venta, que es como se analiza ---
    final ventas = await _todos(negocioId, FirestorePaths.ventas);
    final filasVentas = <List<Object?>>[];
    for (final doc in ventas) {
      final d = doc.data();
      final items = (d['items'] as List?) ?? const [];
      for (final item in items.whereType<Map<String, dynamic>>()) {
        filasVentas.add([
          doc.id,
          _fecha(d['fecha']),
          d['anulada'] == true ? 'si' : 'no',
          d['metodoPago'],
          item['nombre'],
          item['cantidad'],
          item['precioUnitario'],
          item['costoUnitario'],
          d['totalUSD'],
          d['totalBs'],
          d['tasaBcvUsada'],
        ]);
      }
    }
    agregar(
      'ventas.csv',
      _csv([
        'venta_id', 'fecha', 'anulada', 'metodo_pago', 'producto',
        'cantidad', 'precio_unitario', 'costo_unitario',
        'total_usd', 'total_bs', 'tasa',
      ], filasVentas),
    );

    // --- Gastos ---
    final gastos = await _todos(negocioId, FirestorePaths.gastos);
    agregar(
      'gastos.csv',
      _csv([
        'gasto_id', 'fecha', 'categoria', 'subcategoria', 'descripcion',
        'monto_usd',
      ], [
        for (final doc in gastos)
          [
            doc.id,
            _fecha(doc.data()['fecha']),
            doc.data()['categoria'],
            doc.data()['subcategoria'],
            doc.data()['descripcion'],
            doc.data()['monto'],
          ],
      ]),
    );

    // --- Productos ---
    final productos = await _todos(negocioId, FirestorePaths.productos);
    agregar(
      'productos.csv',
      _csv([
        'producto_id', 'nombre', 'categoria', 'precio', 'costo', 'cantidad',
        'alerta_en', 'codigo_barras',
      ], [
        for (final doc in productos)
          [
            doc.id,
            doc.data()['nombre'],
            doc.data()['categoria'],
            doc.data()['precio'],
            doc.data()['costo'],
            doc.data()['cantidad'],
            doc.data()['alertaEn'],
            doc.data()['codigoBarras'],
          ],
      ]),
    );

    // --- Clientes y su libro mayor ---
    final clientes = await _todos(negocioId, FirestorePaths.clientes);
    agregar(
      'clientes.csv',
      _csv(['cliente_id', 'nombre', 'telefono', 'saldo_usd'], [
        for (final doc in clientes)
          [
            doc.id,
            doc.data()['nombre'],
            doc.data()['telefono'],
            doc.data()['saldoUSD'],
          ],
      ]),
    );

    final movimientos = <List<Object?>>[];
    for (final cliente in clientes) {
      final movs = await cliente.reference
          .collection(FirestorePaths.movimientos)
          .get();
      for (final m in movs.docs) {
        movimientos.add([
          cliente.data()['nombre'],
          _fecha(m.data()['fecha']),
          m.data()['tipo'],
          m.data()['montoUSD'],
          m.data()['concepto'],
        ]);
      }
    }
    agregar(
      'fiados.csv',
      _csv(['cliente', 'fecha', 'tipo', 'monto_usd', 'concepto'], movimientos),
    );

    agregar(
      'LEEME.txt',
      'Respaldo de $nombreNegocio\n'
      'Generado por Cuenta Clara el ${DateTime.now()}\n\n'
      'Los archivos son CSV separados por coma, en UTF-8. Se abren con\n'
      'Excel, Google Sheets o cualquier hoja de cálculo.\n\n'
      'ventas.csv lleva una fila por producto vendido, no por venta: así se\n'
      'puede sumar por producto sin tener que separar nada a mano.\n',
    );

    final bytes = ZipEncoder().encode(archivo) ?? const <int>[];
    final dir = await getTemporaryDirectory();
    final fecha = DateTime.now();
    final nombre = 'respaldo_'
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}.zip';
    final destino = File('${dir.path}/$nombre');
    await destino.writeAsBytes(bytes);
    return destino;
  }
}

final respaldoServiceProvider = Provider<RespaldoService>((ref) {
  return RespaldoService(ref.watch(firestoreProvider));
});
