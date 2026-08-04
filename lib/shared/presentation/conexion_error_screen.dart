import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'libreta/libreta.dart';

/// "No pudimos conectar" — réplica visual exacta de `P5 · CONEXIÓN`
/// (`Lote F · Onboarding y Sistema`) y `P4 · SIN CONEXIÓN` (`Lote I ·
/// Estados vacíos`).
///
/// Se muestra SOLO cuando la app no logra cargar sus datos iniciales
/// (sesión/negocio) por falta de señal — es decir, dentro de
/// [SesionErrorScreen]. Una vez que la app ya cargó, perder la señal a mitad
/// de uso (por ejemplo cobrando) NO muestra esto: sigue con el banner no
/// bloqueante de [AvisoConexion], porque la app es offline-first y debe
/// poder seguir vendiendo sin internet.
class ConexionErrorScreen extends StatefulWidget {
  const ConexionErrorScreen({super.key, required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  State<ConexionErrorScreen> createState() => _ConexionErrorScreenState();
}

class _ConexionErrorScreenState extends State<ConexionErrorScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  bool _arrancado = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_arrancado) {
      _arrancado = true;
      if (!MediaQuery.of(context).disableAnimations) {
        _controlador.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Adorno: `ExcludeSemantics` para que el lector de pantalla
                // entre directo al título.
                ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _controlador,
                    builder: (context, child) {
                      final angulo =
                          math.sin(_controlador.value * 2 * math.pi) * 0.10;
                      return Transform.rotate(angle: angulo, child: child);
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        // Halo en el ámbar de superficie, icono en el de
                        // texto: dos tonos distintos a propósito.
                        color: LibretaColors.ambarSuperficie.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        size: 44,
                        color: LibretaColors.aviso,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'No pudimos conectar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.libreta.textoFuerte,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 270,
                  child: Text(
                    'Revisa tu internet e inténtalo de nuevo. Lo que '
                    'guardaste sigue a salvo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: context.libreta.textoMuted, height: 1.5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'sin prisa, aquí está todo',
                  style: GoogleFonts.caveat(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.aviso,
                  ),
                ),
                const SizedBox(height: 18),
                // A todo el ancho, como en [SesionErrorScreen] — que es quien
                // renderiza esta pantalla. `LibretaButton` solo fija el alto,
                // así que en un Column centrado se encogía al ancho de su
                // texto y el mismo botón se veía de dos tamaños según por
                // dónde entraras.
                SizedBox(
                  width: double.infinity,
                  child: LibretaButton(
                    label: 'Reintentar',
                    height: 50,
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: Colors.white,
                    ),
                    onPressed: widget.onReintentar,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
