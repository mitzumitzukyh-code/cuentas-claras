/// Escritura de CSV.
///
/// Existía ya dentro de `RespaldoService`, privado, mientras la exportación de
/// inventario de la pantalla de Mercancía se escribía a mano y sin escapar: un
/// nombre con comillas —`Tornillo 1/2"`, que en una ferretería es lo normal—
/// partía la fila y desplazaba todas las columnas siguientes. Se saca aquí
/// para que haya un solo escritor de CSV en la app y se pueda probar.
library;

/// Un valor listo para ir en una celda.
///
/// Solo se entrecomilla cuando hace falta —si lleva comillas, comas, punto y
/// coma o saltos de línea— y las comillas de dentro se doblan, que es como lo
/// manda el formato. `null` sale como celda vacía, no como la palabra `null`.
String celdaCsv(Object? valor) {
  final texto = (valor ?? '').toString();
  if (!texto.contains(RegExp(r'[",\n\r;]'))) return texto;
  return '"${texto.replaceAll('"', '""')}"';
}

/// Una tabla entera: encabezados y filas, cada celda ya escapada.
String tablaCsv(List<String> encabezados, List<List<Object?>> filas) {
  final buffer = StringBuffer()..writeln(encabezados.map(celdaCsv).join(','));
  for (final fila in filas) {
    buffer.writeln(fila.map(celdaCsv).join(','));
  }
  return buffer.toString();
}
