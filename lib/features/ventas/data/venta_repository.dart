import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/venta.dart';

/// Resultado de registrar una venta: para que la UI diga "registrada" o
/// "guardada, se sube sola" según corresponda, en vez de un mensaje genérico.
enum ResultadoVenta {
  /// Se confirmó con el servidor en el momento (hay señal).
  confirmada,

  /// Se guardó en el teléfono; Firestore la sincroniza sola con el servidor
  /// en cuanto detecte conexión, sin que la app tenga que hacer nada más.
  pendienteDeSincronizar,
}

/// Repositorio de ventas (CLAUDE.md §4, §6).
class VentaRepository {
  VentaRepository(this._db, {Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final FirebaseFirestore _db;
  final Connectivity _connectivity;

  DocumentReference<Map<String, dynamic>> _negocioRef(String negocioId) =>
      _db.collection(FirestorePaths.negocios).doc(negocioId);

  CollectionReference<Map<String, dynamic>> _ventas(String negocioId) =>
      _negocioRef(negocioId).collection(FirestorePaths.ventas);

  CollectionReference<Map<String, dynamic>> _productos(String negocioId) =>
      _negocioRef(negocioId).collection(FirestorePaths.productos);

  /// Registra una venta y descuenta el stock de cada producto.
  ///
  /// Decide el camino ANTES de intentar nada, no compitiendo un timeout
  /// contra la transacción: las transacciones de Firestore no se pueden
  /// cancelar de verdad una vez lanzadas, así que si se dejara correr una en
  /// segundo plano mientras la app sigue con un plan B, ambas podrían acabar
  /// aplicándose — la misma venta duplicada y el stock descontado dos veces
  /// en cuanto regrese la señal. Preguntar primero evita ese escenario.
  Future<ResultadoVenta> registrarVenta(String negocioId, Venta venta) async {
    final estado = await _connectivity.checkConnectivity();
    final sinSenal = estado.isEmpty || estado.every(
      (r) => r == ConnectivityResult.none,
    );

    if (sinSenal) {
      await _registrarSinConexion(negocioId, venta);
      return ResultadoVenta.pendienteDeSincronizar;
    }

    await _registrarConTransaccion(negocioId, venta);
    return ResultadoVenta.confirmada;
  }

  /// Camino normal: todo o nada, y bloquea si no queda stock. Requiere hablar
  /// con el servidor porque solo él conoce el valor verdadero y simultáneo
  /// entre todos los vendedores del negocio.
  Future<void> _registrarConTransaccion(String negocioId, Venta venta) {
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

  /// Camino sin señal: se guarda en el dispositivo y Firestore la encola y
  /// sincroniza sola, sin que la app tenga que hacer seguimiento.
  ///
  /// No hay chequeo de stock: verificarlo con certeza exige preguntarle al
  /// servidor, y por definición no hay nadie a quien preguntarle sin señal.
  /// El descuento usa `FieldValue.increment`, una operación relativa y no una
  /// sobrescritura: si dos vendedores sin señal descuentan el mismo producto
  /// a la vez, el servidor suma ambos decrementos al sincronizar en vez de
  /// que uno borre el efecto del otro. Lo único que no se puede garantizar
  /// offline es que el stock no termine en negativo — el mismo límite que
  /// tiene cualquier punto de venta físico sin conexión.
  Future<void> _registrarSinConexion(String negocioId, Venta venta) async {
    final batch = _db.batch();
    for (final item in venta.items) {
      batch.update(_productos(negocioId).doc(item.productoId), {
        'cantidad': FieldValue.increment(-item.cantidad),
      });
    }
    batch.set(_ventas(negocioId).doc(), venta.toMap());

    // No se espera a `commit()`. Verificado en un dispositivo real: sin señal,
    // ese Future NO resuelve hasta que hay conexión de verdad —igual que una
    // transacción—, así que esperarlo aquí reproduciría exactamente el cuelgue
    // que este código existe para evitar. `batch.update`/`batch.set` ya
    // aplicaron el cambio a la copia local en cuanto se llamaron: es lo que
    // hace que el dashboard y el historial se actualicen al instante. Dejar
    // `commit()` corriendo en segundo plano no cambia eso; solo se registra
    // si termina en un error real (no simplemente "sigue sin señal").
    unawaited(
      batch.commit().catchError((Object e) {
        debugPrint('[venta] fallo al sincronizar en segundo plano: $e');
      }),
    );
  }

  /// Historial completo, más reciente primero. Incluye las anuladas: el diseño
  /// las muestra tachadas, nunca las oculta.
  ///
  /// `includeMetadataChanges` hace que, cuando el servidor por fin confirma
  /// una venta guardada sin señal, llegue un nuevo snapshot solo por eso —sin
  /// esto, la insignia de "pendiente" se quedaría pegada hasta que algún otro
  /// cambio de datos disparara una actualización.
  Stream<List<Venta>> historial(String negocioId, {int limite = 200}) {
    return _ventas(negocioId)
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs.map(Venta.fromDoc).toList());
  }

  /// Espera a que Firestore confirme con el servidor todo lo que el
  /// dispositivo tiene pendiente de subir.
  ///
  /// No hace nada que Firestore no vaya a hacer solo tarde o temprano: sirve
  /// para el botón "Sincronizar ahora", que le da al dueño una respuesta
  /// inmediata en vez de dejarlo esperando sin saber si sigue sin señal.
  Future<bool> sincronizarAhora() async {
    try {
      await _db.waitForPendingWrites().timeout(const Duration(seconds: 15));
      return true;
    } catch (_) {
      // Timeout o sigue sin señal: no es un error del que avisar con
      // detalle, el dueño solo necesita saber que todavía no se pudo.
      return false;
    }
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

/// Ventas que siguen solo en el teléfono, sin confirmar con el servidor.
///
/// Se deriva del historial en vez de abrir un listener aparte: no hay forma
/// de pedirle a Firestore "solo las pendientes" —`hasPendingWrites` es un
/// dato local, no un campo del documento—, así que de todos modos hay que
/// traer un rango y filtrar en el cliente. Mejor reutilizar el que ya está
/// abierto que duplicar la lectura.
final ventasPendientesProvider = Provider<List<Venta>>((ref) {
  final historial = ref.watch(historialVentasProvider).valueOrNull ?? const [];
  return historial.where((v) => v.pendiente).toList();
});
