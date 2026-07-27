/// Enlaces públicos de la app, centralizados para no repetir la URL suelta
/// por el código.
abstract final class AppLinks {
  const AppLinks._();

  /// Página de descarga. Hoy manda a una landing en el mismo Worker (mientras
  /// la app no está en Play Store); el día que se publique, esa misma URL
  /// pasa a redirigir a la ficha de Play Store sin que haya que tocar la app
  /// ni reimprimir nada que ya se compartió.
  static const String descargar =
      'https://cuenta-clara-tasa.mitzumitzukyhs.workers.dev/descargar';

  /// Correo de soporte (CLAUDE.md §8). No hay número de WhatsApp de soporte
  /// configurado todavía, así que el Centro de ayuda usa este canal.
  static const String correoSoporte = 'soporte.cuentaclara@gmail.com';
}
