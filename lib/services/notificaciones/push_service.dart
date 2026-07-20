import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/providers/firebase_providers.dart';
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

  /// Prepara el canal y los manejadores. Se llama una vez al arrancar.
  Future<void> iniciar() async {
    await _locales
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canalTasa);

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
        final token =
            await _messaging.getToken().timeout(const Duration(seconds: 10));
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
  Future<void> mostrarEnPrimerPlano(RemoteMessage mensaje) async {
    final aviso = mensaje.notification;
    if (aviso == null) return;

    await _locales.show(
      mensaje.hashCode,
      aviso.title,
      aviso.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          canalTasa.id,
          canalTasa.name,
          channelDescription: canalTasa.description,
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
        await _messaging
            .unsubscribeFromTopic(topic)
            .timeout(_timeoutTopic);
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
  PreferenciasTasaNotifier(this._servicio) : super(_servicio.leerPreferencias());

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
