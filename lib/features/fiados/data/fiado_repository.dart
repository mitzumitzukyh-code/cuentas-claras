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
  ///
  /// El filtro de eliminados va en Dart y no en la consulta: un `where` más
  /// obligaría a un índice compuesto con el `orderBy` por unas decenas de
  /// clientes.
  Stream<List<ClienteFiado>> clientes(String negocioId) {
    return _clientes(negocioId)
        .orderBy('saldoUSD', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map(ClienteFiado.fromDoc).where((c) => !c.eliminado).toList());
  }

  /// Guarda (o cambia) el teléfono de un cliente ya creado.
  ///
  /// Hasta ahora el teléfono solo se podía poner al crear la ficha, y quien no
  /// lo tenía a mano en ese momento se quedaba sin poder mandarle el
  /// recordatorio nunca más: "Recordar" contestaba «no tiene teléfono
  /// guardado» y ahí terminaba el camino. Los clientes que entran desde el
  /// cuaderno de papel nacen todos así, sin número.
  ///
  /// `null` borra el número: alguien puede querer dejar de guardarlo.
  Future<void> actualizarTelefono(
    String negocioId,
    String clienteId,
    String? telefono,
  ) {
    final limpio = telefono?.trim();
    return _clientes(negocioId).doc(clienteId).update({
      'telefono': (limpio == null || limpio.isEmpty) ? null : limpio,
      'actualizadoEn': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Quita al cliente de la lista sin destruir su historial.
  ///
  /// No se borra el documento: sus movimientos son un libro mayor que las
  /// reglas prohíben borrar, y un borrado físico los dejaría huérfanos. Se
  /// marca, y las consultas lo filtran.
  Future<void> eliminarCliente(String negocioId, String clienteId) {
    return _clientes(negocioId).doc(clienteId).update({
      'eliminado': true,
      'eliminadoEn': Timestamp.fromDate(DateTime.now()),
    });
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

  /// Nombres de los clientes que ya existen, en minúscula, apuntando a su id.
  ///
  /// Se lee de una vez para el importador: preguntar cliente por cliente son
  /// tantas idas al servidor como renglones tenga la página del cuaderno.
  Future<Map<String, String>> nombresExistentes(String negocioId) async {
    final snap = await _clientes(negocioId).get();
    return {
      for (final d in snap.docs)
        if (!ClienteFiado.fromDoc(d).eliminado)
          ClienteFiado.fromDoc(d).nombre.toLowerCase().trim(): d.id,
    };
  }

  /// Copia al libro las deudas que el dueño ya tenía anotadas en papel.
  ///
  /// Cada renglón entra como un movimiento de tipo `fiado` marcado
  /// [MovimientoFiado.importado]: la deuda es real y suma al saldo, pero no
  /// cuenta como plata fiada hoy en el Resumen del día.
  ///
  /// Los clientes que ya existen reciben el movimiento en su cuenta —no se
  /// duplica la ficha— y los nuevos se crean en el mismo batch.
  ///
  /// Se trocea en tandas porque un batch de Firestore admite 500 escrituras y
  /// cada renglón gasta hasta tres (crear cliente, crear movimiento, subir el
  /// saldo). Una página de cuaderno no llega ahí, pero una libreta entera
  /// fotografiada por partes sí, y fallar a medias es la peor forma de fallar.
  Future<int> importarDesdeCuaderno(
    String negocioId, {
    required List<({String nombre, double montoUSD, String concepto})> filas,
    required String registradoPor,
  }) async {
    if (filas.isEmpty) return 0;
    final existentes = await nombresExistentes(negocioId);
    final ahora = DateTime.now();

    var batch = _db.batch();
    var escrituras = 0;
    var guardados = 0;

    Future<void> cerrarTanda() async {
      if (escrituras == 0) return;
      await batch.commit();
      batch = _db.batch();
      escrituras = 0;
    }

    for (final fila in filas) {
      final clave = fila.nombre.toLowerCase().trim();
      if (clave.isEmpty || fila.montoUSD <= 0) continue;

      if (escrituras + 3 > 400) await cerrarTanda();

      var clienteId = existentes[clave];
      final clienteRef = clienteId == null
          ? _clientes(negocioId).doc()
          : _clientes(negocioId).doc(clienteId);

      if (clienteId == null) {
        batch.set(
          clienteRef,
          ClienteFiado(
            id: clienteRef.id,
            nombre: fila.nombre.trim(),
            saldoUSD: 0,
            actualizadoEn: ahora,
          ).toMap(),
        );
        escrituras++;
        clienteId = clienteRef.id;
        // Dos renglones del mismo nombre en la misma tanda tienen que caer en
        // la misma ficha; si no, el cuaderno crea clientes gemelos.
        existentes[clave] = clienteId;
      }

      final movRef = _movimientos(negocioId, clienteId).doc();
      batch.set(
        movRef,
        MovimientoFiado(
          id: movRef.id,
          tipo: TipoMovimientoFiado.fiado,
          montoUSD: fila.montoUSD,
          concepto: fila.concepto,
          fecha: ahora,
          registradoPor: registradoPor,
          negocioId: negocioId,
          importado: true,
        ).toMap(),
      );
      batch.update(clienteRef, {
        'saldoUSD': FieldValue.increment(fila.montoUSD),
        'actualizadoEn': Timestamp.fromDate(ahora),
      });
      escrituras += 2;
      guardados++;
    }

    await cerrarTanda();
    return guardados;
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
      .movimientosDelNegocioDesde(membresia.negocioId, inicio)
      // Lo copiado del cuaderno de papel se queda fuera del día: son deudas
      // viejas que hoy solo se anotaron. Contarlas como fiado otorgado hoy
      // descuadraba el arqueo por plata que nunca salió de la caja. El filtro
      // va en Dart —igual que el de eliminados— para no pedir otro índice
      // compuesto por un puñado de documentos.
      .map((ms) => ms.where((m) => !m.importado).toList());
});
