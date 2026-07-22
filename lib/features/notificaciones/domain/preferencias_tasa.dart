/// Preferencias de los avisos de tasa BCV.
///
/// El reparto se hace por **topics** de FCM, no por tokens de dispositivo. Esto
/// evita mantener un registro de dispositivos en el servidor (y su problema de
/// tokens caducados): el Worker publica en el topic y Firebase reparte.
///
/// Como el filtrado por topic ocurre antes de que el aviso llegue al teléfono,
/// respeta las preferencias incluso con la app cerrada. Filtrar en el cliente no
/// serviría: el sistema ya habría mostrado la notificación.
library;

/// Cuánto tiene que moverse la tasa para que valga la pena avisar.
///
/// Cada umbral es su propio topic (`tasa-subida-1`, `tasa-subida-3`...) y el
/// Worker publica en todos los que la variación supere. Así, quien elige 3 %
/// no recibe nada cuando el dólar se mueve un 1 %, sin lógica en el cliente.
enum UmbralTasa {
  minimoPorCiento(0.1, 'minimo'),
  medioPorCiento(0.5, 'medio'),
  unoPorCiento(1, 'uno'),
  tresPorCiento(3, 'tres'),
  cincoPorCiento(5, 'cinco');

  const UmbralTasa(this.porcentaje, this.id);

  /// Variación mínima, en porcentaje.
  final double porcentaje;

  /// Sufijo del topic. Se usan palabras y no números porque los topics de FCM
  /// no admiten el punto de "0.5".
  final String id;

  String get etiqueta => switch (this) {
    UmbralTasa.minimoPorCiento => 'Cada movimiento (0,1 %)',
    UmbralTasa.medioPorCiento => 'Cambios moderados (0,5 %)',
    UmbralTasa.unoPorCiento => 'Cambios de 1 % o más',
    UmbralTasa.tresPorCiento => 'Cambios de 3 % o más',
    UmbralTasa.cincoPorCiento => 'Solo saltos grandes (5 %)',
  };

  String get descripcionCorta => switch (this) {
    UmbralTasa.minimoPorCiento =>
      'Te avisa por cualquier variación, varias veces al día',
    UmbralTasa.medioPorCiento => 'Te avisa casi a diario',
    UmbralTasa.unoPorCiento => 'Equilibrado',
    UmbralTasa.tresPorCiento => 'Solo movimientos serios',
    UmbralTasa.cincoPorCiento => 'Rara vez, solo lo grave',
  };

  static UmbralTasa desdeId(String? id) => UmbralTasa.values.firstWhere(
    (u) => u.id == id,
    orElse: () => UmbralTasa.unoPorCiento,
  );
}

/// Los cuatro avisos que puede mandar el Worker.
enum TipoAvisoTasa {
  subida,
  bajada,
  ritmo,
  resumen;

  String get emoji => switch (this) {
    TipoAvisoTasa.subida => '📈',
    TipoAvisoTasa.bajada => '📉',
    TipoAvisoTasa.ritmo => '🚀',
    TipoAvisoTasa.resumen => '☀️',
  };

  String get titulo => switch (this) {
    TipoAvisoTasa.subida => 'Cuando el dólar sube',
    TipoAvisoTasa.bajada => 'Cuando el dólar baja',
    TipoAvisoTasa.ritmo => 'Ritmo de subida',
    TipoAvisoTasa.resumen => 'Resumen de la mañana',
  };

  String get detalle => switch (this) {
    TipoAvisoTasa.subida =>
      'Aviso en cuanto la tasa suba por encima de tu umbral.',
    TipoAvisoTasa.bajada =>
      'Útil para decidir cuándo te conviene comprar mercancía.',
    TipoAvisoTasa.ritmo =>
      'Cuando la subida se acelera: varios días seguidos o una semana fuerte.',
    TipoAvisoTasa.resumen => 'Cada mañana, la tasa del día y cuánto se movió.',
  };

  /// Clave con la que se guarda en `SharedPreferences`.
  String get clavePref => 'aviso_tasa_$name';

  /// Subida y bajada dependen del umbral elegido; ritmo y resumen no, porque
  /// no nacen de una variación puntual.
  bool get usaUmbral =>
      this == TipoAvisoTasa.subida || this == TipoAvisoTasa.bajada;

  /// Topic de FCM correspondiente.
  String topic(UmbralTasa umbral) =>
      usaUmbral ? 'tasa-$name-${umbral.id}' : 'tasa-$name';
}

/// Estado completo de las preferencias.
class PreferenciasTasa {
  const PreferenciasTasa({
    this.activos = const {
      TipoAvisoTasa.subida,
      TipoAvisoTasa.bajada,
      TipoAvisoTasa.ritmo,
      TipoAvisoTasa.resumen,
    },
    this.umbral = UmbralTasa.unoPorCiento,
    this.permisoConcedido = false,
  });

  final Set<TipoAvisoTasa> activos;
  final UmbralTasa umbral;

  /// El permiso de notificaciones del sistema (Android 13+ lo pide explícito).
  /// Sin él, los topics no sirven de nada.
  final bool permisoConcedido;

  bool estaActivo(TipoAvisoTasa tipo) => activos.contains(tipo);

  /// Topics a los que debería estar suscrito el dispositivo ahora mismo.
  Set<String> get topicsDeseados => activos.map((t) => t.topic(umbral)).toSet();

  PreferenciasTasa copyWith({
    Set<TipoAvisoTasa>? activos,
    UmbralTasa? umbral,
    bool? permisoConcedido,
  }) {
    return PreferenciasTasa(
      activos: activos ?? this.activos,
      umbral: umbral ?? this.umbral,
      permisoConcedido: permisoConcedido ?? this.permisoConcedido,
    );
  }
}
