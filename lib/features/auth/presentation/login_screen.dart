import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/brand_logo.dart';
import '../../../shared/presentation/neu.dart';
import '../data/auth_repository.dart';
import 'recuperar_screen.dart';
import 'registro_screen.dart';

/// Pantalla 1 — Login (bloque `isLogin` del diseño).
///
/// Correo + contraseña como método principal, "Recordar usuario y contraseña",
/// Google como alternativa, y enlaces a registro y recuperación.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _claveCorreo = 'login_correo_recordado';
  static const _claveRecordar = 'login_recordar';

  final _correo = TextEditingController();
  final _contrasena = TextEditingController();

  bool _verContrasena = false;
  bool _recordarme = false;
  bool _entrando = false;
  bool _google = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarRecordado();
  }

  @override
  void dispose() {
    _correo.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _cargarRecordado() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recordarme = prefs.getBool(_claveRecordar) ?? false;
      if (_recordarme) _correo.text = prefs.getString(_claveCorreo) ?? '';
    });
  }

  /// Solo se guarda el correo: la contraseña nunca se persiste en el
  /// dispositivo — de eso se encarga el llavero del sistema vía autofill.
  Future<void> _guardarRecordado() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveRecordar, _recordarme);
    if (_recordarme) {
      await prefs.setString(_claveCorreo, _correo.text.trim());
    } else {
      await prefs.remove(_claveCorreo);
    }
  }

  Future<void> _iniciarSesion() async {
    final correo = _correo.text.trim();
    final contrasena = _contrasena.text;

    if (correo.isEmpty || contrasena.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }

    setState(() {
      _entrando = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .iniciarSesionConCorreo(correo, contrasena);
      await _guardarRecordado();
      // Le confirma al gestor de contraseñas que estas credenciales sirven,
      // para que ofrezca guardarlas o actualizarlas.
      TextInput.finishAutofillContext();
      // El router redirige solo al cambiar `authState`.
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _mensajeDe(e));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos conectar. Revisa tu internet.');
      }
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  Future<void> _continuarConGoogle() async {
    setState(() {
      _google = true;
      _error = null;
    });
    try {
      final cred =
          await ref.read(authRepositoryProvider).iniciarSesionConGoogle();
      // `null` = el usuario cerró el selector; no es un error.
      if (cred == null && mounted) setState(() => _google = false);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _google = false;
        // ApiException: 10 = falta registrar el SHA-1 del APK en Firebase.
        _error = e.code == 'sign_in_failed'
            ? 'Google Sign-In aún no está configurado (falta el SHA-1 en '
                'Firebase). Ver README_SETUP.'
            : 'No se pudo iniciar sesión con Google.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _google = false;
        _error = _mensajeDe(e);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _google = false;
          _error = 'No se pudo iniciar sesión. Revisa tu conexión.';
        });
      }
    }
  }

  /// Traduce los códigos de Firebase a algo que un comerciante entienda.
  String _mensajeDe(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Ese correo no parece válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'operation-not-allowed':
        return 'El acceso por correo no está habilitado en Firebase.';
      default:
        return e.message ?? 'No se pudo iniciar sesión.';
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
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 72),
                // `IntrinsicHeight` da al Column una altura determinada; sin
                // esto el `Spacer` de abajo revienta dentro del scroll.
                child: IntrinsicHeight(
                  // Sin `AutofillGroup`, el gestor de contraseñas de Android
                  // pinta los campos pero Flutter nunca recibe el texto: se
                  // veían los puntitos y aun así salía "escribe tu contraseña".
                  child: AutofillGroup(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    const Center(child: BrandLogo(size: 64)),
                    const SizedBox(height: 16),
                    Text(
                      'Cuenta Clara',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu negocio, en orden. USD y Bs a la vez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: t.textSec),
                    ),

                    // El diseño empuja el formulario al pie de la pantalla.
                    const SizedBox(height: 48),
                    const Spacer(),

                    NeuInput(
                      controller: _correo,
                      label: 'Correo o teléfono',
                      hint: 'tu@negocio.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    NeuInput(
                      controller: _contrasena,
                      label: 'Contraseña',
                      hint: '••••••••',
                      obscure: !_verContrasena,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _iniciarSesion(),
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _verContrasena = !_verContrasena),
                        child: Icon(
                          _verContrasena
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: t.textSec,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Recordarme(
                      valor: _recordarme,
                      onChanged: (v) => setState(() => _recordarme = v),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _BannerError(mensaje: _error!),
                    ],

                    const SizedBox(height: 20),
                    NeuButton(
                      label: 'Iniciar sesión',
                      loading: _entrando,
                      onPressed: _google ? null : _iniciarSesion,
                    ),

                    const SizedBox(height: 16),
                    _Separador(texto: 'O'),
                    const SizedBox(height: 14),

                    NeuSecondaryButton(
                      label: 'Continuar con Google',
                      onPressed: _entrando || _google ? null : _continuarConGoogle,
                      icon: _google
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const _LogoGoogle(),
                    ),

                    const SizedBox(height: 18),
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿No tienes cuenta? ',
                            style: TextStyle(fontSize: 14, color: t.textSec),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegistroScreen(),
                              ),
                            ),
                            child: const Text(
                              'Crea una',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.marca,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RecuperarScreen(),
                          ),
                        ),
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.marca,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                    ),
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

/// Casilla "Recordar usuario y contraseña" con el cuadrito redondeado del diseño.
class _Recordarme extends StatelessWidget {
  const _Recordarme({required this.valor, required this.onChanged});

  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: () => onChanged(!valor),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: valor ? AppColors.marca : t.chip,
              borderRadius: BorderRadius.circular(6),
            ),
            child: valor
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Recordar usuario y contraseña',
            style: TextStyle(fontSize: 13, color: t.textSec),
          ),
        ],
      ),
    );
  }
}

/// Banner rojo suave de error de credenciales.
class _BannerError extends StatelessWidget {
  const _BannerError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.peligroSuave,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(
          color: AppColors.peligro,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Línea divisoria con una palabra al centro.
class _Separador extends StatelessWidget {
  const _Separador({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: t.border2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.textSec,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: t.border2)),
      ],
    );
  }
}

/// "G" de Google. Para producción, sustituir por el logo oficial según las
/// guías de marca de Google.
class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: t.border),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w800,
          fontSize: 12,
          height: 1,
        ),
      ),
    );
  }
}
