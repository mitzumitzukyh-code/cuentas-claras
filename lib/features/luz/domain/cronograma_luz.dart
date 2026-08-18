/// El cronograma de cortes de luz, y lo que se le dice al dueño sobre él.
///
/// La tabla no vive aquí: la sirve el Worker (`/cronograma-luz`) y la app la
/// guarda en el teléfono. Aquí solo está lo que hay que decidir con ella, que
/// es lo único que se puede equivocar sin que nadie lo note: qué franja toca
/// hoy, y qué hora se le enseña a una persona.
///
/// **Fuera del rango del cronograma no se inventa nada.** Si el mes que viene
/// nadie sube la tabla nueva, la app se calla y lo dice. Avisar «se va a las
/// 8» cuando se fue a las 3 no es un error pequeño: es la última vez que ese
/// dueño le hace caso a un aviso de la app.
library;

/// Una franja de corte: de [desde] a [hasta], en horas del reloj de 24.
///
/// Los números son para calcular. Para leer está [comoTexto], porque nadie en
/// una bodega dice «de dieciocho a veintitrés».
class FranjaCorte {
  const FranjaCorte({required this.desde, required this.hasta});

  final int desde;
  final int hasta;

  String get comoTexto => '${hora12(desde)} a ${hora12(hasta)}';

  @override
  bool operator ==(Object other) =>
      other is FranjaCorte && other.desde == desde && other.hasta == hasta;

  @override
  int get hashCode => Object.hash(desde, hasta);
}

/// Una hora del reloj de 24 escrita como la dice la gente: `18` → «6:00 pm».
///
/// La app no enseña hora militar en ningún sitio. El cronograma impreso viene
/// en 24 h y el `zonedSchedule` necesita el número, pero eso se queda dentro.
String hora12(int hora24) {
  final h = hora24 % 24;
  final sufijo = h < 12 ? 'am' : 'pm';
  final doce = h % 12 == 0 ? 12 : h % 12;
  return '$doce:00 $sufijo';
}

/// Un día con corte: la fecha y la franja que le toca al bloque elegido.
typedef DiaConCorte = ({DateTime fecha, FranjaCorte franja});

/// El cronograma de un estado, tal como lo manda el Worker.
class CronogramaLuz {
  const CronogramaLuz({
    required this.estado,
    required this.version,
    required this.desde,
    required this.hasta,
    required this.sectores,
    required this.dias,
  });

  final String estado;

  /// Qué edición del cronograma es (`2026-08`). Sirve para saber si lo que
  /// hay guardado en el teléfono ya es de otro mes.
  final String version;

  final DateTime desde;
  final DateTime hasta;

  /// Los sectores de cada bloque, para que el dueño encuentre el suyo sin
  /// tener que buscar el papel.
  final Map<String, List<String>> sectores;

  /// `dias['2026-08-13']['A']` → la franja de ese bloque ese día.
  final Map<String, Map<String, FranjaCorte>> dias;

  List<String> get bloques => sectores.keys.toList()..sort();

  static String claveDe(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Si [fecha] cae dentro de lo que este cronograma cubre.
  bool cubre(DateTime fecha) {
    final clave = claveDe(fecha);
    return clave.compareTo(claveDe(desde)) >= 0 &&
        clave.compareTo(claveDe(hasta)) <= 0;
  }

  /// La franja que le toca a [bloque] el día [fecha], o `null` si ese día no
  /// le toca o la fecha se salió del cronograma.
  FranjaCorte? franja(DateTime fecha, String bloque) =>
      dias[claveDe(fecha)]?[bloque.toUpperCase()];

  /// Los próximos [dias] días que traen corte para [bloque], a partir de
  /// [desdeFecha] incluido. Se acaba solo cuando el cronograma se acaba: no
  /// se extrapola ni un día.
  List<DiaConCorte> proximosCortes(
    String bloque, {
    required DateTime desdeFecha,
    int dias = 7,
  }) {
    final salida = <DiaConCorte>[];
    for (var i = 0; i < dias; i++) {
      final fecha = DateTime(
        desdeFecha.year,
        desdeFecha.month,
        desdeFecha.day + i,
      );
      final f = franja(fecha, bloque);
      if (f != null) salida.add((fecha: fecha, franja: f));
    }
    return salida;
  }

  static CronogramaLuz fromJson(Map<String, dynamic> json) {
    final franjas = <String, FranjaCorte>{
      for (final f in (json['franjas'] as List? ?? const []))
        (f as Map)['id'] as String: FranjaCorte(
          desde: (f['desde'] as num).toInt(),
          hasta: (f['hasta'] as num).toInt(),
        ),
    };

    return CronogramaLuz(
      estado: json['estado'] as String? ?? '',
      version: json['version'] as String? ?? '',
      desde: DateTime.parse(json['desde'] as String),
      hasta: DateTime.parse(json['hasta'] as String),
      sectores: {
        for (final e in (json['sectores'] as Map? ?? {}).entries)
          e.key as String: [
            for (final s in (e.value as List)) s as String,
          ],
      },
      dias: {
        for (final dia in (json['dias'] as Map? ?? {}).entries)
          dia.key as String: {
            for (final b in (dia.value as Map).entries)
              if (franjas[b.value] != null)
                b.key as String: franjas[b.value as String]!,
          },
      },
    );
  }
}

/// El aviso de que hoy toca corte, ya escrito.
///
/// Lleva las DOS horas porque son las dos preguntas que se hace quien lo lee:
/// cuánto me queda, y hasta cuándo aguanto. Una sola hora obliga a ir a
/// buscar el cronograma, que es justo lo que este aviso viene a evitar.
({String titulo, String cuerpo}) avisoAntesDelCorte(FranjaCorte franja) => (
      titulo: 'Se va la luz a las ${hora12(franja.desde)}',
      cuerpo: 'Hoy te toca de ${franja.comoTexto}. '
          'Cobra lo que puedas y carga el teléfono.',
    );

/// El aviso de que ya debería haber vuelto.
///
/// No afirma que volvió —la app no tiene forma de saberlo— y por eso el
/// título dice «debería». Prometer luz que no llegó es peor que callarse.
({String titulo, String cuerpo}) avisoAlVolver(FranjaCorte franja) => (
      titulo: 'Ya debería haber vuelto la luz',
      cuerpo: 'El corte de hoy era hasta las ${hora12(franja.hasta)}.',
    );
