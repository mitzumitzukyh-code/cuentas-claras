import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/conectividad_provider.dart';
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

  Stream<List<Producto>> productos(String negocioId, {int limite = 300}) {
    return _col(negocioId)
        .orderBy('nombre')
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map(Producto.fromDoc).toList());
  }

  /// Solo productos con `alertaEn` configurado, para el banner de stock bajo
  /// del Dashboard — evita leer el inventario completo solo para contar.
  Stream<List<Producto>> productosConAlerta(String negocioId) {
    return _col(negocioId)
        .where('alertaEn', isGreaterThan: 0)
        .orderBy('nombre')
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map(Producto.fromDoc).toList());
  }

  /// Crea el producto. Devuelve `false` si quedó guardado solo en el
  /// teléfono (sin señal): Firestore lo sube solo al volver la conexión.
  Future<bool> crear(String negocioId, Producto producto) async {
    if (await sinSenal()) {
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
    if (await sinSenal()) {
      _enSegundoPlano('actualizar', escritura);
      return false;
    }
    await escritura;
    return true;
  }

  /// Igual que [crear]: `false` = borrado local pendiente de sincronizar.
  Future<bool> eliminar(String negocioId, String productoId) async {
    if (await sinSenal()) {
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

/// Productos del negocio activo (máximo 300).
final productosProvider = StreamProvider<List<Producto>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(productoRepositoryProvider).productos(membresia.negocioId);
});

/// Productos con alerta de stock configurada (máximo 100) — para el banner
/// de stock bajo del Dashboard. No reemplaza a [productosProvider] en las
/// pantallas que necesitan el inventario completo.
final productosConAlertaProvider = StreamProvider<List<Producto>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref
      .watch(productoRepositoryProvider)
      .productosConAlerta(membresia.negocioId);
});
