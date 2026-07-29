import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/domain/rubro.dart';
import '../domain/invitacion.dart';
import '../domain/membresia.dart';
import '../domain/metodo_pago_config.dart';
import '../domain/negocio.dart';

/// Repositorio de negocios y membresías (CLAUDE.md §4).
class NegocioRepository {
  NegocioRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _negocios =>
      _db.collection(FirestorePaths.negocios);
  CollectionReference<Map<String, dynamic>> get _membresias =>
      _db.collection(FirestorePaths.membresias);
  CollectionReference<Map<String, dynamic>> get _invitaciones =>
      _db.collection(FirestorePaths.invitaciones);

  /// Membresías del usuario (para saber a qué negocios pertenece).
  Stream<List<Membresia>> misMembresias(String usuarioId) {
    return _membresias
        .where('usuarioId', isEqualTo: usuarioId)
        .snapshots()
        .map((s) => s.docs.map(Membresia.fromDoc).toList());
  }

  Stream<Negocio?> negocioStream(String negocioId) {
    return _negocios
        .doc(negocioId)
        .snapshots()
        .map((doc) => doc.exists ? Negocio.fromDoc(doc) : null);
  }

  /// Miembros de un negocio (pantalla de Empleados). Solo el dueño puede
  /// leerlos: las reglas de Firestore lo exigen además de la UI.
  Stream<List<Membresia>> miembrosDe(String negocioId) {
    return _membresias
        .where('negocioId', isEqualTo: negocioId)
        .snapshots()
        .map((s) => s.docs.map(Membresia.fromDoc).toList());
  }

  Future<void> cambiarRol(String membresiaId, RolMembresia rol) {
    return _membresias.doc(membresiaId).update({'rol': rol.id});
  }

  /// Guarda el mapa de permisos granular de un miembro.
  Future<void> guardarPermisos(String membresiaId, Map<String, bool> permisos) {
    return _membresias.doc(membresiaId).update({'permisos': permisos});
  }

  Future<void> quitarMiembro(String membresiaId) {
    return _membresias.doc(membresiaId).delete();
  }

  /// Guarda el token FCM de este dispositivo en la membresía — lo usa el
  /// Worker para mandar el resumen de ventas del día directo al dueño (ver
  /// [Membresia.pushToken]).
  Future<void> guardarTokenPush(String membresiaId, String token) {
    return _membresias.doc(membresiaId).update({'pushToken': token});
  }

  /// Borra el negocio completo: productos, insumos y gastos, el documento del
  /// negocio y la membresía de quien lo pide. Para cumplir con el borrado de
  /// cuenta que exige Google Play.
  ///
  /// Las **ventas NO se borran** — las reglas de Firestore lo prohíben a
  /// propósito (CLAUDE.md §6: una venta nunca se elimina) y Venezuela exige
  /// conservar los registros de venta por motivos fiscales. Ya no contienen
  /// nada personal del dueño (ni nombre ni correo, solo su uid), así que
  /// conservarlas no deja datos personales atrás; la política de privacidad
  /// lo explica.
  ///
  /// Solo debe llamarse cuando no queda ningún otro miembro — con empleados
  /// activos, la pantalla de borrado de cuenta bloquea el intento y manda a
  /// quitarlos primero.
  Future<void> eliminarNegocioCompleto(
    String negocioId,
    String membresiaId,
  ) async {
    final negocioRef = _negocios.doc(negocioId);
    for (final sub in [
      FirestorePaths.productos,
      FirestorePaths.insumos,
      FirestorePaths.gastos,
    ]) {
      await _borrarColeccion(negocioRef.collection(sub));
    }

    final batch = _db.batch();
    batch.delete(_membresias.doc(membresiaId));
    batch.delete(negocioRef);
    await batch.commit();
  }

