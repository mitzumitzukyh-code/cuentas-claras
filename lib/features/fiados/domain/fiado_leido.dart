import '../../../core/utils/confianza.dart';
import '../../../core/utils/numero_ve.dart';

/// En qué moneda están escritos los montos del cuaderno.
///
/// **Se le pregunta al dueño antes de disparar la cámara, no se deduce.** En
/// un cuaderno venezolano un «150» puede ser 150 Bs o 150 $, y las dos cosas
/// son verosímiles: confundirlas multiplica —o divide— una deuda por
/// setecientos y pico. El dueño lo sabe sin pensarlo; el modelo tendría que
/// adivinarlo. NOTAS.md ya documenta este mismo fallo en el lector de
/// inventario, donde una lista en Bs entraba multiplicada.
enum MonedaCuaderno {
  usd,
  bs;

  String get etiqueta => switch (this) {
        MonedaCuaderno.usd => 'Dólares',
        MonedaCuaderno.bs => 'Bolívares',
      };

  String get ejemplo => switch (this) {
        MonedaCuaderno.usd => 'anoté «20» y son \$20',
        MonedaCuaderno.bs => 'anoté «15.000» y son Bs 15.000',
      };
}

/// Un renglón del cuaderno tal como lo leyó la IA, ya con el monto interpretado.
class FiadoLeido {
  const FiadoLeido({
    required this.idLocal,
    required this.nombre,
    this.montoEscrito,
    this.fecha,
    this.concepto,
    this.confianzaNombre = Confianza.media,
    this.confianzaMonto = Confianza.media,
  });

  /// Identidad del renglón dentro de esta lectura, para la tabla de revisión.
  ///
  /// No viaja a Firestore ni significa nada fuera de la pantalla: existe
  /// porque el nombre es editable y no sirve de clave. Con la posición como
  /// clave, quitar un renglón del medio hacía que el de abajo heredara el
  /// campo de texto del que se acababa de borrar, y el dueño guardaba a otra
  /// persona sin notarlo.
  final int idLocal;

  final String nombre;

  /// El monto tal como está en el cuaderno, ya interpretado a número pero
  /// **todavía en la moneda del cuaderno**. `null` = no se pudo leer.
  ///
  /// Nunca 0: un cero es una deuda saldada, no una ausencia de lectura, y
  /// tratarlos igual borraría una deuda real.
  final double? montoEscrito;

  final DateTime? fecha;
  final String? concepto;
  final Confianza confianzaNombre;
  final Confianza confianzaMonto;

  /// El monto en dólares, que es como la app guarda todo.
  ///
  /// La moneda entra por parámetro y no se guarda en la fila: es una sola para
  /// toda la lectura —la que el dueño eligió antes de la foto— y repetirla en
  /// cada renglón solo abría la puerta a que dos filas de la misma tanda
  /// acabaran en monedas distintas.
  ///
  /// Con el cuaderno en bolívares hace falta la tasa; sin ella devuelve `null`
  /// en vez de colar el número en bruto, porque un «15.000» guardado como
  /// \$15.000 es una deuda inventada de cinco cifras.
  double? montoUSD({required MonedaCuaderno moneda, double? tasa}) {
    final escrito = montoEscrito;
    if (escrito == null) return null;
    if (moneda == MonedaCuaderno.usd) return escrito;
    if (tasa == null || tasa <= 0) return null;
    return escrito / tasa;
  }

  /// `true` si algo de este renglón hay que mirarlo antes de guardar.
  bool get dudoso =>
      montoEscrito == null ||
      confianzaMonto != Confianza.alta ||
      confianzaNombre != Confianza.alta;

  /// Lo que el dueño corrigió en la tabla de revisión.
  ///
  /// [sinMonto] existe porque `montoEscrito: null` no puede significar "bórralo"
  /// y "no lo toques" a la vez: sin la bandera, vaciar la casilla dejaba el
  /// monto que había leído la IA y el renglón se guardaba con la cifra que el
  /// dueño acababa de rechazar.
  ///
  /// Un campo que el dueño escribe a mano pasa a [Confianza.alta]: ya no es una
  /// lectura, es lo que él dice que dice su cuaderno.
  FiadoLeido copyWith({
    String? nombre,
    double? montoEscrito,
    bool sinMonto = false,
  }) {
    return FiadoLeido(
      idLocal: idLocal,
      nombre: nombre ?? this.nombre,
      montoEscrito: sinMonto ? null : (montoEscrito ?? this.montoEscrito),
      fecha: fecha,
      concepto: concepto,
      confianzaNombre: nombre == null ? confianzaNombre : Confianza.alta,
      confianzaMonto:
          (montoEscrito == null && !sinMonto) ? confianzaMonto : Confianza.alta,
    );
  }
}

