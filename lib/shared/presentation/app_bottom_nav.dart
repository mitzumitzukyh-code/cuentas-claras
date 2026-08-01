import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/theme/app_assets.dart';
import 'libreta/libreta.dart';
import 'permiso_requerido.dart';

/// Pestañas de la barra inferior (réplica visual de `P0 · APP SHELL`,
/// `Lote K · Navegación`): Inicio, Cobrar, Mercancía, Reportes y Más.
///
/// Se llama "Cobrar" y no "Ventas" a propósito: es exactamente lo que abre
/// (`CobrarScreen`, con ese mismo título) — "Ventas" prometía un historial
/// que esta pestaña no muestra.
enum NavTab { inicio, cobrar, productos, reportes, perfil }

/// Barra de navegación inferior, fija, con 5 pestañas.
///
/// Solo cambia de color el icono y la etiqueta al activarse — sin píldora de
/// fondo, tal como lo muestra el mockup.
class AppBottomNav extends ConsumerWidget {
  const AppBottomNav({super.key, required this.activa});

  final NavTab activa;

  static const double alto = 64;

  void _ir(BuildContext context, NavTab tab) {
    if (tab == activa) return;
    switch (tab) {
      case NavTab.inicio:
        context.go(Routes.dashboard);
      case NavTab.cobrar:
        context.go(Routes.cobrar);
      case NavTab.productos:
        context.go(Routes.productos);
      case NavTab.reportes:
        context.go(Routes.reportes);
      case NavTab.perfil:
        context.go(Routes.perfil);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    // Un vendedor sin permiso de reportes no ve la pestaña: la pantalla lo
    // rebotaría igual, y una puerta que siempre da a un muro se siente como
    // un error de la app, no como una decisión de su jefe.
    final verReportes = ref.watch(puedeProvider(Permisos.verReportes));
    // La barra de gestos del sistema va *debajo* de las pestañas: si se
    // descuenta de los 64 px la columna de cada pestaña no cabe y desborda.
    final insetInferior = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: alto + insetInferior,
      padding: EdgeInsets.only(bottom: insetInferior),
      decoration: BoxDecoration(
        color: t.papel,
        border: Border(top: BorderSide(color: t.renglon)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D1E2A38),
            offset: Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          _Tab(
            icono: AppAssets.navInicio,
            etiqueta: 'Inicio',
            activa: activa == NavTab.inicio,
            onTap: () => _ir(context, NavTab.inicio),
          ),
          _Tab(
            icono: AppAssets.navVentas,
            etiqueta: 'Cobrar',
            activa: activa == NavTab.cobrar,
            onTap: () => _ir(context, NavTab.cobrar),
          ),
          _Tab(
            icono: AppAssets.navProductos,
            etiqueta: 'Mercancía',
            activa: activa == NavTab.productos,
            onTap: () => _ir(context, NavTab.productos),
          ),
          if (verReportes)
            _Tab(
              icono: AppAssets.navReportes,
              etiqueta: 'Reportes',
              activa: activa == NavTab.reportes,
              onTap: () => _ir(context, NavTab.reportes),
            ),
          _Tab(
            icono: AppAssets.navMas,
            etiqueta: 'Más',
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
    required this.icono,
    required this.etiqueta,
    required this.activa,
    required this.onTap,
  });

  /// Ruta del SVG de `AppAssets.nav*`.
  final String icono;
  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final color = activa ? LibretaColors.verde : t.textoMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            LibretaIcono(icono, size: 21, color: color),
            const SizedBox(height: 3),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
