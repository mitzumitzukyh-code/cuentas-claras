import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/firebase_providers.dart';
import '../../features/negocio/data/negocio_repository.dart';
import '../../features/notificaciones/domain/preferencias_tasa.dart';

/// Canal de Android para los avisos de tasa.
///
/// Android 8+ exige que toda notificación pertenezca a un canal declarado; si
/// no existe, el aviso se descarta en silencio. El id coincide con el que
/// declara el AndroidManifest como canal por defecto de FCM.
const AndroidNotificationChannel canalTasa = AndroidNotificationChannel(
  'tasa_bcv',
  'Tasa del dólar',
  description: 'Avisos cuando el dólar BCV sube, baja o se acelera.',
  importance: Importance.high,
);

/// Canal del resumen de ventas del día — aparte del de tasa BCV para que no
/// aparezca en los ajustes del sistema como si fuera un aviso del dólar.
const AndroidNotificationChannel canalVentas = AndroidNotificationChannel(
  'resumen_ventas',
  'Resumen de ventas',
  description: 'Cuánto vendiste hoy, una vez al final del día.',
  importance: Importance.high,
);

/// Canal de las alertas de stock bajo — que el dueño pueda silenciarlas en los
/// ajustes del sistema sin tocar las de tasa ni las de ventas. El id coincide
/// con el `channel_id` que manda el Worker (`stock_bajo`); sin este canal
/// declarado, Android 8+ descarta esas notificaciones en silencio.
const AndroidNotificationChannel canalStock = AndroidNotificationChannel(
  'stock_bajo',
  'Stock bajo',
  description: 'Avisos cuando un producto se agota o está por agotarse.',
  importance: Importance.high,
);

/// Recibe los push en segundo plano.
///
/// Tiene que ser una función de nivel superior: Android arranca un isolate
/// nuevo para ejecutarla y no puede alcanzar el estado de la app.
///
/// No hace falta pintar nada aquí. El Worker manda una notificación con bloque
/// `notification`, así que el sistema la muestra por su cuenta con el icono y
/// el color del manifest.
@pragma('vm:entry-point')
Future<void> manejarPushEnSegundoPlano(RemoteMessage mensaje) async {}

/// Uno o más topics no confirmaron su suscripción o baja a tiempo.
///
/// El estado local (SharedPreferences) siempre queda consistente con lo que
/// SÍ se confirmó; esto solo informa de que algo se quedó a medias, para que
/// la UI pueda avisar en vez de mostrar un interruptor en verde que miente.
class PushSyncException implements Exception {
  const PushSyncException(this.topics);

  final List<String> topics;

  @override
  String toString() =>
      'No se pudo confirmar con Google: ${topics.join(', ')}. '
      'Puede ser un problema temporal de Google Play Services en este '
      'dispositivo.';
}

/// Notificaciones push de la tasa BCV.
///
/// El reparto va por topics (ver [PreferenciasTasa]), así que este servicio
/// nunca envía un token a ningún servidor.
class PushService {
  PushService(this._messaging, this._locales, this._prefs);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _locales;
  final SharedPreferences _prefs;

  static const _claveUmbral = 'aviso_tasa_umbral';
  static const _clavePermiso = 'aviso_tasa_permiso';
  static const _claveTopics = 'aviso_tasa_topics_suscritos';
  static const _clavePreguntoAuto = 'aviso_tasa_pregunto_auto';