/// Interpreta un renglón crudo del Worker.
///
/// El monto viaja como texto y se interpreta aquí con [normalizarPositivoVE]:
/// «1.500» es mil quinientos y no uno con cinco, y esa regla es determinista.
/// Pedírsela al modelo daba a veces una cosa y a veces la otra.
FiadoLeido fiadoDesdeJson(Map<String, dynamic> f, {required int idLocal}) {
  final fechaCruda = (f['fecha'] as String?)?.trim() ?? '';
  return FiadoLeido(
    idLocal: idLocal,
    nombre: ((f['nombre'] as String?) ?? '').trim(),
    montoEscrito: normalizarPositivoVE(f['monto']),
    fecha: fechaCruda.isEmpty ? null : DateTime.tryParse(fechaCruda),
    concepto: (f['concepto'] as String?)?.trim(),
    confianzaNombre: confianzaDe(f['confianzaNombre']),
    confianzaMonto: confianzaDe(f['confianzaMonto']),
  );
}

/// Junta los renglones que son la misma persona.
///
/// Un cuaderno suele traer varias anotaciones del mismo cliente —cada vez que
/// se llevó algo fiado— y lo que la app guarda es un saldo por persona. Se
/// suman, que es lo que hace el dueño con el lápiz al final de la página.
///
/// Se comparan los nombres en minúscula y sin espacios de sobra; no se intenta
/// nada más listo que eso. «Jose» y «José» quedan separados a propósito: unir
/// por parecido acabaría fundiendo a dos clientes distintos, y separar dos
/// filas de la misma persona lo arregla el dueño en la tabla de revisión en
/// dos toques, mientras que fundir a dos personas pasa desapercibido.
List<FiadoLeido> consolidarFiados(List<FiadoLeido> filas) {
  final porNombre = <String, FiadoLeido>{};
  final orden = <String>[];

  for (final fila in filas) {
    final clave = fila.nombre.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clave.isEmpty) continue;

    final previa = porNombre[clave];
    if (previa == null) {
      porNombre[clave] = fila;
      orden.add(clave);
      continue;
    }

    // Dos anotaciones de la misma persona: se suman. Si a una no se le pudo
    // leer el monto, el total queda ilegible entero — sumar solo lo que se
    // leyó daría una deuda menor que la real, y eso es plata perdida.
    final a = previa.montoEscrito;
    final b = fila.montoEscrito;
    porNombre[clave] = FiadoLeido(
      idLocal: previa.idLocal,
      nombre: previa.nombre,
      montoEscrito: (a == null || b == null) ? null : a + b,
      fecha: fila.fecha ?? previa.fecha,
      concepto: _juntarConceptos(previa.concepto, fila.concepto),
      confianzaNombre: _peor(previa.confianzaNombre, fila.confianzaNombre),
      confianzaMonto: _peor(previa.confianzaMonto, fila.confianzaMonto),
    );
  }

  return [for (final c in orden) porNombre[c]!];
}

Confianza _peor(Confianza a, Confianza b) =>
    a.index >= b.index ? a : b;

/// Junta los conceptos de dos anotaciones de la misma persona.
///
/// Un cuaderno escrito por bloques trae la deuda repartida —«3 bermudas» a un
/// precio y «más viejo» a otro—, y quedarse solo con el primero deja al dueño
/// mirando un monto sumado sin saber de dónde salió. Es la única pista que
/// tiene para reconocer el bloque en su cuaderno.
String? _juntarConceptos(String? a, String? b) {
  final uno = (a ?? '').trim();
  final dos = (b ?? '').trim();
  if (uno.isEmpty) return dos.isEmpty ? null : dos;
  if (dos.isEmpty || dos.toLowerCase() == uno.toLowerCase()) return uno;
  return '$uno · $dos';
}
