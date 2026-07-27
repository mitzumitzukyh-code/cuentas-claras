import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/cierre_caja.dart';

/// Repositorio de cierres de caja (`Lote H`).
class CierreCajaRepository {
  CierreCajaRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String negocioId) => _db
      .collection(FirestorePaths.negocios)
      .doc(negocioId)
      .collection(FirestorePaths.cierres);

  /// `null` si el día todavía no se cerró.
  Stream<CierreCaja?> cierreDe(String negocioId, DateTime fecha) {
    return _col(negocioId)
        .doc(CierreCaja.idDe(fecha))
        .snapshots()
        .map((s) => s.exists ? CierreCaja.fromDoc(s) : null);
  }

  /// Falla si el día ya tenía un cierre: un cierre registrado no se debe
  /// poder pisar con un segundo arqueo. El SDK de Flutter no tiene un
  /// `create()` atómico como el de otras plataformas, así que se simula con
  /// una transacción que primero comprueba que el documento no exista.
  Future<void> crearCierre(String negocioId, CierreCaja cierre) {
    final ref = _col(negocioId).doc(cierre.id);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw Exception('La caja de hoy ya estaba cerrada.');
      }
      tx.set(ref, cierre.toMap());
    });
  }
}

// --- Providers ---

final cierreCajaRepositoryProvider = Provider<CierreCajaRepository>((ref) {
  return CierreCajaRepository(ref.watch(firestoreProvider));
});

/// Cierre de hoy, si ya se hizo.
final cierreDeHoyProvider = StreamProvider<CierreCaja?>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(null);
  return ref
      .watch(cierreCajaRepositoryProvider)
      .cierreDe(membresia.negocioId, DateTime.now());
});
