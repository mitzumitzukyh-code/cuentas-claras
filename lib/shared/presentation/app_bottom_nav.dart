import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Pestañas de la barra inferior del diseño.
enum NavTab { inicio, cobrar, productos, perfil }

/// Barra de navegación inferior (bloque `showNav` del diseño).
///
/// Cada pestaña es un icono dentro de una "píldora" que se tiñe de verde suave
/// y crece un 8 % al estar activa.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.activa});

  final NavTab activa;

  static const double alto = 72;

  void _ir(BuildContext context, NavTab tab) {
    if (tab == activa) return;
    switch (tab) {
      case NavTab.inicio:
        context.go(Routes.dashboard);
      case NavTab.cobrar:
        context.go(Routes.cobrar);
      case NavTab.productos:
        context.go(Routes.productos);
      case NavTab.perfil:
        context.go(Routes.perfil);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // La barra de gestos del sistema va *debajo* de las pestañas: si se
    // descuenta de los 72 px la columna de cada pestaña no cabe y desborda.
    final insetInferior = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: alto + insetInferior,
      padding: EdgeInsets.only(bottom: insetInferior),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border2)),
      ),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Tab(
              icono: Icons.home_outlined,
              etiqueta: 'Inicio',
              activa: activa == NavTab.inicio,
              onTap: () => _ir(context, NavTab.inicio),
            ),
            _Tab(
              // El diseño usa un signo "$" en vez de un icono aquí.
              texto: '\$',
              etiqueta: 'Cobrar',
              activa: activa == NavTab.cobrar,
              onTap: () => _ir(context, NavTab.cobrar),
            ),
            _Tab(
              icono: Icons.grid_view_outlined,
              etiqueta: 'Productos',
              activa: activa == NavTab.productos,
              onTap: () => _ir(context, NavTab.productos),
            ),
            _Tab(
              icono: Icons.person_outline,
              etiqueta: 'Perfil',
              activa: activa == NavTab.perfil,
              onTap: () => _ir(context, NavTab.perfil),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    this.icono,
    this.texto,
    required this.etiqueta,
    required this.activa,
    required this.onTap,
  }) : assert(icono != null || texto != null, 'Se requiere icono o texto');

  final IconData? icono;
  final String? texto;
  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = activa ? AppColors.marca : t.navInactive;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: activa ? 1.08 : 1,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 30,
                decoration: BoxDecoration(
                  color: activa ? t.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: icono != null
                    ? Icon(icono, size: 20, color: color)
                    : Text(
                        texto!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
