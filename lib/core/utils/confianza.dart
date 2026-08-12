/// Cuánta certeza tiene una lectura con IA sobre un campo concreto.
///
/// Vive en `core` y no dentro del lector porque ya la usan dos dominios —el
/// importador de inventario y el de fiados— y declararla dos veces no es una
/// duplicación inocente: los dos archivos acaban importados en el mismo sitio
/// y Dart no sabe cuál `Confianza` es cuál.
///
/// Es **por campo**, no por documento: en un renglón manuscrito el nombre
/// puede leerse nítido y la cifra estar borrosa, y tratar la fila entera como
/// dudosa manda al dueño a revisar lo que ya estaba bien.
enum Confianza { alta, media, baja }

/// Interpreta el campo de confianza tal como viene del Worker.
///
/// Ante cualquier cosa que no reconozca devuelve [Confianza.media]: no es ni
/// "confía" ni "esto está mal", que son las dos formas de equivocarse aquí.
Confianza confianzaDe(Object? crudo) => switch (crudo) {
      'alta' => Confianza.alta,
      'baja' => Confianza.baja,
      _ => Confianza.media,
    };
