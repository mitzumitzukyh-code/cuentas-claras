import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'brand_logo.dart';

/// Pantalla de carga mientras se resuelve el estado de sesión.
///
/// Réplica del bloque `isAppLoading` del diseño: logo pulsante, nombre, spinner
/// y el texto "Cargando tu negocio…".
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();
    // `@keyframes ccPulse` — 1.4 s, ida y vuelta.
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 0.96).animate(
                CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1, end: 0.85).animate(_pulso),
                child: const BrandLogo(size: 72),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Cuenta Clara',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.text,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.marca,
                backgroundColor: t.border2,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Cargando tu negocio…',
              style: TextStyle(fontSize: 13, color: t.textSec),
            ),
          ],
        ),
      ),
    );
  }
}
