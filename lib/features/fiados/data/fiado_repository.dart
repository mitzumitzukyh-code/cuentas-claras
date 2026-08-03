import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/cliente_fiado.dart';

/// Repositorio de fiados (CLAUDE.md §4, ampliado en `Lote G`).
///
/// `saldoUSD` se guarda denormalizado en el documento del cliente y se
/// actualiza con `FieldValue.increment` en el mismo batch que crea el
/// movimiento: es una operación relativa, así que funciona igual con o sin
/// señal (Firestore la aplica localmente y la sincroniza sola), sin la
/// complejidad de doble camino que sí necesita `VentaRepository` (ahí el
/// stock exige una lectura en tiempo real para no vender de más).
class FiadoRepository {
  FiadoRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _negocioRef(String negocioId) =>
      _db.collection(FirestorePaths.negocios).doc(negocioId);

  CollectionReference<Map<String, dynamic>> _clientes(String negocioId) =>
      _negocioRef(negocioId).collection(FirestorePaths.clientes);

  CollectionReference<Map<String, dynamic>> _movimientos(
    String negocioId,
    String clienteId,
  ) =>
      _clientes(negocioId).doc(clienteId).collection(FirestorePaths.movimientos);

  /// Clientes con cuenta de fiado, más deuda primero.
  Stream<List<ClienteFiado>> clientes(String negocioId) {
    return _clientes(negocioId)
        .orderBy('saldoUSD', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ClienteFiado.fromDoc).toList());
  }

  Stream<List<MovimientoFiado>> movimientos(String negocioId, String clienteId) {
    return _movimientos(negocioId, clienteId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(MovimientoFiado.fromDoc).toList());
  }

  /// Crea el cliente si no existe (por nombre) y devuelve su ID.
  Future<String> buscarOCrearCliente(
    String negocioId, {
    required String nombre,
    String? telefono,
  }) async {
    final existente = await _clientes(negocioId)
        .where('nombre', isEqualTo: nombre.trim())
        .limit(1)
        .get();
    if (existente.docs.isNotEmpty) return existente.docs.first.id;

    final ref = _clientes(negocioId).doc();
    await ref.set(
      ClienteFiado(
        id: ref.id,
        nombre: nombre.trim(),
        telefono: telefono,
        saldoUSD: 0,
        actualizadoEn: DateTime.now(),
      ).toMap(),
    );
    return ref.id;
  }

  /// Registra un fiado (+saldo) o un abono (−saldo) y actualiza el saldo del
  /// cliente en el mismo batch.
  Future<void> registrarMovimiento(
    String negocioId,
    String clienteId, {
    required TipoMovimientoFiado tipo,
    required double montoUSD,
    required String concepto,
    required String registradoPor,
  }) async {
    final batch = _db.batch();
    final movRef = _movimientos(negocioId, clienteId).doc();
    batch.set(
      movRef,
      MovimientoFiado(
        id: movRef.id,
        tipo: tipo,
        montoUSD: montoUSD,
        concepto: concepto,
        fecha: DateTime.now(),
        registradoPor: registradoPor,
        negocioId: negocioId,
      ).toMap(),
    );

    final delta = tipo == TipoMovimientoFiado.fiado ? montoUSD : -montoUSD;
    batch.update(_clientes(negocioId).doc(clienteId), {
      'saldoUSD': FieldValue.increment(delta),
      'actualizadoEn': Timestamp.fromDate(DateTime.now()),
    });

    await batch.commit();
  }

  /// Todos los movimientos de fiado del negocio desde [desde] (para el
  /// Resumen del día en Cierre de caja, Lote H). `collectionGroup` cruza las
  /// subcolecciones de todos los clientes; se filtra por `negocioId`
  /// denormalizado porque una consulta no puede filtrar por la ruta del
  /// ancestro.
  Stream<List<MovimientoFiado>> movimientosDelNegocioDesde(
    String negocioId,
    DateTime desde,
  ) {
    return _db
        .collectionGroup(FirestorePaths.movimientos)
        .where('negocioId', isEqualTo: negocioId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .snapshots()
        .map((s) => s.docs.map(MovimientoFiado.fromDoc).toList());
  }
}

// --- Providers ---

final fiadoRepositoryProvider = Provider<FiadoRepository>((ref) {
  return FiadoRepository(ref.watch(firestoreProvider));
});

final clientesFiadoProvider = StreamProvider<List<ClienteFiado>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(fiadoRepositoryProvider).clientes(membresia.negocioId);
});

/// El cliente vivo, por id.
///
/// La pantalla de detalle llega con un [ClienteFiado] en el `extra` de la ruta:
/// un objeto congelado en el instante de navegar. Al anotar un abono, la lista
/// de movimientos —que sí es un stream— se actualizaba y el saldo del
/// encabezado no, así que el cliente veía "+$12,00", "−$1,00" y un saldo
/// pendiente de $12,00.
///
/// Se sirve del stream de la lista, que ya está abierto, en vez de montar un
/// segundo listener sobre el mismo documento. Devuelve `null` mientras la lista
/// carga o si el cliente ya no está; quien llama se queda con el del `extra`.
final clienteFiadoPorIdProvider =
    Provider.family<ClienteFiado?, String>((ref, clienteId) {
  final lista = ref.watch(clientesFiadoProvider).valueOrNull;
  if (lista == null) return null;
  for (final c in lista) {
    if (c.id == clienteId) return c;
  }
  return null;
});

/// Movimientos de un cliente puntual (pantalla de detalle).
final movimientosClienteProvider =
    StreamProvider.family<List<MovimientoFiado>, String>((ref, clienteId) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref
      .watch(fiadoRepositoryProvider)
      .movimientos(membresia.negocioId, clienteId);
});

/// Fiados otorgados y abonos recibidos hoy, en todo el negocio (Resumen del
/// día — Lote H).
final movimientosFiadoHoyProvider = StreamProvider<List<MovimientoFiado>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  final ahora = DateTime.now();
  final inicio = DateTime(ahora.year, ahora.month, ahora.day);
  return ref
      .watch(fiadoRepositoryProvider)
      .movimientosDelNegocioDesde(membresia.negocioId, inicio);
});
