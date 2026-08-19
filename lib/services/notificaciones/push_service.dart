import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/router/app_router.dart';
import '../../app/router/routes.dart';
import '../../core/providers/firebase_providers.dart';
import '../../features/negocio/data/negocio_repository.dart';
import '../../features/notificaciones/domain/preferencias_tasa.dart';
import 'ids_notificacion.dart';

/// Canal de Android para los avisos de tasa.
///
/// Android 8+ exige que toda notificación pertenezca a un canal declarado; si
/// no existe, el aviso se descarta en silencio. El id coincide con el que
/// declara el AndroidManifest como canal por defecto de FCM.
const AndroidNotificationChannel canalTasa = AndroidNotificationChannel(
  'tasa_bcv',
  'Tasa del dólar',
  description: 'La tasa del día a las 8 am, 12 pm y 3 pm.',
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

/// Cortes de luz. Vive aquí, con los demás canales de push, porque estos
/// avisos también los manda el Worker: el teléfono solo se suscribe al topic
/// de su bloque (ver `LuzService`).
///
/// Interrumpe, a diferencia de los recordatorios: llega media hora antes de
/// que se vaya la luz y lo que se hace con él —cobrar lo que falta, cargar el
/// teléfono, cerrar la nevera— no espera.
const AndroidNotificationChannel canalLuz = AndroidNotificationChannel(
  'cortes_luz',
  'Cortes de luz',
  description: 'Aviso antes de que se vaya la luz en tu bloque, y cuándo '
      'debería volver.',
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
  PushService(this._messaging, this._locales, this._prefs, this._router);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _locales;
  final SharedPreferences _prefs;
  final GoRouter _router;

  /// A dónde ir si tocar una notificación fue lo que abrió la app desde cero.
  ///
  /// `getInitialMessage()` solo se puede preguntar una vez de forma útil, así
  /// que se cachea aquí hasta que el Dashboard la consuma en su primer frame
  /// —navegar antes de eso no serviría de nada: el redirect de sesión todavía
  /// está mandando a Splash.
  String? _rutaPendiente;

  /// A qué pantalla lleva cada tipo de aviso, o `null` si no aplica ninguna.
  static String? _rutaDe(Object? tipo) => switch (tipo) {
    'subida' || 'bajada' || 'ritmo' || 'resumen' => Routes.dashboard,
    'stock' => Routes.productos,
    'resumen_ventas' || 'recordatorio_ventas' => Routes.reportes,
    _ => null,
  };

  /// Navega ya mismo — para cuando la app está corriendo (en segundo plano o
  /// en primer plano) y el router ya está montado.
  void _navegarPorToque(Map<String, dynamic> datos) {
    final ruta = _rutaDe(datos['tipo']);
    if (ruta != null) _router.push(ruta);
  }

  /// Lee y limpia la ruta pendiente de un toque en frío. `null` casi siempre.
  String? consumirRutaPendiente() {
    final ruta = _rutaPendiente;
    _rutaPendiente = null;
    return ruta;
  }

  static const _claveActivos = 'aviso_tasa_activos';
  static const _clavePermiso = 'aviso_tasa_permiso';
  static const _claveTopics = 'aviso_tasa_topics_suscritos';
  static const _clavePreguntoAuto = 'aviso_tasa_pregunto_auto';
  static const _claveAvisoDescartado = 'aviso_notif_descartado';

  /// Clave del interruptor "Resumen de la mañana" de la versión anterior.
  ///
  /// La nueva preferencia es un solo interruptor para los avisos de tasa. Quien
  /// ya tenía apagado el resumen de la mañana apagó el único aviso que existía;
  /// respetarlo es lo mismo que respetar su decisión, y encenderle los tres de
  /// golpe sin preguntar seria exactamente el tipo de sorpresa que desinstala
  /// una app de notificaciones.
  static const _claveLegadoResumen = 'aviso_tasa_resumen';

  /// Topics que la versión anterior pudo dejar suscritos y que ya no existen.
  ///
  /// El Worker ya no publica en umbrales (subida/bajada por porcentaje) ni en
  /// el ritmo: solo quedó el topic de tasa. Estos nombres se mantienen solo
  /// para dar de baja lo que hayan quedado huérfanos en dispositivos viejos
  /// — una baja que falló en silencio dejaría al teléfono escuchando un topic
  /// muerto, que es inofensivo pero no hay razón para conservarlo.
  static const _topicsLegadosDeTasa = {
    'tasa-subida-minimo',
    'tasa-subida-medio',
    'tasa-subida-uno',
    'tasa-subida-tres',
    'tasa-subida-cinco',
    'tasa-bajada-minimo',
    'tasa-bajada-medio',
    'tasa-bajada-uno',
    'tasa-bajada-tres',
    'tasa-bajada-cinco',
    'tasa-ritmo',
  };

  /// Cada cuánto vuelve a asomar el aviso de "activa las notificaciones" tras
  /// descartarlo: ni molesto (no sale en cada apertura) ni resignado (no se
  /// rinde para siempre — el permiso apagado deja al usuario sin tasa, ventas
  /// ni stock, así que vale la pena recordárselo de vez en cuando).
  static const _reasomarAviso = Duration(days: 14);

  /// `true` si el empujón se descartó hace menos de [_reasomarAviso] — es
  /// decir, si todavía NO toca volver a mostrarlo en el Inicio.
  bool get avisoNotifDescartadoReciente {
    final ms = _prefs.getInt(_claveAvisoDescartado);
    if (ms == null) return false;
    final descartadoEn = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(descartadoEn) <= _reasomarAviso;
  }

  Future<void> descartarAvisoNotif() =>
      _prefs.setInt(_claveAvisoDescartado, DateTime.now().millisecondsSinceEpoch);

  /// Estado REAL del permiso del sistema en este momento (sin mostrar diálogo).
  ///
  /// No basta el booleano guardado: el usuario puede prender o apagar las
  /// notificaciones desde los ajustes del teléfono sin que la app se entere. Se
  /// pregunta en vivo y de paso se reconcilia el guardado.
  Future<bool> permisoVivo() async {
    final ajustes = await _messaging.getNotificationSettings();
    final ok =
        ajustes.authorizationStatus == AuthorizationStatus.authorized ||
        ajustes.authorizationStatus == AuthorizationStatus.provisional;
    await _prefs.setBool(_clavePermiso, ok);
    return ok;
  }

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
      // Toque sobre una notificación pintada a mano (app en primer plano):
      // el payload es el mismo `data` del push, guardado como JSON al
      // mostrarla.
      onDidReceiveNotificationResponse: (respuesta) {
        final payload = respuesta.payload;
        if (payload == null) return;
        try {
          _navegarPorToque(jsonDecode(payload) as Map<String, dynamic>);
        } catch (_) {
          // Payload corrupto o de una versión vieja de la app: no navegar,
          // no crashear.
        }
      },
    );

    // Con la app abierta, Android no muestra el push por su cuenta: hay que
    // pintarlo a mano o el usuario no ve nada mientras usa la app.
    FirebaseMessaging.onMessage.listen(mostrarEnPrimerPlano);

    // Toque sobre el push nativo con la app en segundo plano (no cerrada).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (mensaje) => _navegarPorToque(mensaje.data),
    );

    // Toque sobre el push nativo con la app cerrada del todo: esto la abrió.
    // No se navega ya mismo —el router recién está mandando a Splash— se
    // guarda para que el Dashboard la use en cuanto la sesión esté lista.
    final inicial = await _messaging.getInitialMessage();
    if (inicial != null) _rutaPendiente = _rutaDe(inicial.data['tipo']);

    // Repara en cada arranque las suscripciones que hayan quedado
    // desincronizadas — en ROMs con Play Services dañado (visto en el ZTE de
    // pruebas) una baja de topic puede fallar en silencio y dejar el
    // dispositivo escuchando un umbral viejo además del actual, repitiendo el
    // mismo aviso varias veces. Sin bloquear el arranque de la app.
    if (permisoConcedido) {
      unawaited(_repararTopicsViejos());
    }

    // Solo en depuración: sin el token no hay forma de comprobar desde fuera a
    // qué topics está suscrito el dispositivo, y "no me llega nada" es
    // imposible de diagnosticar a ciegas.
    //
    // Con timeout y try/catch a propósito: en ROMs con Google Play Services
    // dañado o desactualizado, `getToken()` puede quedarse esperando una
    // respuesta que nunca llega. Sin esto, ese cuelgue es invisible — no hay
    // excepción, no hay log, solo silencio.
    if (kDebugMode) {
      // Deja el inventario de ids en logcat al arrancar. Es la forma rápida de
      // ver si un aviso está saliendo con id dinámico: si el mismo texto
      // aparece con varios ids, algo lo está apilando en vez de reemplazarlo.
      unawaited(diagnosticoNotificaciones());
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

  /// Canal e id que le tocan a cada tipo de aviso.
  ///
  /// El id es FIJO por tipo a propósito: un aviso de tasa nuevo debe
  /// reemplazar al anterior (es el mismo dato, actualizado), no acumularse.
  /// Antes se usaba `mensaje.hashCode`, que cambia con cada push y por eso
  /// dejaba una tarjeta nueva por cada aviso recibido.
  static (AndroidNotificationChannel, int) _destinoDe(Object? tipo) =>
      switch (tipo) {
        'stock' => (canalStock, IdsNotificacion.stock),
        'resumen_ventas' ||
        'recordatorio_ventas' => (canalVentas, IdsNotificacion.resumenVentas),
        'luz' => (canalLuz, IdsNotificacion.luz),
        _ => (canalTasa, IdsNotificacion.tasa),
      };

  /// Pinta un aviso recibido mientras la app está en pantalla.
  ///
  /// Con la app abierta, Android no muestra el push por su cuenta; hay que
  /// pintarlo a mano, y en el canal correcto según el tipo, para que se agrupe
  /// y se pueda silenciar donde corresponde (tasa / ventas / stock).
  Future<void> mostrarEnPrimerPlano(RemoteMessage mensaje) async {
    final aviso = mensaje.notification;
    if (aviso == null) return;

    final (canal, id) = _destinoDe(mensaje.data['tipo']);

    await _locales.show(
      id,
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
          groupKey: IdsNotificacion.grupo,
        ),
      ),
      payload: jsonEncode(mensaje.data),
    );
    await _publicarResumenDeGrupo();
  }

  /// Cabecera del grupo: el renglón que Android pliega arriba cuando hay
  /// varios avisos de la app desplegados.
  ///
  /// Se republica después de cada aviso porque el sistema la descarta cuando
  /// el grupo se queda vacío. Va en el canal de tasa por ser el de más
  /// importancia de los tres: la cabecera hereda el canal que se le dé, y
  /// ponerla en uno silenciado escondería el grupo entero.
  Future<void> _publicarResumenDeGrupo() async {
    await _locales.show(
      IdsNotificacion.resumenGrupo,
      'Cuenta Clara',
      null,
      NotificationDetails(
        android: AndroidNotificationDetails(
          canalTasa.id,
          canalTasa.name,
          channelDescription: canalTasa.description,
          icon: '@drawable/ic_notificacion',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: IdsNotificacion.grupo,
          setAsGroupSummary: true,
          // La cabecera no debe sonar ni vibrar: el aviso que la acompaña ya
          // lo hizo, y si no, cada notificación sonaría dos veces.
          onlyAlertOnce: true,
          playSound: false,
          enableVibration: false,
        ),
      ),
    );
  }

  /// Qué notificaciones hay programadas y cuáles siguen en pantalla.
  ///
  /// Para auditar duplicados sin adivinar: si un mismo aviso aparece con
  /// varios ids distintos, es que algo lo está mostrando con id dinámico. Se
  /// llama desde Ajustes → Diagnóstico y también se puede leer con
  /// `adb logcat -s flutter`.
  Future<String> diagnosticoNotificaciones() async {
    final pendientes = await _locales.pendingNotificationRequests();
    final activas = await _locales
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.getActiveNotifications();

    final buffer = StringBuffer()
      ..writeln('--- Notificaciones programadas (${pendientes.length}) ---');
    for (final p in pendientes..sort((a, b) => a.id.compareTo(b.id))) {
      buffer.writeln('  #${p.id}  ${p.title}');
    }
    buffer.writeln('--- En pantalla ahora (${activas?.length ?? 0}) ---');
    for (final a in activas ?? const []) {
      buffer.writeln('  #${a.id}  ${a.title}  [grupo: ${a.groupKey}]');
    }

    final texto = buffer.toString();
    debugPrint('[push] $texto');
    return texto;
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
    return PreferenciasTasa(
      // Por defecto encendido. Si la instalación viene de la versión anterior,
      // respeta lo que el dueño decidió sobre el resumen de la mañana — el
      // único aviso de tasa que existía entonces.
      activos:
          _prefs.getBool(_claveActivos) ??
          (_prefs.getBool(_claveLegadoResumen) ?? true),
      permisoConcedido: permisoConcedido,
    );
  }

  /// Guarda las preferencias y reconcilia las suscripciones de FCM.
  Future<void> guardarPreferencias(PreferenciasTasa nuevas) async {
    await _prefs.setBool(_claveActivos, nuevas.activos);
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
    final deseados = prefs.permisoConcedido && prefs.activos
        ? {topicAvisoTasa}
        : <String>{};
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

  /// Limpieza preventiva en segundo plano: da de baja los topics de la
  /// versión anterior (umbrales y ritmo) sin importar si [_topicsSuscritos]
  /// sabe de ellos o no.
  ///
  /// Separado de [sincronizarTopics] a propósito: en un dispositivo con Play
  /// Services dañado (visto en el ZTE de pruebas), cada baja de más puede
  /// tardar hasta [_timeoutTopic] en agotarse, y aquí se intentan hasta once
  /// de una vez — mezclarlo con el guardado interactivo de Ajustes dejaría el
  /// botón "Guardando…" colgado casi un minuto. Se llama sola al arrancar y
  /// nadie espera su resultado.
  Future<void> _repararTopicsViejos() async {
    if (!permisoConcedido) return;
    for (final topic in _topicsLegadosDeTasa) {
      try {
        await _messaging.unsubscribeFromTopic(topic).timeout(_timeoutTopic);
      } catch (_) {
        // Best-effort: si falla, se reintenta en el próximo arranque.
      }
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
    ref.watch(goRouterProvider),
  );
});

/// Efecto de una sola vez: si tocar una notificación con la app cerrada fue
/// lo que la abrió, entrega la ruta pendiente para que el Dashboard navegue
/// en su primer frame. Como todo `FutureProvider` normal, Riverpod solo
/// corre esto una vez en la vida del contenedor.
final rutaPendienteDeNotifProvider = FutureProvider<String?>((ref) {
  return ref.watch(pushServiceProvider).consumirRutaPendiente();
});

/// Estado real del permiso de notificaciones del sistema. Lo observa el
/// empujón (`AvisoNotificaciones`) para saber si mostrarse; se invalida al
/// volver a primer plano para reflejar cambios hechos desde los ajustes.
final permisoNotifVivoProvider = FutureProvider<bool>((ref) {
  return ref.watch(pushServiceProvider).permisoVivo();
});

/// Preferencias de avisos, con las suscripciones ya reconciliadas al cambiar.
class PreferenciasTasaNotifier extends StateNotifier<PreferenciasTasa> {
  PreferenciasTasaNotifier(this._servicio)
    : super(_servicio.leerPreferencias());

  final PushService _servicio;

  Future<void> alternar(bool activo) async {
    await _aplicar(state.copyWith(activos: activo));
  }

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
