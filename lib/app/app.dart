import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/auth/presentation/bloqueo_biometrico.dart';
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
  /// Se adaptan al modo claro/oscuro para que la hora/batería/señal sean
  /// siempre visibles.
  SystemUiOverlayStyle _overlay(ThemeMode mode) {
    final oscuro = mode == ThemeMode.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: oscuro ? Brightness.light : Brightness.dark,
      statusBarBrightness: oscuro ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          oscuro ? AppColors.dPageBg : AppColors.lSurface,
      systemNavigationBarIconBrightness:
          oscuro ? Brightness.light : Brightness.dark,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initError != null) {
      return MaterialApp(
        title: 'Cuenta Clara',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        home: FirebaseConfigErrorScreen(mensaje: initError!),
      );
    }

    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'Cuenta Clara',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      // Limita el escalado de texto del sistema: a más de 1.15 el layout de P4
      // se desborda. Se permite achicar/agrandar solo dentro de ese rango.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.15,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _overlay(themeMode),
          child: BloqueoBiometrico(
            child: AvisoConexion(child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
