import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/presentation/libreta/libreta.dart';
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

  Future<void> _enviar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).enviarRecuperacion(_correo.text);
      if (mounted) setState(() => _enviado = true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.code == 'invalid-email'
            ? 'Ese correo no parece válido.'
            : 'No pudimos enviar el enlace. Intenta de nuevo.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Sin conexión. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _enviando = false);
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
                      ? _Enviado(correo: _correo.text.trim())
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
                                const Icon(
                                  Icons.edit_outlined,
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
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: LibretaColors.peligro,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            LibretaButton(
                              label: 'Enviar enlace',
                              loading: _enviando,
                              onPressed: puedeEnviar ? _enviar : null,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Text(
                                  '¿Lo recordaste? Volver a entrar',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: LibretaColors.textoMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
class _Enviado extends StatelessWidget {
  const _Enviado({required this.correo});

  final String correo;

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
          child: const Icon(
            Icons.check_rounded,
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
          'Revisa $correo para restablecer tu contraseña.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: LibretaColors.textoMuted),
        ),
        const SizedBox(height: 26),
        LibretaButton(
          label: 'Volver al inicio',
          height: 48,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
