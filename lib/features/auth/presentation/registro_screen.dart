import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../data/auth_repository.dart';

/// Crear cuenta (réplica visual de `P2 · REGISTRO`, `Lote A · Identidad`).
///
/// Al registrarse, el usuario queda autenticado pero sin negocio, así que el
/// router lo lleva solo al onboarding para configurarlo.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _correo = TextEditingController();
  final _contrasena = TextEditingController();
  final _confirmacion = TextEditingController();

  bool _verContrasena = false;
  bool _verConfirmacion = false;
  bool _creando = false;
  String? _error;

  static const _minimo = 6;

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  bool get _coinciden =>
      _confirmacion.text.isNotEmpty && _contrasena.text == _confirmacion.text;

  bool get _puedeContinuar =>
      _correo.text.trim().contains('@') &&
      _contrasena.text.length >= _minimo &&
      _coinciden;

  Future<void> _crearCuenta() async {
    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .registrarConCorreo(_correo.text, _contrasena.text);
      // El router detecta la sesión nueva sin negocio y salta al onboarding.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mensajeDe(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos conectar. Revisa tu internet.');
      }
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  String _mensajeDe(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta. Inicia sesión.';
      case 'invalid-email':
        return 'Ese correo no parece válido.';
      case 'weak-password':
        return 'La contraseña es muy débil, usa al menos $_minimo caracteres.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'operation-not-allowed':
        return 'El registro por correo no está habilitado en Firebase.';
      default:
        return e.message ?? 'No se pudo crear la cuenta.';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: LibretaBackButton(
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const LibretaLogo(size: 52),
                    const SizedBox(height: 8),
                    const Text(
                      'Abre tu cuaderno',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFAF8F3),
                      ),
                    ),
                    Text(
                      'gratis, en un minuto',
                      style: GoogleFonts.caveat(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: LibretaColors.tagline,
                      ),
                    ),
                  ],
                ),
              ),
              LibretaPaperCard(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      LibretaInput(
                        controller: _correo,
                        label: 'Correo',
                        hint: 'tu@negocio.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      LibretaInput(
                        controller: _contrasena,
                        label: 'Crea una contraseña',
                        hint: '••••••••',
                        obscure: !_verContrasena,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        suffix: _OjoContrasena(
                          visible: _verContrasena,
                          onTap: () =>
                              setState(() => _verContrasena = !_verContrasena),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mínimo $_minimo caracteres.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: LibretaColors.textoMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LibretaInput(
                        controller: _confirmacion,
                        label: 'Confirma tu contraseña',
                        hint: '••••••••',
                        obscure: !_verConfirmacion,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (_puedeContinuar) _crearCuenta();
                        },
                        suffix: _OjoContrasena(
                          visible: _verConfirmacion,
                          onTap: () => setState(
                            () => _verConfirmacion = !_verConfirmacion,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _confirmacion.text.isEmpty
                            ? ''
                            : _coinciden
                                ? 'Las contraseñas coinciden ✓'
                                : 'Las contraseñas no coinciden',
                        style: TextStyle(
                          fontSize: 12,
                          color: _coinciden
                              ? LibretaColors.verde
                              : LibretaColors.peligro,
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: LibretaColors.peligro.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: LibretaColors.peligro,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      LibretaButton(
                        label: 'Crear cuenta',
                        loading: _creando,
                        onPressed: _puedeContinuar ? _crearCuenta : null,
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          text: 'Al continuar aceptas los ',
                          style: const TextStyle(
                            fontSize: 11,
                            color: LibretaColors.textoMuted,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Términos',
                              style: TextStyle(
                                color: LibretaColors.verde,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: ' y la '),
                            TextSpan(
                              text: 'Privacidad',
                              style: TextStyle(
                                color: LibretaColors.verde,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              '¿Ya tienes cuenta? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: LibretaColors.textoMuted,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Inicia sesión',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: LibretaColors.verde,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
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

/// Icono de mostrar/ocultar contraseña.
class _OjoContrasena extends StatelessWidget {
  const _OjoContrasena({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: LibretaColors.textoMuted,
      ),
    );
  }
}