  /// Firestore no borra subcolecciones solas: hay que traer y borrar en
  /// tandas (un batch admite hasta 500 operaciones).
  Future<void> _borrarColeccion(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    const tanda = 400;
    while (true) {
      final snap = await col.limit(tanda).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < tanda) return;
    }
  }

  /// Crea un código de invitación de un solo uso, válido 24 h.
  Future<Invitacion> crearInvitacion({
    required String negocioId,
    required String negocioNombre,
    required RolMembresia rol,
  }) async {
    final invitacion = Invitacion(
      codigo: Invitacion.generarCodigo(),
      negocioId: negocioId,
      negocioNombre: negocioNombre,
      rol: rol,
      expiraEn: DateTime.now().add(Invitacion.duracion),
    );
    await _invitaciones.doc(invitacion.codigo).set(invitacion.toMap());
    return invitacion;
  }

  Future<Invitacion?> buscarInvitacion(String codigo) async {
    final doc = await _invitaciones.doc(codigo.trim().toUpperCase()).get();
    return doc.exists ? Invitacion.fromDoc(doc) : null;
  }

  /// Acepta una invitación: crea la membresía y marca el código como usado.
  ///
  /// Ambas escrituras van en un `batch` para que no quede un código consumido
  /// sin membresía, ni una membresía con el código aún disponible.
  Future<void> aceptarInvitacion({
    required Invitacion invitacion,
    required String usuarioId,
    String? nombre,
    String? correo,
  }) async {
    final membresiaId = FirestorePaths.membresiaId(
      usuarioId,
      invitacion.negocioId,
    );
    final membresia = Membresia(
      id: membresiaId,
      usuarioId: usuarioId,
      negocioId: invitacion.negocioId,
      rol: invitacion.rol,
      nombre: nombre,
      correo: correo,
      // Las reglas leen este código para comprobar que la invitación sigue
      // viva, sin usar, y es de este negocio y este rol.
      codigoInvitacion: invitacion.codigo,
    );

    final batch = _db.batch();
    batch.set(_membresias.doc(membresiaId), membresia.toMap());
    batch.update(_invitaciones.doc(invitacion.codigo), {'usado': true});
    await batch.commit();
  }

  /// Guarda los métodos de pago aceptados y sus datos.
  Future<void> guardarMetodosPago(
    String negocioId,
    List<MetodoPagoConfig> metodos,
  ) {
    return _negocios.doc(negocioId).update({
      'metodosPago': MetodoPagoConfig.listaAMapa(metodos),
    });
  }

  /// Guarda los ajustes editables del negocio (pantalla de Ajustes).
  ///
  /// Se escriben solo los campos enviados para no pisar `configuracion` ni el
  /// resto del documento.
  Future<void> actualizarAjustes(
    String negocioId, {
    String? nombre,
    bool? incluirIva,
    String? reciboMensaje,
    bool? alertaStockActiva,
    double? metaMensualUsd,
    String? proveedorWhatsapp,
    bool? haceDelivery,
    String? bancoCodigo,
    String? bancoNombre,
    String? fotoUrl,
    bool? fotoComoFondo,
  }) {
    final cambios = <String, dynamic>{
      if (nombre != null) 'nombre': nombre,
      if (incluirIva != null) 'incluirIva': incluirIva,
      if (reciboMensaje != null) 'reciboMensaje': reciboMensaje,
      if (alertaStockActiva != null) 'alertaStockActiva': alertaStockActiva,
      if (metaMensualUsd != null) 'metaMensualUsd': metaMensualUsd,
      if (proveedorWhatsapp != null) 'proveedorWhatsapp': proveedorWhatsapp,
      if (haceDelivery != null) 'haceDelivery': haceDelivery,
      if (bancoCodigo != null) 'bancoCodigo': bancoCodigo,
      if (bancoNombre != null) 'bancoNombre': bancoNombre,
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
      if (fotoComoFondo != null) 'fotoComoFondo': fotoComoFondo,
    };
    if (cambios.isEmpty) return Future.value();
    return _negocios.doc(negocioId).update(cambios);
  }

  /// Crea un negocio y la membresía de dueño de quien lo funda (CLAUDE.md §6).
  ///
  /// Las dos escrituras van **en orden, no en batch**. Las reglas de Firestore
  /// solo aceptan una membresía de dueño autoconcedida si el negocio ya existe
  /// y su `creadoPor` es el propio usuario; dentro de un batch las reglas se
  /// evalúan contra el estado anterior, así que el negocio todavía no estaría
  /// ahí y la membresía se rechazaría.
  ///
  /// El precio de perder la atomicidad es que un fallo entre ambas escrituras
  /// deja un negocio sin miembros. Es inofensivo —nadie puede leerlo ni
  /// escribirlo, ni siquiera quien lo creó— y el usuario simplemente reintenta.
  Future<Negocio> crearNegocio({
    required String usuarioId,
    required String nombre,
    required Rubro rubro,
    String? nombreUsuario,
    String? correoUsuario,
  }) async {
    final negocioRef = _negocios.doc();
    final negocio = Negocio(
      id: negocioRef.id,
      nombre: nombre,
      rubro: rubro,
      configuracion: rubro.config,
      creadoPor: usuarioId,
    );

    final membresiaId = FirestorePaths.membresiaId(usuarioId, negocioRef.id);
    final membresia = Membresia(
      id: membresiaId,
      usuarioId: usuarioId,
      negocioId: negocioRef.id,
      rol: RolMembresia.dueno,
      nombre: nombreUsuario,
      correo: correoUsuario,
    );

    await negocioRef.set(negocio.toMap());
    await _membresias.doc(membresiaId).set(membresia.toMap());

    return negocio;
  }
}

