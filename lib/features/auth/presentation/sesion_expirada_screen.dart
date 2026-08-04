import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router/routes.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/auth_repository.dart';

/// "Tu sesión expiró" — réplica visual de `P4 · SESIÓN` (`Lote F · Onboarding
/// y Sistema`).
///
/// Se muestra solo cuando la app tenía sesión guardada y las credenciales
/// dejaron de servir (contraseña cambiada en otro lado, cuenta deshabilitada).
/// Aparecer en el login sin explicación hacía pensar que se habían perdido los
/// datos del negocio.
class SesionExpiradaScreen extends ConsumerStatefulWidget {
  const SesionExpiradaScreen({super.key});

  @override
  ConsumerState<SesionExpiradaScreen> createState() =>
      _SesionExpiradaScreenState();
}

class _SesionExpiradaScreenState extends ConsumerState<SesionExpiradaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  bool _arrancado = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_arrancado) {
      _arrancado = true;
      if (!MediaQuery.of(context).disableAnimations) _controlador.repeat();
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _volverAEntrar() {
    ref.read(authRepositoryProvider).sesionExpirada = false;
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;

    return Scaffold(
      backgroundColor: t.papel,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(34),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // El anillo que late: la sesión se cerró, no se rompió nada.
                // `ExcludeSemantics` porque es puro adorno — el lector de
                // pantalla tiene que llegar directo al título.
                ExcludeSemantics(
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _controlador,
                          builder: (context, _) {
                            final v = _controlador.value;
                            return Opacity(
                              opacity: (1 - v).clamp(0.0, 1.0) * 0.6,
                              child: Container(
                                width: 60 + 30 * v,
                                height: 60 + 30 * v,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: LibretaColors.verde.withValues(
                                      alpha: .4,
                                    ),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: t.bordeSuave,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.lock_clock_outlined,
                            size: 28,
                            color: t.textoFuerte,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Tu sesión expiró',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 280,
                  child: Text(
                    'Por seguridad cerramos tu sesión. Vuelve a entrar, aquí '
                    'seguimos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: t.textoMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'tus cuentas te esperan',
                  style: GoogleFonts.caveat(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
                  ),
                ),
                const SizedBox(height: 20),
                // A todo el ancho, como en [SesionErrorScreen], que es réplica
                // del mismo bloque del diseño. `LibretaButton` solo fija el
                // alto, así que en un Column centrado se encogía al ancho de su
                // texto y las dos pantallas del mismo lote no se parecían.
                SizedBox(
                  width: double.infinity,
                  child: LibretaButton(
                    label: 'Volver a entrar',
                    height: 50,
                    onPressed: _volverAEntrar,
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
