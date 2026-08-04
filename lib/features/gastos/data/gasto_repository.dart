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
import '../domain/gasto.dart';

/// Repositorio de gastos de un negocio (CLAUDE.md §4, pantalla 9).
class GastoRepository {
  GastoRepository(this._db, this._cloudinary);

  final FirebaseFirestore _db;
  final CloudinaryService _cloudinary;

  CollectionReference<Map<String, dynamic>> _col(String negocioId) => _db
      .collection(FirestorePaths.negocios)
      .doc(negocioId)
      .collection(FirestorePaths.gastos);

  /// Registra el gasto. Devuelve `false` si quedó guardado solo en el
  /// teléfono (sin señal): Firestore lo sube solo al volver la conexión.
  Future<bool> crear(String negocioId, Gasto gasto) async {
    if (await sinSenal()) {
      unawaited(
        _col(negocioId).add(gasto.toMap()).then<void>((_) {}, onError: (Object e) {
          debugPrint('[gasto] fallo al sincronizar (crear): $e');
        }),
      );
      return false;
    }
    await _col(negocioId).add(gasto.toMap());
    return true;
  }

  /// Marca el gasto como eliminado. **No lo borra.**
  ///
  /// Los gastos alimentan los reportes: destruir el documento deja un hueco
  /// que nadie puede auditar después. Se marca `eliminado` y las consultas lo
  /// filtran. `false` = quedó pendiente de sincronizar, sin señal.
  Future<bool> eliminar(String negocioId, String gastoId) async {
    final marca = {
      'eliminado': true,
      'eliminadoEn': Timestamp.fromDate(DateTime.now()),
    };
    if (await sinSenal()) {
      unawaited(_col(negocioId).doc(gastoId).update(marca).catchError((Object e) {
        debugPrint('[gasto] fallo al sincronizar (eliminar): $e');
      }));
      return false;
    }
    await _col(negocioId).doc(gastoId).update(marca);
    return true;
  }

  /// Guarda los cambios de un gasto ya registrado.
  ///
  /// Solo los campos que el formulario edita: ni `tasaUsada` ni las marcas de
  /// borrado se tocan al editar — la tasa es la del día en que se registró y
  /// reescribirla al corregir una descripción falsearía el histórico.
  Future<bool> actualizar(String negocioId, Gasto gasto) async {
    final cambios = {
      'categoria': gasto.categoria.id,
      'subcategoria': gasto.subcategoria,
      'descripcion': gasto.descripcion,
      'monto': gasto.monto,
      'fecha': Timestamp.fromDate(gasto.fecha),
      'fotoReciboUrl': gasto.fotoReciboUrl,
    };
    if (await sinSenal()) {
      unawaited(_col(negocioId).doc(gasto.id).update(cambios).catchError((Object e) {
        debugPrint('[gasto] fallo al sincronizar (actualizar): $e');
      }));
      return false;
    }
    await _col(negocioId).doc(gasto.id).update(cambios);
    return true;
  }

  /// Gastos desde [desde], más reciente primero. El filtro va en el servidor
  /// por la misma razón que en reportes de ventas: el total del mes debe ser
  /// el total, no una página.
  Stream<List<Gasto>> gastosDesde(String negocioId, DateTime desde) {
    return _col(negocioId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Gasto.fromDoc).where((g) => !g.eliminado).toList());
  }

  /// Gastos de un mes concreto, más reciente primero.
  ///
  /// El filtro de eliminados va en Dart y no en la consulta a propósito: un
  /// `where` más sobre `eliminado` obligaría a desplegar un índice compuesto
  /// para algo que en un mes son decenas de documentos, no miles.
  Stream<List<Gasto>> gastosDelMes(String negocioId, DateTime mes) {
    final inicio = DateTime(mes.year, mes.month);
    final fin = DateTime(mes.year, mes.month + 1);
    return _col(negocioId)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha', isLessThan: Timestamp.fromDate(fin))
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Gasto.fromDoc).where((g) => !g.eliminado).toList());
  }

  /// Sube la foto del recibo y devuelve su URL pública (misma vía que las
  /// fotos de producto: Cloudinary, porque Storage exige el plan Blaze).
  Future<String> subirFotoRecibo(String negocioId, File archivo) {
    return _cloudinary.subirImagen(
      archivo,
      carpeta: 'cuenta-clara/$negocioId/recibos',
    );
  }
}

// --- Providers ---

final gastoRepositoryProvider = Provider<GastoRepository>((ref) {
  return GastoRepository(
    ref.watch(firestoreProvider),
    ref.watch(cloudinaryServiceProvider),
  );
});

/// Gastos del mes en curso del negocio activo.
final gastosDelMesProvider = StreamProvider<List<Gasto>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  final ahora = DateTime.now();
  return ref
      .watch(gastoRepositoryProvider)
      .gastosDesde(membresia.negocioId, DateTime(ahora.year, ahora.month));
});

/// Qué mes está mirando la pantalla de Gastos. Siempre el día 1, para que dos
/// referencias al mismo mes sean el mismo valor.
final mesGastosProvider = StateProvider<DateTime>((ref) {
  final hoy = DateTime.now();
  return DateTime(hoy.year, hoy.month);
});

/// Gastos del mes que se está mirando (no necesariamente el actual).
final gastosDelMesElegidoProvider = StreamProvider<List<Gasto>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref
      .watch(gastoRepositoryProvider)
      .gastosDelMes(membresia.negocioId, ref.watch(mesGastosProvider));
});

/// Un gasto vivo por id, para que el detalle no pinte una foto congelada
/// después de editarlo (`CLAUDE.md` §8.c).
final gastoPorIdProvider = Provider.family<Gasto?, String>((ref, gastoId) {
  final lista = ref.watch(gastosDelMesElegidoProvider).valueOrNull;
  if (lista == null) return null;
  for (final g in lista) {
    if (g.id == gastoId) return g;
  }
  return null;
});