// --- Providers ---

final negocioRepositoryProvider = Provider<NegocioRepository>((ref) {
  return NegocioRepository(ref.watch(firestoreProvider));
});

/// Membresías del usuario autenticado (vacío si no hay sesión).
final misMembresiasProvider = StreamProvider<List<Membresia>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(const []);
  return ref.watch(negocioRepositoryProvider).misMembresias(user.uid);
});

/// Negocio seleccionado manualmente (multi-negocio, Fase 3). `null` = usar el
/// primero disponible.
///
/// Se persiste: sin esto, quien administra dos sucursales volvía a la primera
/// cada vez que abría la app y podía cobrar en el negocio equivocado sin
/// darse cuenta.
class NegocioSeleccionadoNotifier extends StateNotifier<String?> {
  NegocioSeleccionadoNotifier(this._prefs)
      : super(_prefs.getString(_clave));

  static const _clave = 'negocio_seleccionado';
  final SharedPreferences _prefs;

  @override
  set state(String? valor) {
    super.state = valor;
    if (valor == null) {
      _prefs.remove(_clave);
    } else {
      _prefs.setString(_clave, valor);
    }
  }

  @override
  String? get state => super.state;
}

final negocioSeleccionadoProvider =
    StateNotifierProvider<NegocioSeleccionadoNotifier, String?>((ref) {
  return NegocioSeleccionadoNotifier(ref.watch(sharedPreferencesProvider));
});

/// Membresía activa (define el negocio y el rol actuales).
final membresiaActivaProvider = Provider<Membresia?>((ref) {
  final membresias = ref.watch(misMembresiasProvider).valueOrNull ?? const [];
  if (membresias.isEmpty) return null;
  final seleccionado = ref.watch(negocioSeleccionadoProvider);
  if (seleccionado != null) {
    for (final m in membresias) {
      if (m.negocioId == seleccionado) return m;
    }
  }
  return membresias.first;
});

/// Negocio activo en tiempo real.
final negocioActivoProvider = StreamProvider<Negocio?>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(null);
  return ref
      .watch(negocioRepositoryProvider)
      .negocioStream(membresia.negocioId);
});

/// Un negocio cualquiera por id — usado por el selector de "Más" para
/// mostrar el nombre de cada negocio en `misMembresiasProvider` sin acoplarlo
/// al negocio activo.
final negocioPorIdProvider =
    StreamProvider.family<Negocio?, String>((ref, negocioId) {
  return ref.watch(negocioRepositoryProvider).negocioStream(negocioId);
});

/// Miembros del negocio activo (pantalla de Empleados).
final miembrosNegocioProvider = StreamProvider<List<Membresia>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  return ref.watch(negocioRepositoryProvider).miembrosDe(membresia.negocioId);
});

/// Atajo: ¿el usuario es dueño del negocio activo? Controla acciones de rol.
final esDuenoProvider = Provider<bool>((ref) {
  return ref.watch(membresiaActivaProvider)?.rol.esDueno ?? false;
});

/// Verifica si el usuario activo tiene un permiso específico.
/// Retorna `true` si es dueño (tiene todos los permisos) o si el permiso
/// está habilitado en su membresía.
final puedeProvider = Provider.family<bool, String>((ref, permiso) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return false;
  if (membresia.rol.esDueno) return true;
  return membresia.puede(permiso);
});
