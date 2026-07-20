import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/notificaciones/push_service.dart';
import '../../../shared/presentation/neu.dart';
import '../domain/preferencias_tasa.dart';

/// Sección de Ajustes con los avisos de la tasa BCV.
///
/// Va aparte de `AjustesScreen` porque es preferencia del **dispositivo**, no
/// del negocio: quien las apaga las apaga en su teléfono, no para el equipo.
class AvisosTasaSeccion extends ConsumerWidget {
  const AvisosTasaSeccion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final prefs = ref.watch(preferenciasTasaProvider);
    final notifier = ref.read(preferenciasTasaProvider.notifier);

    // `alternar`/`cambiarUmbral`/`pedirPermiso` pueden fallar si Google no
    // confirma la suscripción a tiempo (ver PushSyncException). El interruptor
    // ya se movió de forma optimista; esto solo avisa de que quizás no se
    // sincronizó de verdad, en vez de dejar al usuario creyendo que sí.
    Future<void> conAviso(Future<void> Function() accion) async {
      try {
        await accion();
      } on PushSyncException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.peligro),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '💵 Avisos del dólar',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.textSec,
          ),
        ),
        const SizedBox(height: 8),
        NeuCard(
          clip: true,
          child: Column(
            children: [
              if (!prefs.permisoConcedido)
                _PedirPermiso(
                  onPedir: () => conAviso(() async {
                    final ok = await notifier.pedirPermiso();
                    if (!context.mounted || ok) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Sin permiso no podemos avisarte. Puedes '
                          'concederlo en los ajustes del teléfono.',
                        ),
                      ),
                    );
                  }),
                ),

              for (final tipo in TipoAvisoTasa.values)
                _FilaAviso(
                  tipo: tipo,
                  activo: prefs.estaActivo(tipo),
                  habilitado: prefs.permisoConcedido,
                  onChanged: (v) => conAviso(() => notifier.alternar(tipo, v)),
                ),

              // El umbral solo importa si hay algún aviso que dependa de él.
              if (prefs.permisoConcedido &&
                  TipoAvisoTasa.values
                      .where((t) => t.usaUmbral)
                      .any(prefs.estaActivo))
                _SelectorUmbral(
                  umbral: prefs.umbral,
                  onCambiar: (u) => conAviso(() => notifier.cambiarUmbral(u)),
                  tasaActual: ref.watch(bcvRateProvider).valueOrNull?.tasa,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Aviso previo: sin el permiso del sistema, los interruptores no sirven.
class _PedirPermiso extends StatelessWidget {
  const _PedirPermiso({required this.onPedir});

  final Future<void> Function() onPedir;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuListTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔔 Activa las notificaciones',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: t.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Necesitamos tu permiso para avisarte cuando el dólar se mueva.',
            style: TextStyle(fontSize: 11.5, color: t.textSec),
          ),
          const SizedBox(height: 10),
          NeuButton(label: 'Permitir avisos', onPressed: onPedir),
        ],
      ),
    );
  }
}

class _FilaAviso extends StatelessWidget {
  const _FilaAviso({
    required this.tipo,
    required this.activo,
    required this.habilitado,
    required this.onChanged,
  });

  final TipoAvisoTasa tipo;
  final bool activo;
  final bool habilitado;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: habilitado ? 1 : 0.45,
      child: NeuListTile(
        child: Row(
          children: [
            Text(tipo.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipo.titulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tipo.detalle,
                    style: TextStyle(fontSize: 11.5, color: t.textSec),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            NeuToggle(
              value: activo && habilitado,
              onChanged: habilitado ? onChanged : (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorUmbral extends StatelessWidget {
  const _SelectorUmbral({
    required this.umbral,
    required this.onCambiar,
    this.tasaActual,
  });

  final UmbralTasa umbral;
  final ValueChanged<UmbralTasa> onCambiar;

  /// Para traducir el porcentaje a bolívares. `null` mientras carga la tasa.
  final double? tasaActual;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuListTile(
      divider: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Desde cuánto te avisamos?',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: t.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            umbral.descripcionCorta,
            style: TextStyle(fontSize: 11.5, color: t.textSec),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final u in UmbralTasa.values)
                NeuChip(
                  label: u.etiqueta,
                  selected: u == umbral,
                  onTap: () => onCambiar(u),
                ),
            ],
          ),
          // Traduce el porcentaje a bolívares: "3 %" no le dice nada a nadie,
          // "unos Bs 22 por dólar" sí.
          if (tasaActual != null) ...[
            const SizedBox(height: 6),
            Text(
              'Con la tasa de hoy son unos '
              'Bs ${(tasaActual! * umbral.porcentaje / 100).toStringAsFixed(2)} '
              'por dólar.',
              style: const TextStyle(fontSize: 11, color: AppColors.marca),
            ),
          ],
        ],
      ),
    );
  }
}
