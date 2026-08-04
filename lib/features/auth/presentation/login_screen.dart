import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
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

  /// Borra el aviso en cuanto el usuario corrige algo.
  ///
  /// Antes solo se limpiaba al reintentar, así que "Correo o contraseña
  /// incorrectos" seguía en rojo mientras se escribía la corrección.
  void _limpiarError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _iniciarSesion() async {
    // La guarda va aquí y no solo en el botón: `onSubmitted` del campo de
    // contraseña entra por este mismo camino, y pulsar "Listo" dos veces
    // seguidas lanzaba dos inicios de sesión — camino directo al
    // `too-many-requests` de Firebase.
    if (_entrando || _google) return;

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
    } catch (e) {
      // No todo lo que falla aquí es la red: `iniciarSesionConCorreo` también
      // escribe la sesión en el almacenamiento seguro. Cuando esto decía
      // siempre "revisa tu internet", un fallo al guardar mandaba a revisar la
      // conexión a alguien que ya había entrado.
      if (mounted) {
        setState(() => _error = mensajeDeError(e, accion: 'iniciar sesión'));
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
      // ApiException: 10 = falta registrar el SHA-1 del APK en Firebase. Ese
      // dato es para quien compila, no para el dueño de la bodega: antes se le
      // pintaba en pantalla "falta el SHA-1 en Firebase, ver README_SETUP", y
      // ese texto viajaba dentro del APK de producción.
      debugPrint('[error] Google Sign-In → ${e.code} · ${e.message}');
      setState(() {
        _google = false;
        _error = e.code == 'sign_in_failed'
            ? 'Entrar con Google no está disponible por ahora. Usa tu correo '
                'y tu contraseña.'
            : 'No se pudo iniciar sesión con Google.';
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _google = false;
        _error = _mensajeDe(e);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _google = false;
          _error = mensajeDeError(e, accion: 'iniciar sesión con Google');
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
        // `e.message` es el texto de Firebase, en inglés y con el código
        // técnico dentro: «An internal error has occurred.
        // [ INVALID_LOGIN_CREDENTIALS ]». Eso se manda a la consola; al dueño
        // se le dice algo que pueda leer.
        return mensajeDeError(e, accion: 'iniciar sesión');
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
                        color: LibretaColors.crema,
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
                          onChanged: (_) => _limpiarError(),
                        ),
                        const SizedBox(height: 16),
                        LibretaInput(
                          controller: _contrasena,
                          label: 'Contraseña',
                          hint: '••••••••',
                          obscure: !_verContrasena,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _limpiarError(),
                          onSubmitted: (_) => _iniciarSesion(),
                          suffix: LibretaOjoContrasena(
                            visible: _verContrasena,
                            onTap: () => setState(
                              () => _verContrasena = !_verContrasena,
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
                          LibretaBannerError(mensaje: _error!),
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

                        const SizedBox(height: 6),
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
                              LibretaEnlace(
                                texto: 'Regístrate',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const RegistroScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: LibretaEnlace(
                            texto: '¿Olvidaste tu contraseña?',
                            tamano: 13,
                            grosor: FontWeight.w700,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RecuperarScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
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
    // La etiqueta la pone el texto de la fila y la acción de toque, el
    // `GestureDetector`; aquí solo se añade el estado marcado y se funden en un
    // nodo. Excluir la semántica de dentro habría dejado una casilla que se
    // anuncia pero no se puede activar.
    return MergeSemantics(
      child: Semantics(
        checked: valor,
        child: GestureDetector(
          onTap: () => onChanged(!valor),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: valor
                      ? LibretaColors.verde
                      : LibretaColors.superficie,
                  borderRadius: BorderRadius.circular(6),
                  border: valor
                      ? null
                      : Border.all(color: LibretaColors.bordeSuave, width: 1.5),
                ),
                child: valor
                    ? const LibretaIcono(
                        AppAssets.accConfirmar,
                        size: 13,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              const Text(
                'Recordar usuario y contraseña',
                style: TextStyle(fontSize: 13, color: LibretaColors.textoMuted),
              ),
            ],
          ),
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
