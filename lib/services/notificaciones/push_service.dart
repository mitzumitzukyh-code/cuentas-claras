import 'dart:convert';

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
  ///
  /// Se pasa el estado anterior para poder desuscribir lo que sobra: cambiar de
  /// umbral cambia el nombre del topic, y sin darse de baja del viejo llegarían
  /// avisos duplicados con dos umbrales distintos.
  Future<void> guardarPreferencias(
    PreferenciasTasa nuevas, {
    PreferenciasTasa? anteriores,
  }) async {
    for (final tipo in TipoAvisoTasa.values) {
      await _prefs.setBool(tipo.clavePref, nuevas.estaActivo(tipo));
    }
    await _prefs.setString(_claveUmbral, nuevas.umbral.id);

    final previos = (anteriores ?? leerPreferencias()).topicsDeseados;
    await sincronizarTopics(nuevas, topicsPrevios: previos);
  }

  /// Deja las suscripciones de FCM igual a lo que piden las preferencias.
  Future<void> sincronizarTopics(
    PreferenciasTasa prefs, {
    Set<String> topicsPrevios = const {},
  }) async {
    final deseados = prefs.topicsDeseados;

    for (final topic in topicsPrevios.difference(deseados)) {
      await _messaging.unsubscribeFromTopic(topic);
    }
    if (!prefs.permisoConcedido) {
      // Sin permiso no tiene sentido recibir: se sale de todo para no gastar
      // envíos en un dispositivo que no los va a mostrar.
      for (final topic in deseados) {
        await _messaging.unsubscribeFromTopic(topic);
      }
      return;
    }
    for (final topic in deseados.difference(topicsPrevios)) {
      await _messaging.subscribeToTopic(topic);
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

  Future<void> _aplicar(PreferenciasTasa nuevas) async {
    final anteriores = state;
    state = nuevas;
    await _servicio.guardarPreferencias(nuevas, anteriores: anteriores);
  }
}

final preferenciasTasaProvider =
    StateNotifierProvider<PreferenciasTasaNotifier, PreferenciasTasa>((ref) {
  return PreferenciasTasaNotifier(ref.watch(pushServiceProvider));
});
