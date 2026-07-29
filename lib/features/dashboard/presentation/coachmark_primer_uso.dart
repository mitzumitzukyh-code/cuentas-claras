import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../ventas/data/venta_repository.dart';

/// ¿Falta mostrar el coachmark de primer uso? (Lote P · P1)
///
/// Se muestra una sola vez, y solo mientras el negocio no tenga ninguna venta:
/// una vez que cobró, ya sabe dónde está el botón y el aviso sería ruido.
final coachmarkPendienteProvider = Provider<bool>((ref) {
  final visto =
      ref.watch(sharedPreferencesProvider).getBool(CoachmarkPrimerUso.clave) ??
          false;
  if (visto) return false;
  // Mientras el historial carga no se decide nada: mostrarlo y esconderlo al
  // segundo siguiente es peor que esperar.
  final historial = ref.watch(historialVentasProvider);
  if (historial.isLoading || historial.hasError) return false;
  return (historial.valueOrNull ?? const []).isEmpty;
});

/// Globo que señala el botón de Cobrar la primera vez que se abre la app.
///
/// No bloquea la pantalla ni se pone encima de nada: es una nota al pie del
/// bloque de accesos. Un tutorial modal ya existe (`tutorial_screen`); esto
/// es el recordatorio suave para quien lo saltó.
class CoachmarkPrimerUso extends ConsumerStatefulWidget {
  const CoachmarkPrimerUso({super.key});

  static const String clave = 'coachmark_cobrar_visto';

  @override
  ConsumerState<CoachmarkPrimerUso> createState() => _CoachmarkPrimerUsoState();
}

class _CoachmarkPrimerUsoState extends ConsumerState<CoachmarkPrimerUso> {
  bool _cerrado = false;

  void _entendido() {
    ref.read(sharedPreferencesProvider).setBool(CoachmarkPrimerUso.clave, true);
    setState(() => _cerrado = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_cerrado || !ref.watch(coachmarkPendienteProvider)) {
      return const SizedBox.shrink();
    }

    final t = context.libreta;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0x140E9F6E),
        border: Border.all(color: const Color(0x4D0E9F6E)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.touch_app_outlined,
            size: 18,
            color: LibretaColors.verde,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toca «Cobrar» para anotar tu primera venta',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.textoFuerte,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Se suma sola al total del día.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: t.textoMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _entendido,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'Entendido',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: LibretaColors.verde,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
