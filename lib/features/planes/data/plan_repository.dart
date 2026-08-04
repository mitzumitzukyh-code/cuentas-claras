import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/plan.dart';

/// Lee el plan de un usuario desde `suscripciones/{usuarioId}`.
///
/// **Nadie escribe aquí desde el cliente, a propósito.** Marcar Premium con una
/// escritura de la app sería falsificable por cualquiera con el teléfono en la
/// mano: el día que se conecte la compra, quien escriba este documento es una
/// Cloud Function que verifica el recibo contra Google Play, y las reglas de
/// Firestore dejan este documento en solo lectura para el usuario. Mientras
/// tanto la colección está vacía y todo el mundo es [Plan.gratis], que es
/// exactamente lo que la app hacía antes de existir esta capa.
class PlanRepository {
  const PlanRepository(this._db);

  final FirebaseFirestore _db;

  /// El plan del usuario. Sin documento, [Plan.gratis].
  Stream<Plan> planDe(String usuarioId) {
    // Ni siquiera se consulta Firestore: así el interruptor de pruebas
    // funciona aunque las reglas de `suscripciones` todavía no estén
    // desplegadas, que es justo el caso en que hace falta.
    if (premiumForzado) return Stream.value(Plan.premium);

    return _db.collection('suscripciones').doc(usuarioId).snapshots().map((d) {
      if (!d.exists) return Plan.gratis;
      final datos = d.data();
      final vence = (datos?['vence'] as Timestamp?)?.toDate();
      // Una suscripción vencida es gratis. Sin fecha se entiende vigente: los
      // planes de Play renuevan solos y la función que los verifica es quien
      // pone la fecha cuando corresponde.
      if (vence != null && vence.isBefore(DateTime.now())) return Plan.gratis;
      return Plan.fromId(datos?['plan'] as String?);
    });
  }
}

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(firestoreProvider));
});

/// El plan del usuario que tiene la sesión abierta.
///
/// Es el que manda sobre **cuántos negocios** puede tener: ese tope es suyo,
/// no de ningún negocio en concreto.
final miPlanProvider = StreamProvider<Plan>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(Plan.gratis);
  return ref.watch(planRepositoryProvider).planDe(user.uid);
});

/// El plan que rige dentro del negocio activo: el de su dueño.
///
/// Un empleado no paga y aun así trabaja sin marca de agua si el dueño es
/// Premium — el negocio hereda lo que tenga quien lo creó. Manda sobre los
/// topes de productos y de empleados, y sobre la marca de agua.
///
/// Nunca es `null` ni lanza: mientras carga, o si el negocio no dice quién lo
/// creó, cae en [Plan.gratis]. Un plan que no consta es un plan que no se
/// pagó.
final planDelNegocioProvider = Provider<Plan>((ref) {
  final negocio = ref.watch(negocioActivoProvider).valueOrNull;
  final dueno = negocio?.creadoPor;
  if (dueno == null) return Plan.gratis;

  // Si el dueño es quien está mirando, se reaprovecha su propio stream en vez
  // de abrir un segundo listener sobre el mismo documento.
  final yo = ref.watch(authStateProvider).valueOrNull;
  if (yo != null && yo.uid == dueno) {
    return ref.watch(miPlanProvider).valueOrNull ?? Plan.gratis;
  }
  return ref.watch(planDeUsuarioProvider(dueno)).valueOrNull ?? Plan.gratis;
});

/// El plan de un usuario cualquiera por id — lo usa [planDelNegocioProvider]
/// para leer el del dueño cuando quien mira es un empleado.
final planDeUsuarioProvider =
    StreamProvider.family<Plan, String>((ref, usuarioId) {
  return ref.watch(planRepositoryProvider).planDe(usuarioId);
});
