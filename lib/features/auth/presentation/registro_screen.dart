import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';
import '../data/auth_repository.dart';

/// Crear cuenta (bloque `isObCreds` del diseño — "PASO 1 DE 4").
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
    final t = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: NeuIconBtn(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'PASO 1 DE 4',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.marca,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Creemos tu cuenta',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Con esto entrarás la próxima vez que abras la app.',
                        style: TextStyle(fontSize: 14, color: t.textSec),
                      ),
                      const SizedBox(height: 22),

                      NeuInput(
                        controller: _correo,
                        label: 'Correo',
                        hint: 'tu@negocio.com',
                        height: 52,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 18),

                      NeuInput(
                        controller: _contrasena,
                        label: 'Crea una contraseña',
                        hint: '••••••••',
                        height: 52,
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
                        style: TextStyle(fontSize: 12, color: t.textSec),
                      ),
                      const SizedBox(height: 18),

                      NeuInput(
                        controller: _confirmacion,
                        label: 'Confirma tu contraseña',
                        hint: '••••••••',
                        height: 52,
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
                          color: _coinciden ? AppColors.marca : AppColors.peligro,
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.peligroSuave,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.peligro,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      const Spacer(),
                      const SizedBox(height: 20),
                      NeuButton(
                        label: 'Continuar',
                        loading: _creando,
                        onPressed: _puedeContinuar ? _crearCuenta : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 20,
        color: t.textSec,
      ),
    );
  }
}
