import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/business/business_presets.dart';
import '../../../../core/business/business_profile.dart';
import '../../../../core/business/business_profile_provider.dart';
import '../../../../features/negocio/data/negocio_repository.dart';
import '../../../../shared/presentation/libreta/libreta.dart';

/// Los atajos del Inicio: los del perfil del negocio más los universales.
///
/// Dibuja lo que devuelve `atajosDeInicio`, quitando los que ya tienen su
/// lugar en la pantalla y los que llevan a una pantalla que este usuario no
/// puede abrir. No hay `switch` por rubro: cambiar qué ve una panadería es
/// cambiar su preset.
///
/// Si después de todos los descartes queda menos de un par, la sección no se
/// dibuja: un botón suelto bajo el de Cobrar no parece un menú de atajos,
/// parece un error de maquetación.
class GridAtajos extends ConsumerWidget {
  const GridAtajos({super.key, this.excluir = const {'cobrar'}});

  /// Ids que no se dibujan aquí porque ya tienen su lugar en la pantalla.
  /// Por defecto `cobrar`, que es el botón héroe: repetirlo como pastilla a
  /// tres dedos del botón grande solo confunde sobre cuál hay que tocar.
  final Set<String> excluir;

  /// Menos de esto y la sección entera desaparece.
  static const int _minimoParaDibujar = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atajos = [
      for (final a in atajosDeInicio(ref.watch(businessProfileProvider)))
        if (!excluir.contains(a.id) &&
            (a.permiso == null || ref.watch(puedeProvider(a.permiso!))))
          a,
    ];
    if (atajos.length < _minimoParaDibujar) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, limites) {
        // Dos columnas: con tres o cuatro atajos, una sola fila los deja tan
        // estrechos que la etiqueta se corta.
        const separacion = 10.0;
        final ancho = (limites.maxWidth - separacion) / 2;
        return Wrap(
          spacing: separacion,
          runSpacing: separacion,
          children: [
            for (final atajo in atajos)
              SizedBox(width: ancho, child: _Atajo(atajo: atajo)),
          ],
        );
      },
    );
  }
}

class _Atajo extends StatelessWidget {
  const _Atajo({required this.atajo});

  final HomeShortcut atajo;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: () => context.push(atajo.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.renglon),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            LibretaIcono(atajo.iconKey, size: 20, color: LibretaColors.verde),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                atajo.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: t.textoFuerte,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
