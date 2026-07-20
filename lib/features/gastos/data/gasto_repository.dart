import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/gasto.dart';

/// Repositorio de gastos de un negocio (CLAUDE.md §4, pantalla 9).
class GastoRepository {
  GastoRepository(this._db, this._cloudinary, {Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;
  final Connectivity _connectivity;

  CollectionReference<Map<String, dynamic>> _col(String negocioId) => _db
      .collection(FirestorePaths.negocios)
      .doc(negocioId)
      .collection(FirestorePaths.gastos);

  /// Mismo criterio que ventas y productos: sin señal el Future de Firestore
  /// no resuelve, así que el camino se decide ANTES de escribir para no
  /// dejar la pantalla colgada "guardando".
  Future<bool> _sinSenal() async {
    final estado = await _connectivity.checkConnectivity();
    return estado.isEmpty ||
        estado.every((r) => r == ConnectivityResult.none);
  }

  /// Registra el gasto. Devuelve `false` si quedó guardado solo en el
  /// teléfono (sin señal): Firestore lo sube solo al volver la conexión.
  Future<bool> crear(String negocioId, Gasto gasto) async {
    if (await _sinSenal()) {
      unawaited(
        _col(negocioId).add(gasto.toMap()).then<void>((_) {}, onError: (Object e) {
          debugPrint('[gasto] fallo al sincronizar (crear): $e');
        }),
      );
      return false;
    }
    await _col(negocioId).add(gasto.toMap());
    return true;
  }

  /// Igual que [crear]: `false` = borrado local pendiente de sincronizar.
  Future<bool> eliminar(String negocioId, String gastoId) async {
    if (await _sinSenal()) {
      unawaited(_col(negocioId).doc(gastoId).delete().catchError((Object e) {
        debugPrint('[gasto] fallo al sincronizar (eliminar): $e');
      }));
      return false;
    }
    await _col(negocioId).doc(gastoId).delete();
    return true;
  }

  /// Gastos desde [desde], más reciente primero. El filtro va en el servidor
  /// por la misma razón que en reportes de ventas: el total del mes debe ser
  /// el total, no una página.
  Stream<List<Gasto>> gastosDesde(String negocioId, DateTime desde) {
    return _col(negocioId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Gasto.fromDoc).toList());
  }

  /// Sube la foto del recibo y devuelve su URL pública (misma vía que las
  /// fotos de producto: Cloudinary, porque Storage exige el plan Blaze).
  Future<String> subirFotoRecibo(String negocioId, File archivo) {
    return _cloudinary.subirImagen(
      archivo,
      carpeta: 'cuenta-clara/$negocioId/recibos',
    );
  }
}

// --- Providers ---

final gastoRepositoryProvider = Provider<GastoRepository>((ref) {
  return GastoRepository(
    ref.watch(firestoreProvider),
    ref.watch(cloudinaryServiceProvider),
  );
});

/// Gastos del mes en curso del negocio activo.
final gastosDelMesProvider = StreamProvider<List<Gasto>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  final ahora = DateTime.now();
  return ref
      .watch(gastoRepositoryProvider)
      .gastosDesde(membresia.negocioId, DateTime(ahora.year, ahora.month));
});
