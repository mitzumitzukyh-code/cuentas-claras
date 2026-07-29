import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../negocio/data/negocio_repository.dart';

/// Lo que el negocio lleva acumulado desde que empezó a usar la app.
class BalanceAcumulado {
  const BalanceAcumulado({
    required this.ventasUSD,
    required this.gastosUSD,
    required this.numeroVentas,
    required this.desde,
  });

  final double ventasUSD;
  final double gastosUSD;
  final int numeroVentas;

  /// Fecha de la primera venta registrada. `null` si todavía no hay ninguna.
  final DateTime? desde;

  double get balanceUSD => ventasUSD - gastosUSD;

  bool get vacio => numeroVentas == 0 && gastosUSD == 0;
}

/// Balance histórico completo (Lote N · F7).
///
/// Usa las agregaciones del servidor (`sum`/`count`) en vez de traerse todas
/// las ventas: el total de un negocio con dos años de historia son miles de
/// documentos, y aquí solo se necesitan tres números. El servidor los calcula
/// y manda el resultado, no los datos.
///
/// Nota: las agregaciones no leen la caché, así que sin señal esto no
/// resuelve — por eso la UI lo trata como opcional y no bloquea la pantalla.
final balanceAcumuladoProvider = FutureProvider<BalanceAcumulado>((ref) async {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) {
    return const BalanceAcumulado(
      ventasUSD: 0,
      gastosUSD: 0,
      numeroVentas: 0,
      desde: null,
    );
  }

  final db = ref.watch(firestoreProvider);
  final negocio = db.collection(FirestorePaths.negocios).doc(membresia.negocioId);

  // Las anuladas no cuentan: nunca fueron plata que entró.
  final ventas = negocio
      .collection(FirestorePaths.ventas)
      .where('anulada', isEqualTo: false);

  final resumenVentas =
      await ventas.aggregate(sum('totalUSD'), count()).get();
  final resumenGastos = await negocio
      .collection(FirestorePaths.gastos)
      .aggregate(sum('monto'))
      .get();

  // La fecha de arranque sí necesita un documento real, pero es uno solo.
  final primera =
      await ventas.orderBy('fecha').limit(1).get();

  return BalanceAcumulado(
    ventasUSD: resumenVentas.getSum('totalUSD') ?? 0,
    gastosUSD: resumenGastos.getSum('monto') ?? 0,
    numeroVentas: resumenVentas.count ?? 0,
    desde: primera.docs.isEmpty
        ? null
        : (primera.docs.first.data()['fecha'] as Timestamp?)?.toDate(),
  );
});
