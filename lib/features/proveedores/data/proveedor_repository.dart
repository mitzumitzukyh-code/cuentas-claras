import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/proveedor.dart';

/// Repositorio de proveedores / cuentas por pagar (`Lote H`).
///
/// Mismo patrón que `FiadoRepository`: `saldoUSD` denormalizado, ajustado con
/// `FieldValue.increment` en el mismo batch que crea el movimiento.
class ProveedorRepository {
  ProveedorRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _negocioRef(String negocioId) =>
      _db.collection(FirestorePaths.negocios).doc(negocioId);

  CollectionReference<Map<String, dynamic>> _proveedores(String negocioId) =>
      _negocioRef(negocioId).collection(FirestorePaths.proveedores);

  CollectionReference<Map<String, dynamic>> _movimientos(
    String negocioId,
    String proveedorId,
  ) =>
      _proveedores(negocioId).doc(proveedorId).collection(FirestorePaths.movimientos);

  /// Proveedores con deuda primero.
  Stream<List<Proveedor>> proveedores(String negocioId) {
    return _proveedores(negocioId)
        .orderBy('saldoUSD', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Proveedor.fromDoc).toList());
  }

  Stream<List<MovimientoProveedor>> movimientos(
    String negocioId,
    String proveedorId,
  ) {
    return _movimientos(negocioId, proveedorId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(MovimientoProveedor.fromDoc).toList());
  }

  Future<String> buscarOCrearProveedor(
    String negocioId, {
    required String nombre,
  }) async {
    final existente = await _proveedores(negocioId)
        .where('nombre', isEqualTo: nombre.trim())
        .limit(1)
        .get();
    if (existente.docs.isNotEmpty) return existente.docs.first.id;

    final ref = _proveedores(negocioId).doc();
    await ref.set(
      Proveedor(
        id: ref.id,
        nombre: nombre.trim(),
        saldoUSD: 0,
        actualizadoEn: DateTime.now(),
      ).toMap(),
    );
    return ref.id;
  }

  /// Registra una compra a crédito (+saldo) o un pago (−saldo).
  Future<void> registrarMovimiento(
    String negocioId,
    String proveedorId, {
    required TipoMovimientoProveedor tipo,
    required double montoUSD,
    required String concepto,
    required String registradoPor,
    DateTime? vencimiento,
  }) async {
    final batch = _db.batch();
    final movRef = _movimientos(negocioId, proveedorId).doc();
    batch.set(
      movRef,
      MovimientoProveedor(
        id: movRef.id,
        tipo: tipo,
        montoUSD: montoUSD,
        concepto: concepto,
        fecha: DateTime.now(),
        registradoPor: registradoPor,
        vencimiento: vencimiento,
      ).toMap(),
    );

    final delta = tipo == TipoMovimientoProveedor.compra ? montoUSD : -montoUSD;
    final cambiosProveedor = <String, dynamic>{
      'saldoUSD': FieldValue.increment(delta),
      'actualizadoEn': Timestamp.fromDate(DateTime.now()),
    };
    if (tipo == TipoMovimientoProveedor.compra && vencimiento != null) {
      cambiosProveedor['proximoVencimiento'] = Timestamp.fromDate(vencimiento);
    }
    batch.update(_proveedores(negocioId).doc(proveedorId), cambiosProveedor);

    await batch.commit();
  }
}

// --- Providers ---

final proveedorRepositoryProvider = Provider<ProveedorRepository>((ref) {
  return ProveedorRepository(ref.watch(firestoreProvider));
});

final proveedoresProvider = StreamProvider<List<Proveedor>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(proveedorRepositoryProvider).proveedores(membresia.negocioId);
});

final movimientosProveedorProvider =
    StreamProvider.family<List<MovimientoProveedor>, String>((ref, proveedorId) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref
      .watch(proveedorRepositoryProvider)
      .movimientos(membresia.negocioId, proveedorId);
});
