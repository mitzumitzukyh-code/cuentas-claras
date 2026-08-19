import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/notificaciones/push_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';

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
              _EnvolverFila(
                ultima: true,
                child: _FilaAviso(
                  activo: prefs.activos,
                  habilitado: prefs.permisoConcedido,
                  onChanged: (v) => conAviso(() => notifier.alternar(v)),
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

/// Aviso previo: sin el permiso del sistema, el interruptor no sirve.
class _PedirPermiso extends StatelessWidget {
  const _PedirPermiso({required this.onPedir});

  final Future<void> Function() onPedir;

  @override
  Widget build(BuildContext context) {
    return _EnvolverFila(
      ultima: false,
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
            'Necesitamos tu permiso para avisarte la tasa del día.',
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
    required this.activo,
    required this.habilitado,
    required this.onChanged,
  });

  final bool activo;
  final bool habilitado;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: habilitado ? 1 : 0.45,
      child: Row(
        children: [
          const Text('☀️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasa del día',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.libreta.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'La tasa del dólar a las 8 am, 12 pm y 3 pm. '
                  'A las 9 pm llega el resumen de tus ventas.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.libreta.textoMuted,
                  ),
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