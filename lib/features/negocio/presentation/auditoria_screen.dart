import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../data/auditoria_repository.dart';

/// Historial de auditoría — "quién hizo qué" (`Lote E · P3`).
class AuditoriaScreen extends ConsumerWidget {
  const AuditoriaScreen({super.key});

  static const _dias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  static String _tituloDia(DateTime f) {
    final hoy = DateTime.now();
    final d = DateTime(f.year, f.month, f.day);
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final dif = h.difference(d).inDays;
    if (dif == 0) return 'Hoy';
    if (dif == 1) return 'Ayer';
    return '${_dias[f.weekday - 1]} ${f.day}';
  }

  static String _hora(DateTime f) {
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    return '$h:${f.minute.toString().padLeft(2, '0')} '
        '${f.hour < 12 ? "a.m." : "p.m."}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final eventos = ref.watch(auditoriaProvider).valueOrNull ?? const [];

    final grupos = <String, List<EventoAuditoria>>{};
    for (final e in eventos) {
      grupos.putIfAbsent(_tituloDia(e.fecha), () => []).add(e);
    }

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        spiral: false,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.renglon)),
                ),
                child: Row(
                  children: [
                    LibretaBackButton(
                      oscuro: true,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Historial de auditoría',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: t.textoFuerte,
                            ),
                          ),
                          Text(
                            'quién hizo qué',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.textoMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: eventos.isEmpty
                    ? _Vacio()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          for (final dia in grupos.keys) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                bottom: 8,
                              ),
                              child: Text(
                                dia.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: t.textoMuted,
                                ),
                              ),
                            ),
                            for (final e in grupos[dia]!)
                              _FilaEvento(evento: e, hora: _hora(e.fecha)),
                          ],
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

class _FilaEvento extends StatelessWidget {
  const _FilaEvento({required this.evento, required this.hora});

  final EventoAuditoria evento;
  final String hora;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.textoFuerte.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              evento.autorNombre.isEmpty
                  ? '?'
                  : evento.autorNombre[0].toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: evento.autorNombre,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ' ${evento.accion}'),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: t.textoFuerte,
                  ),
                ),
                if (evento.detalle.isNotEmpty)
                  Text(
                    evento.detalle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: t.textoMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hora,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: t.textoMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fact_check_outlined, size: 44, color: t.textoMuted),
            const SizedBox(height: 14),
            Text(
              'Todavía no hay nada anotado',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aquí queda registrado quién anula una venta, cambia un precio '
              'o cierra la caja.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: t.textoMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
