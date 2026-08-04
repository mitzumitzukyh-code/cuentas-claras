import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// Se muestra si Firebase no pudo inicializarse.
///
/// En desarrollo casi siempre es que falta ejecutar `flutterfire configure`
/// (ver `README_SETUP.md`), y por eso la pantalla nació con las instrucciones
/// y la excepción a la vista. Pero el `catch` de `main()` es genérico: en un
/// teléfono real cualquier fallo de arranque cae aquí, y entonces el dueño de
/// la bodega leía "ejecuta flutterfire configure para generar
/// firebase_options.dart" — que no le dice nada y no puede hacer.
///
/// Así que el detalle técnico se muestra solo en debug. En release se explica
/// lo único accionable que hay: reabrir la app, y si sigue, reinstalarla.
class FirebaseConfigErrorScreen extends StatelessWidget {
  const FirebaseConfigErrorScreen({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    debugPrint('[error] Firebase.initializeApp → $mensaje');

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 56, color: AppColors.aviso),
                const SizedBox(height: 16),
                Text(
                  kDebugMode
                      ? 'Firebase no está configurado'
                      : 'No pudimos abrir la app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  kDebugMode
                      ? 'Ejecuta `flutterfire configure` para generar '
                          'firebase_options.dart y conectar el proyecto.\n'
                          'Consulta README_SETUP.md.'
                      : 'Algo falló al arrancar. Cierra la app y vuelve a '
                          'abrirla. Si sigue igual, desinstálala e instálala '
                          'de nuevo — tus datos están guardados en tu cuenta, '
                          'no en el teléfono.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSec),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 20),
                  Text(
                    mensaje,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: t.textSec),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
