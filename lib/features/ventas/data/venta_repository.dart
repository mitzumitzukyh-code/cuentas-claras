import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/venta.dart';

/// Repositorio de ventas (CLAUDE.md §4, §6).
class VentaRepository {
  VentaRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _negocioRef(String negocioId) =>
      _db.collection(FirestorePaths.negocios).doc(negocioId);

  CollectionReference<Map<String, dynamic>> _ventas(String negocioId) =>
      _negocioRef(negocioId).collection(FirestorePaths.ventas);

  CollectionReference<Map<String, dynamic>> _productos(String negocioId) =>
      _negocioRef(negocioId).collection(FirestorePaths.productos);

  /// Registra una venta y descuenta el stock de cada producto de forma atómica
  /// (una transacción evita vender más de lo disponible).
  Future<void> registrarVenta(String negocioId, Venta venta) {
    return _db.runTransaction((tx) async {
      // Lecturas primero (requisito de las transacciones de Firestore).
      final refs = venta.items
          .map((i) => _productos(negocioId).doc(i.productoId))
          .toList();
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        snaps.add(await tx.get(ref));
      }

      for (var i = 0; i < venta.items.length; i++) {
        final item = venta.items[i];
        final actual = (snaps[i].data()?['cantidad'] as num?)?.toDouble() ?? 0;
        final restante = actual - item.cantidad;
        // Margen mínimo para que la aritmética de coma flotante no bloquee una
        // venta que agota justo el stock (49,5 − 49,5 puede dar −1e-15).
        if (restante < -0.0001) {
          throw Exception('Stock insuficiente para "${item.nombre}".');
        }
        tx.update(refs[i], {'cantidad': restante < 0 ? 0.0 : restante});
      }

      tx.set(_ventas(negocioId).doc(), venta.toMap());
    });
  }

  /// Historial completo, más reciente primero. Incluye las anuladas: el diseño
  /// las muestra tachadas, nunca las oculta.
  Stream<List<Venta>> historial(String negocioId, {int limite = 200}) {
    return _ventas(negocioId)
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map(Venta.fromDoc).toList());
  }

  /// Anula una venta y devuelve el stock al inventario (CLAUDE.md §6).
  ///
  /// La venta nunca se borra: se marca `anulada: true`. Solo el dueño puede
  /// hacerlo — las reglas de Firestore lo exigen además de la UI.
  Future<void> anularVenta(String negocioId, Venta venta) {
    return _db.runTransaction((tx) async {
      final ventaRef = _ventas(negocioId).doc(venta.id);
      final ventaSnap = await tx.get(ventaRef);
      if ((ventaSnap.data()?['anulada'] as bool?) ?? false) {
        throw Exception('Esta venta ya estaba anulada.');
      }

      final refs = venta.items
          .map((i) => _productos(negocioId).doc(i.productoId))
          .toList();
      final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in refs) {
        snaps.add(await tx.get(ref));
      }

      for (var i = 0; i < venta.items.length; i++) {
        // Un producto borrado después de la venta ya no puede recibir stock.
        if (!snaps[i].exists) continue;
        final actual = (snaps[i].data()?['cantidad'] as num?)?.toDouble() ?? 0;
        tx.update(refs[i], {'cantidad': actual + venta.items[i].cantidad});
      }

      tx.update(ventaRef, {'anulada': true});
    });
  }

  /// Ventas del día actual (para el dashboard), excluyendo anuladas.
  Stream<List<Venta>> ventasDelDia(String negocioId) {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day);
    return _ventas(negocioId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .snapshots()
        .map((s) => s.docs
            .map(Venta.fromDoc)
            .where((v) => !v.anulada)
            .toList());
  }
}

// --- Providers ---

final ventaRepositoryProvider = Provider<VentaRepository>((ref) {
  return VentaRepository(ref.watch(firestoreProvider));
});

/// Ventas de hoy del negocio activo.
final ventasDelDiaProvider = StreamProvider<List<Venta>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(ventaRepositoryProvider).ventasDelDia(membresia.negocioId);
});

/// Historial completo del negocio activo (pantalla de Historial).
final historialVentasProvider = StreamProvider<List<Venta>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(ventaRepositoryProvider).historial(membresia.negocioId);
});
