import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/auth_repository.dart';
import 'recuperar_screen.dart';
import 'registro_screen.dart';

/// Pantalla 1 — Login (réplica visual de `P1 · LOGIN`, `Lote A · Identidad`).
///
/// Correo + contraseña sigue siendo el método principal (el mockup asume
/// código por WhatsApp, pero eso requiere infraestructura — Twilio/360dialog
/// — que el negocio no tiene aprobada todavía; se decidió mantener el login
/// actual y solo re-vestirlo con la estética de libreta).
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
              const Padding(
                padding: EdgeInsets.fromLTRB(26, 24, 26, 20),
                child: Column(
                  children: [
                    LibretaLogo(size: 52, sobreOscuro: true),
                    SizedBox(height: 10),
                    Text(
                      'Bienvenido de vuelta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFAF8F3),
                      ),
                    ),
                  ],
                ),
              ),
              LibretaPaperCard(
                child: SingleChildScrollView(
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
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        LibretaInput(
                          controller: _contrasena,
                          label: 'Contraseña',
                          hint: '••••••••',
                          obscure: !_verContrasena,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _iniciarSesion(),
                          suffix: GestureDetector(
                            onTap: () => setState(
                              () => _verContrasena = !_verContrasena,
                            ),
                            child: Icon(
                              _verContrasena
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                              color: LibretaColors.textoMuted,
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
                        LibretaButton(
                          label: 'Iniciar sesión',
                          loading: _entrando,
                          onPressed: _google ? null : _iniciarSesion,
                        ),

                        const SizedBox(height: 16),
                        const _Separador(texto: 'O'),
                        const SizedBox(height: 14),

                        LibretaSecondaryButton(
                          label: 'Continuar con Google',
                          onPressed:
                              _entrando || _google ? null : _continuarConGoogle,
                          icon: _google
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const _LogoGoogle(),
                        ),

                        const SizedBox(height: 18),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '¿No tienes cuenta? ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: LibretaColors.textoMuted,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegistroScreen(),
                                  ),
                                ),
                                child: const Text(
                                  'Regístrate',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: LibretaColors.verde,
                                    fontWeight: FontWeight.w800,
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
                                color: LibretaColors.verde,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
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

/// Casilla "Recordar usuario y contraseña" con el cuadrito redondeado del diseño.
class _Recordarme extends StatelessWidget {
  const _Recordarme({required this.valor, required this.onChanged});

  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
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
              color: valor ? LibretaColors.verde : LibretaColors.superficie,
              borderRadius: BorderRadius.circular(6),
              border: valor
                  ? null
                  : Border.all(color: LibretaColors.bordeSuave, width: 1.5),
            ),
            child: valor
                ? const LibretaIcono(AppAssets.accConfirmar, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          const Text(
            'Recordar usuario y contraseña',
            style: TextStyle(fontSize: 13, color: LibretaColors.textoMuted),
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
        color: LibretaColors.peligro.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        mensaje,
        style: TextStyle(
          color: LibretaColors.peligro,
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
    return Row(
      children: [
        const Expanded(child: Divider(color: LibretaColors.bordeSuave)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LibretaColors.textoMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: LibretaColors.bordeSuave)),
      ],
    );
  }
}

/// "G" de Google. Para producción, sustituir por el logo oficial según las
/// guías de marca de Google.
/// La "G" multicolor oficial de Google, dibujada a mano.
///
/// Antes era una "G" tipográfica azul dentro de un círculo — funcional, pero
/// no se reconocía como el botón de Google y transmitía menos confianza. Se
/// pinta con CustomPaint (sin assets) siguiendo la marca: cuatro segmentos de
/// arco en los colores oficiales más la barra horizontal azul.
class _LogoGoogle extends StatelessWidget {
  const _LogoGoogle();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _PintorG()),
    );
  }
}

class _PintorG extends CustomPainter {
  const _PintorG();

  static const _azul = Color(0xFF4285F4);
  static const _verde = Color(0xFF34A853);
  static const _amarillo = Color(0xFFFBBC05);
  static const _rojo = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width * 0.22;
    final centro = size.center(Offset.zero);
    final radio = (size.width - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    final pincel =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor;

    // Ángulos en radianes; 0 = derecha, sentido horario. La abertura de la
    // "G" queda arriba a la derecha, donde entra la barra azul.
    const grado = 3.14159 / 180;
    void arco(double desde, double barrido, Color color) {
      canvas.drawArc(rect, desde * grado, barrido * grado, false,
          pincel..color = color);
    }

    arco(-10, 55, _azul); // derecha, hacia abajo
    arco(45, 90, _verde); // abajo
    arco(135, 90, _amarillo); // izquierda
    arco(225, 100, _rojo); // arriba (deja la abertura a la derecha)

    // Barra horizontal azul: del centro hacia el borde derecho, a media
    // altura — el rasgo más reconocible de la "G".
    canvas.drawRect(
      Rect.fromLTWH(
        centro.dx,
        centro.dy - grosor / 2,
        radio + grosor / 2,
        grosor,
      ),
      Paint()..color = _azul,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorG oldDelegate) => false;
}
