import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../../../services/notificaciones/push_service.dart';

/// Empujón para activar las notificaciones cuando están apagadas.
///
/// La app pide el permiso una sola vez al arrancar; si el usuario lo niega (o
/// nunca lo concede), se queda sin avisos de tasa, ventas ni stock y no vuelve
/// a enterarse. Este aviso lo recuerda de forma amable: en el Inicio es
/// descartable (reaparece a las dos semanas, ver [PushService]); en la pantalla
/// de Notificaciones es fijo, porque quien la abre justamente quiere avisos.
///
/// "Activar" pide el permiso; si el sistema ya no muestra el diálogo —Android
/// 13+ deja de mostrarlo tras una negativa— abre directo los ajustes de
/// notificaciones de la app, que es el único camino que queda.
class AvisoNotificaciones extends ConsumerStatefulWidget {
  const AvisoNotificaciones({super.key, this.permitirDescartar = true});

  /// En el Inicio se puede descartar; en la pantalla de Notificaciones no.
  final bool permitirDescartar;

  @override
  ConsumerState<AvisoNotificaciones> createState() =>
      _AvisoNotificacionesState();
}

class _AvisoNotificacionesState extends ConsumerState<AvisoNotificaciones>
    with WidgetsBindingObserver {
  bool _descartadoLocal = false;
  bool _pidiendo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app (por ejemplo tras activar el permiso en Ajustes) se
    // reconsulta el estado real, así el aviso desaparece sin reiniciar.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permisoNotifVivoProvider);
    }
  }

  Future<void> _activar() async {
    setState(() => _pidiendo = true);
    bool concedido;
    try {
      concedido =
          await ref.read(preferenciasTasaProvider.notifier).pedirPermiso();
    } on PushSyncException {
      // El permiso pudo concederse aunque la sincronía de topics fallara.
      concedido = ref.read(preferenciasTasaProvider).permisoConcedido;
    } finally {
      if (mounted) setState(() => _pidiendo = false);
    }

    ref.invalidate(permisoNotifVivoProvider);
    // Concedido: el widget se oculta solo al reevaluar el permiso.
    if (concedido || !mounted) return;

    // El sistema no mostró el diálogo (ya se negó antes): al único lugar donde
    // se puede activar a mano. Al regresar, `didChangeAppLifecycleState`
    // reconsulta y esconde el aviso si quedó activado.
    if (Platform.isAndroid) {
      const intent = AndroidIntent(
        action: 'android.settings.APP_NOTIFICATION_SETTINGS',
        arguments: {
          'android.provider.extra.APP_PACKAGE': 'com.mitzukyhsdev.cuentaclara',
        },
      );
      await intent.launch();
    }
  }

  void _descartar() {
    ref.read(pushServiceProvider).descartarAvisoNotif();
    setState(() => _descartadoLocal = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_descartadoLocal) return const SizedBox.shrink();

    // Estado REAL del permiso (no el guardado). Mientras carga no se muestra
    // nada, para no parpadear un aviso que quizá no toque.
    final vivo = ref.watch(permisoNotifVivoProvider).valueOrNull;
    if (vivo == null || vivo) return const SizedBox.shrink();

    // En el Inicio respeta el descarte de dos semanas; en Notificaciones no.
    if (widget.permitirDescartar &&
        ref.read(pushServiceProvider).avisoNotifDescartadoReciente) {
      return const SizedBox.shrink();
    }

    final t = context.libreta;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LibretaColors.aviso.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LibretaColors.aviso.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus notificaciones están apagadas',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Actívalas para enterarte del dólar, tus ventas del día y '
                  'cuando un producto se te esté agotando.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: t.textoMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pidiendo ? null : _activar,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: LibretaColors.aviso,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child:
                            _pidiendo
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Activar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),
                    if (widget.permitirDescartar) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _descartar,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            'Ahora no',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: t.textoMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
