/// Normalización de teléfonos venezolanos a E.164 sin `+`, que es lo que
/// `wa.me` necesita para abrir un chat.
///
/// El dueño anota el número como se lo dictaron: `0414-510-0255`,
/// `+58 414 5100255`, `414 5100255`. Antes se limpiaba con
/// `replaceAll(RegExp(r'\D'), '')` y se metía tal cual en la URL, así que
/// `04145100255` viajaba con el cero de marcación nacional y sin código de
/// país. WhatsApp no puede resolver ese número: en vez del chat abría el
/// selector de contactos, y con 40 clientes fiados sin agendar no había forma
/// de llegar a ninguno.
library;

/// Prefijo internacional de Venezuela.
const String prefijoVE = '58';

/// Operadoras móviles (sin el cero) y códigos de área fijos más comunes.
///
/// Se validan los móviles porque son los que reciben WhatsApp; los fijos se
/// aceptan si tienen largo de fijo, pero WhatsApp rara vez responde en ellos.
const Set<String> operadorasMovilesVE = {'412', '414', '416', '424', '426'};

/// Devuelve el número listo para `wa.me`, o `null` si no es uno válido.
///
/// Nunca lanza y nunca devuelve algo a medias: o sale un número que se puede
/// marcar, o sale `null` para que quien llama lo diga en vez de abrir WhatsApp
/// con basura.
///
/// Acepta, todos al mismo resultado `584145100255`:
/// `04145100255`, `0414-510-0255`, `+58 414 5100255`, `414 5100255`,
/// `(0414) 510 02 55`.
String? normalizarTelefonoVE(String? crudo) {
  if (crudo == null) return null;

  // Fuera todo lo que no sea dígito: espacios, guiones, paréntesis y el `+`.
  var d = crudo.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;

  // Prefijo de salida internacional marcado a mano (`00 58 …`).
  if (d.startsWith('00')) d = d.substring(2);

  if (d.startsWith(prefijoVE)) {
    // Ya viene con código de país. Puede traer además el cero nacional
    // pegado —`58 0414…`, un clásico de copiar y pegar—, que sobra.
    var resto = d.substring(prefijoVE.length);
    if (resto.startsWith('0')) resto = resto.substring(1);
    return _conPrefijo(resto);
  }

  // Cero de marcación nacional: `0414…`.
  if (d.startsWith('0')) return _conPrefijo(d.substring(1));

  // Sin cero ni código de país: `414 5100255`.
  return _conPrefijo(d);
}

/// Valida el número nacional (10 dígitos: 3 de operadora + 7 de abonado) y le
/// antepone el código de país.
String? _conPrefijo(String nacional) {
  if (nacional.length != 10) return null;
  final operadora = nacional.substring(0, 3);
  // El primer dígito de un código venezolano —móvil o fijo— es 2 o 4. Con
  // esto se descarta un número de otro país pegado sin su prefijo, que si no
  // saldría "válido" y abriría un chat con un desconocido.
  if (!operadora.startsWith('2') && !operadora.startsWith('4')) return null;
  return '$prefijoVE$nacional';
}

/// `true` si el número normalizado corresponde a una operadora móvil.
///
/// WhatsApp vive en los móviles: sirve para avisar antes de mandar un mensaje
/// a un fijo que nadie va a leer.
bool esMovilVE(String? normalizado) {
  if (normalizado == null || normalizado.length != 12) return false;
  return operadorasMovilesVE.contains(normalizado.substring(2, 5));
}
