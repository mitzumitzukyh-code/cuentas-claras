import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import 'negocio_repository.dart';

/// Un cambio que alguien hizo en el negocio (`Lote E · P3`).
class EventoAuditoria {
  const EventoAuditoria({
    required this.id,
    required this.accion,
    required this.detalle,
    required this.autorNombre,
    required this.fecha,
  });

  /// Verbo corto: "anuló una venta", "cambió un precio", "cerró la caja".
  final String accion;

  /// Qué se tocó, en palabras del dueño: "Venta #1042 · $5,00".
  final String detalle;

  final String id;
  final String autorNombre;
  final DateTime fecha;

  factory EventoAuditoria.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    return EventoAuditoria(
      id: doc.id,
      accion: (d['accion'] as String?) ?? '',
      detalle: (d['detalle'] as String?) ?? '',
      autorNombre: (d['autorNombre'] as String?) ?? 'Alguien',
      fecha: (d['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'accion': accion,
        'detalle': detalle,
        'autorNombre': autorNombre,
        'fecha': Timestamp.fromDate(fecha),
      };
}

/// Registro de quién hizo qué.
///
/// Solo se anota lo que puede generar una discusión después: anular una venta,
/// cambiar un precio, cerrar la caja, tocar el inventario a mano. Registrar
/// cada lectura convertiría esto en ruido y en factura de Firestore.
class AuditoriaRepository {
  const AuditoriaRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String negocioId) => _db
      .collection(FirestorePaths.negocios)
      .doc(negocioId)
      .collection(FirestorePaths.auditoria);

  Stream<List<EventoAuditoria>> eventos(String negocioId, {int limite = 100}) {
    return _col(negocioId)
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((s) => s.docs.map(EventoAuditoria.fromDoc).toList());
  }

  /// Anota un evento. No se espera a que confirme el servidor: el registro es
  /// para leerlo después, y bloquear la acción del dueño por esperar a que se
  /// escriba su bitácora sería el peor intercambio posible.
  void anotar(
    String negocioId, {
    required String accion,
    required String detalle,
    required String autorNombre,
  }) {
    _col(negocioId).add(
      EventoAuditoria(
        id: '',
        accion: accion,
        detalle: detalle,
        autorNombre: autorNombre,
        fecha: DateTime.now(),
      ).toMap(),
    );
  }
}

final auditoriaRepositoryProvider = Provider<AuditoriaRepository>((ref) {
  return AuditoriaRepository(ref.watch(firestoreProvider));
});

final auditoriaProvider = StreamProvider<List<EventoAuditoria>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(auditoriaRepositoryProvider).eventos(membresia.negocioId);
});
