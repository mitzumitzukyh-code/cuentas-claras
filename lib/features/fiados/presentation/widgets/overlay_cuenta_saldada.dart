import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/money_formatter.dart';
import '../../../../shared/presentation/libreta/libreta.dart';

/// La cuenta llegó a cero.
///
/// Es el único momento de toda la app donde se celebra con la cursiva de
/// marca: saldar una deuda es la buena noticia del día para las dos partes, y
/// hasta ahora no pasaba absolutamente nada — el número bajaba a $0,00 y ya.
///
/// El botón de avisar no es adorno: ese mensaje es el comprobante del cliente.
/// Previene el "yo ya te pagué" de la semana siguiente, que es de las cosas por
/// las que un bodeguero recomienda la app.
class OverlayCuentaSaldada extends StatefulWidget {
  const OverlayCuentaSaldada({
    super.key,
    required this.nombre,
    required this.saldoAFavorUSD,
    required this.onAvisar,
    required this.onCerrar,
  });

  final String nombre;

  /// Si abonó de más, cuánto le queda a favor. `0` = quedó justo en cero.
  final double saldoAFavorUSD;

  final VoidCallback onAvisar;
  final VoidCallback onCerrar;

  @override
  State<OverlayCuentaSaldada> createState() => _OverlayCuentaSaldadaState();
}

class _OverlayCuentaSaldadaState extends State<OverlayCuentaSaldada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final aFavor = widget.saldoAFavorUSD > 0;

    // Entrada suave y una sola vez. Si el sistema tiene las animaciones
    // apagadas, el `AnimationController` termina de inmediato y el contenido
    // aparece completo — no queda nada a medio dibujar.
    final entrada = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xE6102530),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: entrada,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1).animate(entrada),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: LibretaColors.verde,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        '¡Cuenta saldada!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.caveat(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        aFavor
                            ? '${widget.nombre} abonó de más: le quedan '
                                '${MoneyFormatter.usd(widget.saldoAFavorUSD)} '
                                'a favor para su próxima compra.'
                            : '${widget.nombre} no te debe nada.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: Color(0xD9FFFFFF),
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        child: LibretaButton(
                          label: 'Avisarle por WhatsApp',
                          icon: const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: widget.onAvisar,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: widget.onCerrar,
                        child: const Text(
                          'Ahora no',
                          style: TextStyle(color: Color(0xB3FFFFFF)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'El aviso le sirve de comprobante.',
                        style: TextStyle(fontSize: 12, color: t.textoMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
