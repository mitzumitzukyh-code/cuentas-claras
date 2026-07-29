import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/insumo.dart';

/// Repositorio de insumos: la materia prima que las recetas consumen
/// (CLAUDE.md §4: `negocios/{id}/insumos/{id}`).
class InsumoRepository {
  InsumoRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String negocioId) => _db
      .collection(FirestorePaths.negocios)
      .doc(negocioId)
      .collection(FirestorePaths.insumos);

  Stream<List<Insumo>> insumos(String negocioId) => _col(negocioId)
      .orderBy('nombre')
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Insumo.fromDoc).toList());

  Future<void> crear(String negocioId, Insumo insumo) =>
      _col(negocioId).add(insumo.toMap());

  Future<void> actualizar(String negocioId, Insumo insumo) =>
      _col(negocioId).doc(insumo.id).update(insumo.toMap());

  Future<void> eliminar(String negocioId, String insumoId) =>
      _col(negocioId).doc(insumoId).delete();

  /// Suma [delta] a la existencia (negativo para consumir).
  ///
  /// Va con `increment` y no leyendo-escribiendo: dos ventas simultáneas de
  /// dos teléfonos distintos tienen que restar las dos, no pisarse.
  Future<void> ajustar(String negocioId, String insumoId, double delta) =>
      _col(negocioId).doc(insumoId).update({
        'cantidad': FieldValue.increment(delta),
      });
}

// --- Providers ---

final insumoRepositoryProvider = Provider<InsumoRepository>((ref) {
  return InsumoRepository(ref.watch(firestoreProvider));
});

/// Insumos del negocio activo.
final insumosProvider = StreamProvider<List<Insumo>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(insumoRepositoryProvider).insumos(membresia.negocioId);
});
