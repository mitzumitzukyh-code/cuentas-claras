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
import '../domain/producto.dart';

/// Repositorio de productos de un negocio (CLAUDE.md §4).
class ProductoRepository {
  ProductoRepository(this._db, this._cloudinary, {Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;
  final Connectivity _connectivity;

  /// Mismo criterio que `VentaRepository.registrarVenta`: se decide el camino
  /// ANTES de escribir, porque sin señal el Future de Firestore no resuelve
  /// hasta que vuelve la conexión y la pantalla se quedaría colgada
  /// "guardando" para siempre.
  Future<bool> _sinSenal() async {
    final estado = await _connectivity.checkConnectivity();
    return estado.isEmpty ||
        estado.every((r) => r == ConnectivityResult.none);
  }

  CollectionReference<Map<String, dynamic>> _col(String negocioId) => _db
      .collection(FirestorePaths.negocios)
      .doc(negocioId)
      .collection(FirestorePaths.productos);

  Stream<List<Producto>> productos(String negocioId) {
    return _col(negocioId)
        .orderBy('nombre')
        .snapshots()
        .map((s) => s.docs.map(Producto.fromDoc).toList());
  }

  /// Crea el producto. Devuelve `false` si quedó guardado solo en el
  /// teléfono (sin señal): Firestore lo sube solo al volver la conexión.
  Future<bool> crear(String negocioId, Producto producto) async {
    if (await _sinSenal()) {
      _enSegundoPlano('crear', _col(negocioId).add(producto.toMap()));
      return false;
    }
    await _col(negocioId).add(producto.toMap());
    return true;
  }

  /// Igual que [crear]: `false` = guardado local pendiente de sincronizar.
  Future<bool> actualizar(String negocioId, Producto producto) async {
    final escritura =
        _col(negocioId).doc(producto.id).update(producto.toMap());
    if (await _sinSenal()) {
      _enSegundoPlano('actualizar', escritura);
      return false;
    }
    await escritura;
    return true;
  }

  /// Igual que [crear]: `false` = borrado local pendiente de sincronizar.
  Future<bool> eliminar(String negocioId, String productoId) async {
    if (await _sinSenal()) {
      _enSegundoPlano('eliminar', _col(negocioId).doc(productoId).delete());
      return false;
    }
    await _col(negocioId).doc(productoId).delete();
    return true;
  }

  /// La escritura ya se aplicó a la copia local; su Future solo resuelve al
  /// confirmar el servidor, así que se deja correr y únicamente se registra
  /// si termina en un error real.
  void _enSegundoPlano(String accion, Future<void> escritura) {
    unawaited(escritura.catchError((Object e) {
      debugPrint('[producto] fallo al sincronizar ($accion): $e');
    }));
  }

  /// Alta masiva desde el modal de importar. Un solo `batch` para que o entran
  /// todos o no entra ninguno.
  Future<void> crearVarios(String negocioId, List<Producto> productos) {
    final batch = _db.batch();
    for (final p in productos) {
      batch.set(_col(negocioId).doc(), p.toMap());
    }
    return batch.commit();
  }

  /// Sube la foto del producto y devuelve su URL pública.
  ///
  /// Va a Cloudinary, no a Cloud Storage: este último exige el plan Blaze de
  /// Firebase. La URL resultante se guarda igual en `producto.fotoUrl`, así que
  /// el resto de la app no distingue el origen.
  Future<String> subirFoto(String negocioId, File archivo) {
    return _cloudinary.subirImagen(
      archivo,
      carpeta: 'cuenta-clara/$negocioId/productos',
    );
  }
}

// --- Providers ---

final productoRepositoryProvider = Provider<ProductoRepository>((ref) {
  return ProductoRepository(
    ref.watch(firestoreProvider),
    ref.watch(cloudinaryServiceProvider),
  );
});

/// Productos del negocio activo.
final productosProvider = StreamProvider<List<Producto>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(productoRepositoryProvider).productos(membresia.negocioId);
});
