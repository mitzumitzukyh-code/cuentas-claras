import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/notificaciones/push_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../domain/preferencias_tasa.dart';

/// Sección de Ajustes con los avisos de la tasa BCV.
///
/// Va aparte de `AjustesScreen` porque es preferencia del **dispositivo**, no
/// del negocio: quien las apaga las apaga en su teléfono, no para el equipo.
class AvisosTasaSeccion extends ConsumerWidget {
  const AvisosTasaSeccion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferenciasTasaProvider);
    final notifier = ref.read(preferenciasTasaProvider.notifier);

    Future<void> conAviso(Future<void> Function() accion) async {
      try {
        await accion();
      } on PushSyncException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: LibretaColors.peligro),
        );
      }
    }

    final filas = <_FilaAviso>[
      for (final tipo in TipoAvisoTasa.values)
        _FilaAviso(
          tipo: tipo,
          activo: prefs.estaActivo(tipo),
          habilitado: prefs.permisoConcedido,
          onChanged: (v) => conAviso(() => notifier.alternar(tipo, v)),
        ),
    ];
    final mostrarUmbral = prefs.permisoConcedido &&
        TipoAvisoTasa.values.where((t) => t.usaUmbral).any(prefs.estaActivo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVISOS DEL DÓLAR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: context.libreta.textoMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.libreta.superficie,
            border: Border.all(color: const Color(0x141E2A38)),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (!prefs.permisoConcedido)
                _PedirPermiso(
                  ultima: filas.isEmpty && !mostrarUmbral,
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

              for (var i = 0; i < filas.length; i++)
                _EnvolverFila(
                  ultima: i == filas.length - 1 && !mostrarUmbral,
                  child: filas[i],
                ),

              if (mostrarUmbral)
                _EnvolverFila(
                  ultima: true,
                  child: _SelectorUmbral(
                    umbral: prefs.umbral,
                    onCambiar: (u) => conAviso(() => notifier.cambiarUmbral(u)),
                    tasaActual: ref.watch(bcvRateProvider).valueOrNull?.tasa,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EnvolverFila extends StatelessWidget {
  const _EnvolverFila({required this.child, required this.ultima});

  final Widget child;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: child,
    );
  }
}

/// Aviso previo: sin el permiso del sistema, los interruptores no sirven.
class _PedirPermiso extends StatelessWidget {
  const _PedirPermiso({required this.onPedir, required this.ultima});

  final Future<void> Function() onPedir;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return _EnvolverFila(
      ultima: ultima,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activa las notificaciones',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.libreta.textoFuerte,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Necesitamos tu permiso para avisarte cuando el dólar se mueva.',
            style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
          ),
          const SizedBox(height: 10),
          LibretaButton(label: 'Permitir avisos', onPressed: onPedir),
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
    return Opacity(
      opacity: habilitado ? 1 : 0.45,
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
                    color: context.libreta.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tipo.detalle,
                  style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LibretaToggle(
            value: activo && habilitado,
            onChanged: habilitado ? onChanged : (_) {},
          ),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Desde cuánto te avisamos?',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: context.libreta.textoFuerte,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          umbral.descripcionCorta,
          style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final u in UmbralTasa.values)
              LibretaChip(
                label: u.etiqueta,
                selected: u == umbral,
                onTap: () => onCambiar(u),
              ),
          ],
        ),
        if (tasaActual != null) ...[
          const SizedBox(height: 6),
          Text(
            'Con la tasa de hoy son unos '
            'Bs ${(tasaActual! * umbral.porcentaje / 100).toStringAsFixed(2)} '
            'por dólar.',
            style: const TextStyle(fontSize: 11, color: LibretaColors.verde),
          ),
        ],
      ],
    );
  }
}
