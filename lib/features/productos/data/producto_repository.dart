import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/producto.dart';

/// Repositorio de productos de un negocio (CLAUDE.md §4).
class ProductoRepository {
  ProductoRepository(this._db, this._cloudinary);

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;

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

  Future<void> crear(String negocioId, Producto producto) {
    return _col(negocioId).add(producto.toMap());
  }

  Future<void> actualizar(String negocioId, Producto producto) {
    return _col(negocioId).doc(producto.id).update(producto.toMap());
  }

  Future<void> eliminar(String negocioId, String productoId) {
    return _col(negocioId).doc(productoId).delete();
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
