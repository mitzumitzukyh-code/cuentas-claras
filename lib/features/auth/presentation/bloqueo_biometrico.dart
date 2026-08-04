import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../data/auth_repository.dart';
import '../data/biometria_service.dart';

/// Candado de huella/rostro sobre la app ya abierta (`Lote A · F7`).
///
/// Aparece al arrancar y cada vez que la app vuelve del segundo plano, si el
/// dueño lo activó y hay sesión. No sustituye al login: la sesión de Firebase
/// sigue viva detrás — esto solo tapa la pantalla.
///
/// Si no hay sesión no hace nada: en el login no hay nada que proteger, y
/// pedir huella ahí dejaría fuera a quien todavía no ha entrado.
class BloqueoBiometrico extends ConsumerStatefulWidget {
  const BloqueoBiometrico({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BloqueoBiometrico> createState() => _BloqueoBiometricoState();
}

class _BloqueoBiometricoState extends ConsumerState<BloqueoBiometrico>
    with WidgetsBindingObserver {
  bool _bloqueado = false;
  bool _pidiendo = false;

  /// Cuándo se desbloqueó por última vez.
  ///
  /// El diálogo de huella devuelve el foco a la app, y ese `resumed` llega por
  /// el canal de plataforma sin orden garantizado respecto al `await` que lo
  /// esperaba. Si llega justo después de bajar [_pidiendo], `_evaluar` volvería
  /// a cerrar el candado y a pedir la huella otra vez, en bucle. Un desbloqueo
  /// recién hecho invalida el siguiente `resumed`.
  DateTime? _desbloqueadoEn;

  bool get _recienDesbloqueado {
    final t = _desbloqueadoEn;
    return t != null &&
        DateTime.now().difference(t) < const Duration(seconds: 2);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // El propio diálogo de huella le quita el foco a la app y dispara estos
    // mismos eventos. Sin esta guarda, taparíamos y volveríamos a pedir la
    // huella encima de la huella que ya se está pidiendo.
    if (_pidiendo) return;

    switch (estado) {
      // Se cierra ya en `inactive`, no solo en `paused`. Android toma la
      // miniatura del conmutador de tareas cuando la app pierde el foco, y
      // eso ocurre *antes* de `paused`: cerrando solo ahí, la miniatura salía
      // con las ventas del día a la vista. Que es exactamente el momento que
      // este candado existe para tapar — el teléfono cambiando de manos con
      // la app abierta.
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (ref.read(biometriaServiceProvider).activa) {
          setState(() => _bloqueado = true);
        }
      case AppLifecycleState.resumed:
        _evaluar();
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _evaluar() async {
    final servicio = ref.read(biometriaServiceProvider);
    if (!servicio.activa) return;
    if (ref.read(authStateProvider).valueOrNull == null) return;
    // El `resumed` que sigue al propio desbloqueo no vuelve a cerrar nada.
    if (_pidiendo || _recienDesbloqueado) return;
    if (!mounted) return;
    setState(() => _bloqueado = true);
    await _desbloquear();
  }

  Future<void> _desbloquear() async {
    if (_pidiendo) return;
    _pidiendo = true;
    try {
      final ok = await ref
          .read(biometriaServiceProvider)
          .pedir(motivo: 'Desbloquea Cuenta Clara');
      if (ok) _desbloqueadoEn = DateTime.now();
      if (!mounted) return;
      if (ok) setState(() => _bloqueado = false);
    } finally {
      // En `finally` y no en línea recta: `BiometriaService.pedir` captura
      // `PlatformException`, pero cualquier otra excepción dejaba la bandera
      // en `true` para siempre. A partir de ahí "Desbloquear" no hacía nada
      // y, con el candado puesto, la app quedaba inservible hasta reiniciarla.
      _pidiendo = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // `authStateProvider` puede tardar en emitir su primer valor incluso con
    // sesión ya guardada (Firebase recarga las credenciales de forma
    // asíncrona). Si el primer frame corre antes de eso, `_evaluar` —llamado
    // una sola vez desde `initState`— ve "sin sesión" y nunca vuelve a
    // intentarlo: la app abría de una, sin pedir huella, en un arranque en
    // frío. Esto reintenta en cuanto la sesión de verdad aparece.
    ref.listen(authStateProvider, (_, actual) {
      if (actual.valueOrNull != null) _evaluar();
    });
    return Stack(
      children: [
        // El candado tapa la app en pantalla, pero en un `Stack` lo de debajo
        // sigue en el árbol de semántica: con el bloqueo puesto, un lector de
        // pantalla podía ir leyendo el Dashboard de atrás. Es exactamente lo
        // que esta pantalla existe para esconder.
        ExcludeSemantics(excluding: _bloqueado, child: widget.child),
        if (_bloqueado)
          Positioned.fill(
            child: _Pantalla(onReintentar: _desbloquear),
          ),
      ],
    );
  }
}

class _Pantalla extends StatelessWidget {
  const _Pantalla({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Material(
      color: t.papel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LibretaColors.verde.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  size: 38,
                  color: LibretaColors.verde,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Cuenta Clara está bloqueada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: t.textoFuerte,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Usa tu huella o rostro para volver a entrar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: t.textoMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: LibretaButton(
                  label: 'Desbloquear',
                  icon: const Icon(
                    Icons.fingerprint_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                  onPressed: onReintentar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
