import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/historial_tasa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../dashboard/presentation/urgencias.dart';

const _claveLeidas = 'notificaciones_leidas_en';

/// Hasta cuándo el dueño ya vio sus notificaciones.
///
/// No hay colección de notificaciones en Firestore: se derivan del estado real
/// del negocio (fiados vencidos, stock en cero, caja sin cerrar…), así que
/// nunca queda una notificación fantasma de algo ya resuelto. Lo único que hay
/// que recordar es hasta cuándo las vio.
class NotificacionesLeidasNotifier extends StateNotifier<DateTime?> {
  NotificacionesLeidasNotifier(this._prefs)
      : super(DateTime.tryParse(_prefs.getString(_claveLeidas) ?? ''));

  final SharedPreferences _prefs;

  void marcarLeidas() {
    final ahora = DateTime.now();
    state = ahora;
    _prefs.setString(_claveLeidas, ahora.toIso8601String());
  }
}

final notificacionesLeidasProvider =
    StateNotifierProvider<NotificacionesLeidasNotifier, DateTime?>((ref) {
  return NotificacionesLeidasNotifier(ref.watch(sharedPreferencesProvider));
});

/// Notificaciones (`Lote P · P4`).
///
/// Es la lista de pendientes del Inicio, completa y agrupada por día.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final items = ref.watch(urgenciasProvider);

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        spiral: false,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.renglon)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t.textoFuerte.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 17,
                          color: t.textoFuerte,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notificaciones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: t.textoFuerte,
                        ),
                      ),
                    ),
                    if (items.isNotEmpty)
                      GestureDetector(
                        onTap: () => ref
                            .read(notificacionesLeidasProvider.notifier)
                            .marcarLeidas(),
                        child: const Text(
                          'Marcar leídas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LibretaColors.verde,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LibretaAvisoOfflineCompacto(
                    copy: 'Sin conexión — se sincroniza al volver el internet',
                  ),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const _SinNotificaciones()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          const _PostItTasa(),
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              // Tras "Marcar leídas" son las mismas cosas, pero
                              // ya vistas: el rótulo lo dice (Lote F · P3).
                              ref.watch(notificacionesLeidasProvider) == null
                                  ? 'NUEVAS'
                                  : 'ANTERIORES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: t.textoMuted,
                              ),
                            ),
                          ),
                          for (final u in items) _FilaNotificacion(urgencia: u),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaNotificacion extends ConsumerWidget {
  const _FilaNotificacion({required this.urgencia});

  final Urgencia urgencia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final leidasEn = ref.watch(notificacionesLeidasProvider);
    final noLeida =
        leidasEn == null || DateTime.now().difference(leidasEn).inHours >= 12;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
        context.push(urgencia.ruta);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.renglon)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: urgencia.grave
                    ? const Color(0x24F2A93C)
                    : const Color(0x1F0E9F6E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: LibretaIcono(
                urgencia.icono,
                size: 18,
                color:
                    urgencia.grave ? LibretaColors.aviso : LibretaColors.verde,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    urgencia.titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: t.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    urgencia.detalle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (noLeida) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: urgencia.grave
                      ? LibretaColors.aviso
                      : LibretaColors.verde,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SinNotificaciones extends StatelessWidget {
  const _SinNotificaciones();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0x140E9F6E),
                shape: BoxShape.circle,
              ),
              child: const LibretaIcono(AppAssets.accConfirmar,
                size: 30,
                color: LibretaColors.verde,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Todo al día',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No hay nada pendiente por ahora.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: t.textoMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-it de la tasa BCV (`Lote F · P3`).
///
/// Es lo único de esta pantalla que no es un pendiente: no hay nada que
/// resolver, es el dato con el que se calculan todos los precios del día. Por
/// eso va como papelito pegado y no como tarjeta de la lista.
class _PostItTasa extends ConsumerWidget {
  const _PostItTasa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialTasaProvider);
    if (historial.isEmpty) return const SizedBox.shrink();

    final hoy = historial.first;
    final ayer = historial.length > 1 ? historial[1] : null;
    final delta = ayer == null ? null : hoy.valor - ayer.valor;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Transform.rotate(
        angle: -0.017,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFCEFB4),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x241E2A38),
                offset: Offset(2, 5),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TASA BCV ACTUALIZADA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: Color(0xFF9A7B1A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    MoneyFormatter.bs(hoy.valor),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Color(0xFF1E2A38),
                    ),
                  ),
                  if (delta != null && delta.abs() >= 0.01) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${delta > 0 ? "▲" : "▼"} ${MoneyFormatter.bs(delta.abs()).replaceFirst("Bs ", "")}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: delta > 0
                            ? LibretaColors.verde
                            : LibretaColors.peligro,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                'tus precios ya están al día',
                style: GoogleFonts.caveat(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9A7B1A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
