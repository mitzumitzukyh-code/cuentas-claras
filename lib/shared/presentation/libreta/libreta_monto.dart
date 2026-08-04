import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../features/negocio/data/negocio_repository.dart';

/// Un importe pintado según la moneda que el negocio eligió en el onboarding.
///
/// Toda la app venía escribiendo el mismo par a mano: el monto en dólares
/// grande y, debajo y en gris, el de bolívares. Eso ignoraba el paso 2 del
/// onboarding — una bodega que trabaja en bolívares leía su cifra principal en
/// una moneda que no usa para decidir nada.
///
/// Aquí manda [ModoPrecio]: `usd` deja los dólares arriba, `ves` sube los
/// bolívares, y `ambas` pinta los dos con el mismo peso en una sola línea. La
/// pantalla no necesita saber en cuál de los tres está.
///
/// La tasa sale de [tasaActivaValorProvider] y no del BCV a secas: contempla la
/// que el dueño escribió a mano y la elección entre oficial y paralela. Sin
/// tasa solo se pinta el importe en dólares, sea cual sea el modo — no hay
/// conversión posible y una cifra inventada sería peor que una ausente.
class LibretaMonto extends ConsumerWidget {
  const LibretaMonto({
    super.key,
    required this.usd,
    required this.estiloPrincipal,
    this.estiloSecundario,
    this.alineacion = CrossAxisAlignment.start,
    this.espacio = 2,
    this.maxLines,
  });

  final double usd;

  /// Estilo de la cifra grande. Es el mismo dé la moneda que dé: lo que cambia
  /// con el modo es cuál de las dos ocupa ese sitio, no cómo se ve.
  final TextStyle estiloPrincipal;

  /// Estilo de la cifra de referencia. Con `null` no se pinta la segunda
  /// línea — útil donde solo cabe una.
  final TextStyle? estiloSecundario;

  final CrossAxisAlignment alineacion;
  final double espacio;
  final int? maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoPrecioProvider);
    final tasa = ref.watch(tasaActivaValorProvider);
    final (principal, secundario) = modo.montos(usd, tasa);

    return Column(
      crossAxisAlignment: alineacion,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          principal,
          style: estiloPrincipal,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
        if (secundario != null && estiloSecundario != null) ...[
          SizedBox(height: espacio),
          Text(
            secundario,
            style: estiloSecundario,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Los dos importes ya ordenados según el modo del negocio, para donde hace
/// falta el texto y no un widget: mensajes de WhatsApp, subtítulos que se
/// interpolan dentro de una frase, recibos.
///
/// Devuelve `(principal, secundario)`, con `secundario` en `null` cuando no
/// hay tasa o cuando el modo los junta en una sola cadena.
(String, String?) montosDelNegocio(WidgetRef ref, double usd) {
  final modo = ref.watch(modoPrecioProvider);
  final tasa = ref.watch(tasaActivaValorProvider);
  return modo.montos(usd, tasa);
}
