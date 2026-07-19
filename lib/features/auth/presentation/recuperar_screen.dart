import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';
import '../data/auth_repository.dart';

/// Recuperar contraseña (bloque `isRecuperar` del diseño).
///
/// Dos estados: formulario y confirmación de "Enlace enviado".
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
    final t = context.tokens;
    // El botón solo se activa con algo que parezca un correo.
    final puedeEnviar = _correo.text.trim().contains('@');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
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
              if (_enviado)
                Expanded(child: _Enviado(correo: _correo.text.trim()))
              else ...[
                Text(
                  'Recuperar contraseña',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Te enviaremos un enlace a tu correo.',
                  style: TextStyle(fontSize: 14, color: t.textSec),
                ),
                const SizedBox(height: 18),
                NeuInput(
                  controller: _correo,
                  hint: 'tu@negocio.com',
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() {}),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                NeuButton(
                  label: 'Enviar enlace',
                  loading: _enviando,
                  onPressed: puedeEnviar ? _enviar : null,
                ),
              ],
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
    final t = context.tokens;
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('✓', style: TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 16),
        Text(
          'Enlace enviado',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: t.text,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 260,
          child: Text(
            'Revisa $correo para restablecer tu contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.textSec),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 200,
          child: NeuButton(
            label: 'Volver al inicio',
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}
