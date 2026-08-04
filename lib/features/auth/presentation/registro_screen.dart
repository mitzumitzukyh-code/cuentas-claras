import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../perfil/presentation/legal_screen.dart';
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

  /// Los dos enlaces del pie tienen que poder abrirse: la frase de encima dice
  /// que al continuar se aceptan, y hasta ahora estaban pintados de verde y
  /// negrita sin hacer nada al tocarlos.
  late final TapGestureRecognizer _tocarTerminos;
  late final TapGestureRecognizer _tocarPrivacidad;

  @override
  void initState() {
    super.initState();
    _tocarTerminos = TapGestureRecognizer()
      ..onTap = () => LegalScreen.abrir(context, DocumentoLegal.terminos);
    _tocarPrivacidad = TapGestureRecognizer()
      ..onTap = () => LegalScreen.abrir(context, DocumentoLegal.privacidad);
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    _confirmacion.dispose();
    _tocarTerminos.dispose();
    _tocarPrivacidad.dispose();
    super.dispose();
  }

  bool get _coinciden =>
      _confirmacion.text.isNotEmpty && _contrasena.text == _confirmacion.text;

  bool get _puedeContinuar =>
      _correo.text.trim().contains('@') &&
      _contrasena.text.length >= _minimo &&
      _coinciden;

  /// Reevalúa `_puedeContinuar` y borra el aviso en cuanto se corrige algo.
  void _alEscribir() {
    setState(() => _error = null);
  }

  Future<void> _crearCuenta() async {
    // `onSubmitted` del último campo entra por aquí igual que el botón: sin la
    // guarda, pulsar "Listo" dos veces creaba dos intentos de registro.
    if (_creando) return;

    setState(() {
      _creando = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .registrarConCorreo(_correo.text, _contrasena.text);
      // Le dice al gestor de contraseñas que la cuenta se creó, para que
      // ofrezca guardarla. Es el único momento en que eso importa: el usuario
      // acaba de inventarse una contraseña y no la tiene apuntada en ningún
      // lado.
      TextInput.finishAutofillContext();
      // El router detecta la sesión nueva sin negocio y salta al onboarding.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mensajeDe(e));
    } catch (e) {
      // `registrarConCorreo` también escribe la sesión en el almacenamiento
      // seguro, así que no todo lo que falla aquí es la red: decir siempre
      // "revisa tu internet" mandaba a mirar la conexión a alguien que ya
      // tenía la cuenta creada.
      if (mounted) {
        setState(() => _error = mensajeDeError(e, accion: 'crear la cuenta'));
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
        // `e.message` viene de Firebase, en inglés y con el código técnico
        // dentro. Eso va a la consola; al usuario se le dice algo legible.
        return mensajeDeError(e, accion: 'crear la cuenta');
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
                    const LibretaLogo(size: 52, sobreOscuro: true),
                    const SizedBox(height: 8),
                    const Text(
                      'Abre tu cuaderno',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: LibretaColors.crema,
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
                  // `AutofillGroup`: sin él los `autofillHints` no arman ningún
                  // contexto y Android nunca ofrece guardar la contraseña
                  // recién creada — que es el único momento en que hace falta.
                  child: AutofillGroup(
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
                          onChanged: (_) => _alEscribir(),
                        ),
                        const SizedBox(height: 6),
                        // El correo era el único requisito sin pista: con uno
                        // mal escrito, "Crear cuenta" se quedaba gris y nada en
                        // pantalla decía por qué.
                        Text(
                          _correo.text.isEmpty ||
                                  _correo.text.trim().contains('@')
                              ? ''
                              : 'Escribe el correo completo, con arroba.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: LibretaColors.peligro,
                          ),
                        ),
                        const SizedBox(height: 10),
                        LibretaInput(
                          controller: _contrasena,
                          label: 'Crea una contraseña',
                          hint: '••••••••',
                          obscure: !_verContrasena,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _alEscribir(),
                          suffix: LibretaOjoContrasena(
                            visible: _verContrasena,
                            onTap: () => setState(
                              () => _verContrasena = !_verContrasena,
                            ),
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
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _alEscribir(),
                          onSubmitted: (_) {
                            if (_puedeContinuar) _crearCuenta();
                          },
                          suffix: LibretaOjoContrasena(
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
                          LibretaBannerError(mensaje: _error!),
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
                            children: [
                              TextSpan(
                                text: 'Términos',
                                recognizer: _tocarTerminos,
                                style: const TextStyle(
                                  color: LibretaColors.verde,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(text: ' y la '),
                              TextSpan(
                                text: 'Privacidad',
                                recognizer: _tocarPrivacidad,
                                style: const TextStyle(
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
                              LibretaEnlace(
                                texto: 'Inicia sesión',
                                tamano: 13,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
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
