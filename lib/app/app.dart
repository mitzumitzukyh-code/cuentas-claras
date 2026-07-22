import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../shared/presentation/aviso_conexion.dart';
import '../shared/presentation/firebase_config_error_screen.dart';
import 'router/app_router.dart';

/// Widget raíz de Cuenta Clara.
class CuentaClaraApp extends ConsumerWidget {
  const CuentaClaraApp({super.key, this.initError});

  /// Mensaje de error si `Firebase.initializeApp` falló en `main()`.
  final String? initError;

  /// Iconos de la barra de estado y de navegación del sistema.
  ///
  /// El fondo de la app es claro, así que los iconos deben ser oscuros para
  /// verse (y al revés en modo oscuro). Sin esto Android hereda el estilo de la
  /// app anterior y la hora/batería/señal quedan invisibles.
  SystemUiOverlayStyle _overlay(bool oscuro) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: oscuro ? Brightness.light : Brightness.dark,
      statusBarBrightness: oscuro ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          oscuro ? AppColors.dSurface : AppColors.lSurface,
      systemNavigationBarIconBrightness:
          oscuro ? Brightness.light : Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(themeModeProvider);

    if (initError != null) {
      return MaterialApp(
        title: 'Cuenta Clara',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: modo,
        debugShowCheckedModeBanner: false,
        home: FirebaseConfigErrorScreen(mensaje: initError!),
      );
    }

    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Cuenta Clara',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: modo,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlay(modo == ThemeMode.dark),
        child: AvisoConexion(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
