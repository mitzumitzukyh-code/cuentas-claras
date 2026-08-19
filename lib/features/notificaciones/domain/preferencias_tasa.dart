/// Preferencias de los avisos de la tasa BCV.
///
/// El reparto se hace por **topics** de FCM, no por tokens de dispositivo. Esto
/// evita mantener un registro de dispositivos en el servidor (y su problema de
/// tokens caducados): el Worker publica en el topic y Firebase reparte.
///
/// Como el filtrado por topic ocurre antes de que el aviso llegue al teléfono,
/// respeta las preferencias incluso con la app cerrada. Filtrar en el cliente no
/// serviría: el sistema ya habría mostrado la notificación.
library;

/// Topic de FCM del aviso de tasa.
///
/// Las tres franjas del día (8 am, 12 pm y 3 pm) salen por este mismo topic:
/// son el mismo dato —la tasa del día— actualizado, y el dueño lo pidió con un
/// solo interruptor. Antes había un topic por tipo de aviso (subida, bajada,
/// ritmo) y por umbral; eso se fue junto con los avisos horarios, que
/// terminaban siendo spam.
const String topicAvisoTasa = 'tasa-resumen';

/// Estado completo de las preferencias.
class PreferenciasTasa {
  const PreferenciasTasa({
    this.activos = true,
    this.permisoConcedido = false,
  });

  /// Los avisos del dólar están encendidos. Por defecto sí: quien abre la app
  /// ya dijo que los quería al conceder el permiso.
  final bool activos;

  /// El permiso de notificaciones del sistema (Android 13+ lo pide explícito).
  /// Sin él, los topics no sirven de nada.
  final bool permisoConcedido;

  PreferenciasTasa copyWith({bool? activos, bool? permisoConcedido}) {
    return PreferenciasTasa(
      activos: activos ?? this.activos,
      permisoConcedido: permisoConcedido ?? this.permisoConcedido,
    );
  }
}