  /// Prepara el canal y los manejadores. Se llama una vez al arrancar.
  Future<void> iniciar() async {
    final android =
        _locales
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await android?.createNotificationChannel(canalTasa);
    await android?.createNotificationChannel(canalVentas);
    await android?.createNotificationChannel(canalStock);

    await _locales.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notificacion'),
      ),
    );

    // Con la app abierta, Android no muestra el push por su cuenta: hay que
    // pintarlo a mano o el usuario no ve nada mientras usa la app.
    FirebaseMessaging.onMessage.listen(mostrarEnPrimerPlano);

    // Solo en depuración: sin el token no hay forma de comprobar desde fuera a
    // qué topics está suscrito el dispositivo, y "no me llega nada" es
    // imposible de diagnosticar a ciegas.
    //
    // Con timeout y try/catch a propósito: en ROMs con Google Play Services
    // dañado o desactualizado, `getToken()` puede quedarse esperando una
    // respuesta que nunca llega. Sin esto, ese cuelgue es invisible — no hay
    // excepción, no hay log, solo silencio.
    if (kDebugMode) {
      try {
        final token = await _messaging.getToken().timeout(
          const Duration(seconds: 10),
        );
        debugPrint('[push] token FCM: $token');
        // Además de logcat: en ROMs que filtran el nivel Info del tag
        // `flutter` (visto en un ZTE de pruebas, donde debugPrint nunca
        // aparecía pese a ejecutarse), esto se puede leer directo del
        // disco con `adb shell run-as <paquete> cat .../FlutterSharedPreferences.xml`
        // sin depender de logcat en absoluto.
        await _prefs.setString('debug_fcm_token', token ?? '(null)');
      } catch (e) {
        debugPrint('[push] no se pudo obtener el token: $e');
        await _prefs.setString('debug_fcm_token', 'ERROR: $e');
      }
    }
  }

  /// Pinta un aviso recibido mientras la app está en pantalla.
  ///
  /// Con la app abierta, Android no muestra el push por su cuenta; hay que
  /// pintarlo a mano, y en el canal correcto según el tipo, para que se agrupe
  /// y se pueda silenciar donde corresponde (tasa / ventas / stock).
  Future<void> mostrarEnPrimerPlano(RemoteMessage mensaje) async {
    final aviso = mensaje.notification;
    if (aviso == null) return;

    final canal = switch (mensaje.data['tipo']) {
      'stock' => canalStock,
      'resumen_ventas' || 'recordatorio_ventas' => canalVentas,
      _ => canalTasa,
    };

    await _locales.show(
      mensaje.hashCode,
      aviso.title,
      aviso.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          icon: '@drawable/ic_notificacion',
          importance: Importance.high,
          priority: Priority.high,
          // El cuerpo lleva cifras y puede pasar de una línea.
          styleInformation: BigTextStyleInformation(aviso.body ?? ''),
        ),
      ),
      payload: jsonEncode(mensaje.data),
    );
  }

  /// Pide el permiso de notificaciones (Android 13+ e iOS lo exigen).
  Future<bool> pedirPermiso() async {
    final ajustes = await _messaging.requestPermission();
    final concedido =
        ajustes.authorizationStatus == AuthorizationStatus.authorized ||
        ajustes.authorizationStatus == AuthorizationStatus.provisional;
    await _prefs.setBool(_clavePermiso, concedido);
    return concedido;
  }

  bool get permisoConcedido => _prefs.getBool(_clavePermiso) ?? false;

  /// `true` si ya se intentó pedir el permiso automáticamente alguna vez.
  ///
  /// Antes el permiso (y por lo tanto la suscripción a los topics) solo se
  /// pedía si el dueño encontraba el botón "Permitir avisos" en Ajustes —
  /// muchos nunca llegaban a verlo y se quedaban sin ninguna notificación,
  /// sin saber por qué, aunque Android ya les permitiera recibirlas. Ahora se
  /// pregunta sola la primera vez que se abre el Dashboard; esta bandera
  /// evita repetir el intento en cada arranque de la app.
  bool get yaSePreguntoAutomatico =>
      _prefs.getBool(_clavePreguntoAuto) ?? false;

  Future<void> marcarPreguntadoAutomatico() =>
      _prefs.setBool(_clavePreguntoAuto, true);

  // --- Preferencias ---

  PreferenciasTasa leerPreferencias() {
    final activos = <TipoAvisoTasa>{};
    for (final tipo in TipoAvisoTasa.values) {
      // Por defecto todo encendido: quien abre la app ya dijo que quiere los
      // avisos al conceder el permiso.
      if (_prefs.getBool(tipo.clavePref) ?? true) activos.add(tipo);
    }
    return PreferenciasTasa(
      activos: activos,
      umbral: UmbralTasa.desdeId(_prefs.getString(_claveUmbral)),
      permisoConcedido: permisoConcedido,
    );
  }

  /// Guarda las preferencias y reconcilia las suscripciones de FCM.
  Future<void> guardarPreferencias(PreferenciasTasa nuevas) async {
    for (final tipo in TipoAvisoTasa.values) {
      await _prefs.setBool(tipo.clavePref, nuevas.estaActivo(tipo));
    }
    await _prefs.setString(_claveUmbral, nuevas.umbral.id);
    await sincronizarTopics(nuevas);
  }

  /// Topics a los que este dispositivo está suscrito de verdad.
  ///
  /// Se persiste porque FCM no ofrece forma de preguntárselo desde el cliente,
  /// y es la única referencia fiable para saber de qué hay que darse de baja.
  Set<String> get _topicsSuscritos =>
      (_prefs.getStringList(_claveTopics) ?? const []).toSet();

  /// Cuánto se espera a `subscribeToTopic`/`unsubscribeFromTopic` antes de
  /// darlas por colgadas.
  ///
  /// En ROMs con Google Play Services dañado o desactualizado —el ZTE de
  /// pruebas mostraba `DynamiteModule` y `ProviderInstaller` fallando— estas
  /// llamadas pueden quedarse esperando una respuesta que nunca llega, sin
  /// lanzar ninguna excepción. Sin este límite, ese cuelgue es invisible: la
  /// interfaz queda esperando para siempre y no hay ningún error que mostrar.
  static const _timeoutTopic = Duration(seconds: 8);

  /// Deja las suscripciones de FCM igual a lo que piden las preferencias.
  ///
  /// Compara contra lo REALMENTE suscrito, no contra el estado anterior de las
  /// preferencias. Derivarlo del estado anterior tenía un fallo silencioso: al
  /// conceder el permiso, los topics deseados de antes y de después son los
  /// mismos —el permiso no cambia la lista, solo si sirve de algo—, así que la
  /// diferencia salía vacía y no se suscribía a nada. El usuario veía los
  /// interruptores encendidos y no recibía ni un aviso.
  ///
  /// Solo se guarda como "suscrito" lo que de verdad confirmó el SDK. Si un
  /// topic falla o se cuelga, se lanza al final para que quien llama pueda
  /// avisar al usuario en vez de dejar el interruptor en verde por una
  /// suscripción que nunca se completó.
  Future<void> sincronizarTopics(PreferenciasTasa prefs) async {
    // Sin permiso no se recibe nada: se sale de todo para no gastar envíos en
    // un dispositivo que no los va a mostrar.
    final deseados = prefs.permisoConcedido ? prefs.topicsDeseados : <String>{};
    final suscritos = Set<String>.from(_topicsSuscritos);
    final fallidos = <String>[];

    for (final topic in suscritos.difference(deseados).toList()) {
      try {
        await _messaging.unsubscribeFromTopic(topic).timeout(_timeoutTopic);
        suscritos.remove(topic);
      } catch (_) {
        // No se pudo confirmar la baja: se deja como estaba y se reintentará
        // en la próxima sincronización.
        fallidos.add(topic);
      }
    }
    for (final topic in deseados.difference(suscritos).toList()) {
      try {
        await _messaging.subscribeToTopic(topic).timeout(_timeoutTopic);
        suscritos.add(topic);
      } catch (_) {
        fallidos.add(topic);
      }
    }

    await _prefs.setStringList(_claveTopics, suscritos.toList()..sort());

    if (fallidos.isNotEmpty) {
      throw PushSyncException(fallidos);
    }
  }
}

