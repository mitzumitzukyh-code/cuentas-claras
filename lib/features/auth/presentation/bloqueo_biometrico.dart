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
    // Al irse a segundo plano se vuelve a cerrar, para que el candado sirva
    // de algo cuando el teléfono cambia de manos con la app abierta.
    if (estado == AppLifecycleState.paused) {
      if (ref.read(biometriaServiceProvider).activa) {
        setState(() => _bloqueado = true);
      }
    } else if (estado == AppLifecycleState.resumed) {
      _evaluar();
    }
  }

  Future<void> _evaluar() async {
    final servicio = ref.read(biometriaServiceProvider);
    if (!servicio.activa) return;
    if (ref.read(authStateProvider).valueOrNull == null) return;
    if (!mounted) return;
    setState(() => _bloqueado = true);
    await _desbloquear();
  }

  Future<void> _desbloquear() async {
    if (_pidiendo) return;
    _pidiendo = true;
    final ok = await ref
        .read(biometriaServiceProvider)
        .pedir(motivo: 'Desbloquea Cuenta Clara');
    _pidiendo = false;
    if (!mounted) return;
    if (ok) setState(() => _bloqueado = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
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
                decoration: const BoxDecoration(
                  color: Color(0x140E9F6E),
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
