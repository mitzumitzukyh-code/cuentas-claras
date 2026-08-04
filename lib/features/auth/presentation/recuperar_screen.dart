import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../data/auth_repository.dart';

/// Recuperar contraseña (réplica visual de `P3 · RECUPERAR`,
/// `Lote A · Identidad`).
///
/// El mockup asume un código; como el login sigue siendo correo+contraseña,
/// aquí se manda el enlace de restablecimiento de Firebase — el copy se
/// ajustó para reflejar eso. Dos estados: formulario y "Enlace enviado".
class RecuperarScreen extends ConsumerStatefulWidget {
  const RecuperarScreen({super.key});

  @override
  ConsumerState<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends ConsumerState<RecuperarScreen> {
  final _correo = TextEditingController();

  bool _enviando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  /// Reevalúa si se puede enviar y borra el aviso al corregir el correo.
  void _alEscribir() {
    setState(() => _error = null);
  }

  Future<void> _enviar() async {
    if (_enviando) return;

    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).enviarRecuperacion(_correo.text);
      if (mounted) setState(() => _enviado = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // `user-not-found` se trata como envío correcto a propósito. Antes caía
      // en el mensaje genérico, así que quien se equivocaba de correo
      // reintentaba con el mismo error para siempre, sin nada que le apuntara
      // al correo. Y responder distinto según la cuenta exista o no permite
      // averiguar quién está registrado. La pantalla de confirmación está
      // redactada para no mentir en este caso ("si ese correo tiene una
      // cuenta…").
      if (e.code == 'user-not-found') {
        setState(() => _enviado = true);
        return;
      }
      setState(() => _error = _mensajeDe(e));
    } catch (e) {
      if (mounted) {
        setState(() => _error = mensajeDeError(e, accion: 'enviar el enlace'));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _mensajeDe(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Ese correo no parece válido.';
      // Sin este caso el mensaje era "Intenta de nuevo", que es justo lo que
      // no hay que hacer cuando Firebase te está frenando por insistir.
      case 'too-many-requests':
        return 'Pediste el enlace varias veces seguidas. Espera unos minutos '
            'antes de volver a intentarlo.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      default:
        return mensajeDeError(e, accion: 'enviar el enlace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeEnviar = _correo.text.trim().contains('@');

    return Scaffold(
      backgroundColor: LibretaColors.degradadoAuth.last,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: LibretaColors.degradadoAuth,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: LibretaBackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              LibretaPaperCard(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: SingleChildScrollView(
                  child: _enviado
                      ? _Enviado(
                          correo: _correo.text.trim(),
                          onOtroCorreo: () => setState(() => _enviado = false),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: LibretaColors.verde.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.mail_outline,
                                size: 30,
                                color: LibretaColors.verde,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Recuperar acceso',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: LibretaColors.textoFuerte,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tranquilo, esto le pasa a cualquiera. Escribe '
                              'tu correo y te enviamos un enlace para volver '
                              'a entrar.',
                              style: TextStyle(
                                fontSize: 14,
                                color: LibretaColors.textoMuted,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  'respira, lo resolvemos',
                                  style: GoogleFonts.caveat(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    color: LibretaColors.verde,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const LibretaIcono(AppAssets.accEditar,
                                  size: 16,
                                  color: LibretaColors.verde,
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            LibretaInput(
                              controller: _correo,
                              label: 'Correo',
                              hint: 'tu@negocio.com',
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => _alEscribir(),
                              onSubmitted: (_) {
                                if (puedeEnviar) _enviar();
                              },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              LibretaBannerError(mensaje: _error!),
                            ],
                            const SizedBox(height: 18),
                            LibretaButton(
                              label: 'Enviar enlace',
                              loading: _enviando,
                              onPressed: puedeEnviar ? _enviar : null,
                            ),
                            Center(
                              child: LibretaEnlace(
                                texto: '¿Lo recordaste? Volver a entrar',
                                tamano: 13,
                                grosor: FontWeight.w600,
                                color: LibretaColors.textoMuted,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación tras enviar el enlace.
///
/// El texto está redactado en condicional ("si … tiene una cuenta") porque
/// aquí también se aterriza cuando el correo no existe: la pantalla no puede
/// prometer un envío que quizá no ocurrió, pero tampoco delatar qué correos
/// están registrados.
class _Enviado extends StatelessWidget {
  const _Enviado({required this.correo, required this.onOtroCorreo});

  final String correo;

  /// Vuelve al formulario. Sin esto, quien se equivocaba de correo o no veía
  /// llegar nada solo podía salir de la pantalla y empezar de cero.
  final VoidCallback onOtroCorreo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: LibretaColors.verde.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const LibretaIcono(AppAssets.accConfirmar,
            size: 34,
            color: LibretaColors.verde,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Enlace enviado',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: LibretaColors.textoFuerte,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Si $correo tiene una cuenta, ahí llega el enlace para restablecer '
          'tu contraseña.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: LibretaColors.textoMuted),
        ),
        const SizedBox(height: 8),
        const Text(
          'Si no lo ves, revisa la carpeta de spam.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: LibretaColors.textoMuted),
        ),
        const SizedBox(height: 22),
        LibretaButton(
          label: 'Volver a iniciar sesión',
          height: 48,
          onPressed: () => Navigator.of(context).pop(),
        ),
        LibretaEnlace(
          texto: 'Probar con otro correo',
          tamano: 13,
          grosor: FontWeight.w600,
          color: LibretaColors.textoMuted,
          onTap: onOtroCorreo,
        ),
      ],
    );
  }
}