// --- Providers ---

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final notificacionesLocalesProvider = Provider<FlutterLocalNotificationsPlugin>(
  (ref) => FlutterLocalNotificationsPlugin(),
);

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(
    ref.watch(firebaseMessagingProvider),
    ref.watch(notificacionesLocalesProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

/// Preferencias de avisos, con las suscripciones ya reconciliadas al cambiar.
class PreferenciasTasaNotifier extends StateNotifier<PreferenciasTasa> {
  PreferenciasTasaNotifier(this._servicio)
    : super(_servicio.leerPreferencias());

  final PushService _servicio;

  Future<void> alternar(TipoAvisoTasa tipo, bool activo) async {
    final activos = Set<TipoAvisoTasa>.from(state.activos);
    activo ? activos.add(tipo) : activos.remove(tipo);
    await _aplicar(state.copyWith(activos: activos));
  }

  Future<void> cambiarUmbral(UmbralTasa umbral) =>
      _aplicar(state.copyWith(umbral: umbral));

  /// Pide el permiso del sistema y, si lo dan, suscribe a los topics elegidos.
  Future<bool> pedirPermiso() async {
    final concedido = await _servicio.pedirPermiso();
    await _aplicar(state.copyWith(permisoConcedido: concedido));
    return concedido;
  }

  /// Pide el permiso automáticamente, pero solo una vez en toda la vida de la
  /// instalación — se llama desde el Dashboard, no hace falta que el dueño
  /// encuentre ningún botón. Si Android ya lo tenía concedido (versiones
  /// anteriores a la 13, o porque el dueño lo activó desde los ajustes del
  /// sistema), Firebase lo confirma sin mostrar ningún diálogo y esto alcanza
  /// para dejar los topics suscritos de una vez.
  Future<void> pedirPermisoAutomaticoSiHaceFalta() async {
    if (_servicio.yaSePreguntoAutomatico) return;
    await _servicio.marcarPreguntadoAutomatico();
    if (state.permisoConcedido) return;
    try {
      await pedirPermiso();
    } on PushSyncException {
      // Sin usuario mirando no hay a quién avisarle del fallo de sincronía;
      // la próxima vez que abra Ajustes lo reintentará con feedback visible.
    }
  }

  /// Aplica el cambio y reconcilia con Google. Si la reconciliación falla, el
  /// estado se relee de lo que de verdad quedó guardado —nunca se deja el
  /// optimista puesto—, y el error se relanza para que la pantalla lo muestre.
  Future<void> _aplicar(PreferenciasTasa nuevas) async {
    state = nuevas;
    try {
      await _servicio.guardarPreferencias(nuevas);
    } catch (_) {
      state = _servicio.leerPreferencias();
      rethrow;
    }
  }
}

final preferenciasTasaProvider =
    StateNotifierProvider<PreferenciasTasaNotifier, PreferenciasTasa>((ref) {
      return PreferenciasTasaNotifier(ref.watch(pushServiceProvider));
    });

/// Efecto de una sola vez: pide el permiso de notificaciones automáticamente
/// si nunca se había preguntado. Al ser un `FutureProvider` normal, Riverpod
/// solo ejecuta su cuerpo la primera vez que algo lo observa en toda la vida
/// del `ProviderContainer` — por eso el Dashboard puede simplemente
/// observarlo en cada build sin repetir el intento.
final autoPedirPermisoTasaProvider = FutureProvider<void>((ref) {
  return ref
      .read(preferenciasTasaProvider.notifier)
      .pedirPermisoAutomaticoSiHaceFalta();
});

/// Guarda el token FCM de este dispositivo en la membresía activa, para que
/// el Worker pueda mandarle el resumen de ventas del día directo al dueño.
///
/// A diferencia del permiso (que se pide una sola vez en la vida de la
/// instalación), esto SÍ se reevalúa cada vez que cambian sus dependencias
/// (permiso recién concedido, cambio de negocio activo, etc.) — son
/// reescrituras baratas e idempotentes, y es la única forma de no perderse
/// el momento en que el permiso pasa de no concedido a concedido.
///
/// Solo el dueño lo necesita: el resumen de ventas es información financiera,
/// igual que Reportes (CLAUDE.md §6), y un empleado no debe recibirla.
final registrarTokenVentasProvider = FutureProvider<void>((ref) async {
  final prefs = ref.watch(preferenciasTasaProvider);
  final esDueno = ref.watch(esDuenoProvider);
  final membresia = ref.watch(membresiaActivaProvider);
  if (!prefs.permisoConcedido || !esDueno || membresia == null) return;

  final token = await ref.watch(firebaseMessagingProvider).getToken();
  if (token == null || token == membresia.pushToken) return;
  await ref
      .watch(negocioRepositoryProvider)
      .guardarTokenPush(membresia.id, token);
});
