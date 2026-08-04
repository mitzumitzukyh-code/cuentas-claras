/// Interpreta números escritos a la venezolana: punto de miles, coma decimal.
///
/// Vive en Dart y no en el prompt de la IA a propósito: convertir `4.500,80` en
/// `4500.80` es determinista y no necesita un modelo. Pedírselo a Gemini lo
/// hacía a veces —y a veces devolvía `4.5`, o `450080`— sin forma de saber
/// cuál de las tres había pasado.
library;

/// Convierte a `double` lo que venga escrito, o `null` si no hay número.
///
/// Nunca devuelve `0` por no entender: un cero inventado en un precio es
/// mercancía regalada. Si no se puede leer, se dice que no se pudo.
///
/// Entiende:
/// - `4.500,80` → 4500.8 (miles con punto, decimal con coma)
/// - `4500,80` → 4500.8
/// - `4,500.80` → 4500.8 (alguien escribiendo a la gringa)
/// - `1.200` → 1200 (tres cifras tras el punto: son miles)
/// - `1.20` → 1.2 (una o dos cifras: es decimal)
/// - `$4,50`, `Bs 4.500,80`, `12 uds` → se ignora todo lo que no sea cifra
double? normalizarNumeroVE(Object? crudo) {
  if (crudo == null) return null;
  if (crudo is num) return crudo.toDouble();

  // Se conservan solo dígitos, separadores y el signo. Fuera símbolos de
  // moneda, unidades y espacios: "Bs 4.500,80" y "$4,50" son cifras.
  var t = crudo.toString().replaceAll(RegExp(r'[^0-9.,\-]'), '');
  if (t.isEmpty) return null;

  final negativo = t.startsWith('-');
  t = t.replaceAll('-', '');
  if (t.isEmpty) return null;

  final ultimoPunto = t.lastIndexOf('.');
  final ultimaComa = t.lastIndexOf(',');

  String normalizado;
  if (ultimoPunto >= 0 && ultimaComa >= 0) {
    // Con los dos separadores, el ÚLTIMO es el decimal. Cubre `4.500,80` y
    // también `4,500.80` sin tener que adivinar la nacionalidad de quien
    // escribió.
    final decimal = ultimoPunto > ultimaComa ? '.' : ',';
    final miles = decimal == '.' ? ',' : '.';
    normalizado = t.replaceAll(miles, '').replaceAll(decimal, '.');
  } else if (ultimaComa >= 0) {
    // Solo coma: en Venezuela es el decimal.
    normalizado = t.replaceAll(',', '.');
  } else if (ultimoPunto >= 0) {
    // Solo punto: ambiguo. Con exactamente tres cifras detrás —y más de una
    // delante— son miles (`1.200`); con una o dos, es decimal (`1.20`).
    final detras = t.length - ultimoPunto - 1;
    final variosPuntos = '.'.allMatches(t).length > 1;
    normalizado = (variosPuntos || (detras == 3 && ultimoPunto > 0))
        ? t.replaceAll('.', '')
        : t;
  } else {
    normalizado = t;
  }

  final valor = double.tryParse(normalizado);
  if (valor == null || valor.isNaN || valor.isInfinite) return null;
  return negativo ? -valor : valor;
}

/// Igual que [normalizarNumeroVE] pero descarta los que no sirven como precio
/// o como existencia: negativos y ceros.
///
/// `0` se descarta a propósito. Un precio en cero es mercancía regalada, y en
/// una lectura automática casi siempre significa "no se pudo leer", no
/// "es gratis".
double? normalizarPositivoVE(Object? crudo) {
  final v = normalizarNumeroVE(crudo);
  if (v == null || v <= 0) return null;
  return v;
}
