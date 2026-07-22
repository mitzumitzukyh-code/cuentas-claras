import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';

/// `true` si el tutorial de bienvenida todavía no se le ha mostrado al usuario.
///
/// Lo observa el Dashboard para abrirlo una sola vez, la primera vez que se
/// entra tras crear el negocio. Es un `FutureProvider` (se resuelve una vez por
/// arranque), así que el Dashboard puede escucharlo sin repetir la apertura.
final tutorialPendienteProvider = FutureProvider<bool>(
  (ref) => TutorialScreen.pendiente(),
);

/// Un paso del tutorial.
typedef _Paso = ({String icono, String titulo, String detalle});

/// Tutorial de bienvenida (bloque `isTutorial` del diseño).
///
/// Se muestra una sola vez tras crear el negocio; la marca queda en
/// `SharedPreferences` para no repetirlo en cada arranque.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  static const String _clave = 'tutorial_visto';

  /// `true` si al usuario todavía no se le ha mostrado.
  static Future<bool> pendiente() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_clave) ?? false);
  }

  static Future<void> marcarVisto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_clave, true);
  }

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  int _paso = 0;

  static const List<_Paso> _pasos = [
    (
      icono: '💵',
      titulo: 'Cobra en segundos',
      detalle: 'Toca los productos o escanea su código de barras para armar la '
          'cuenta. El total sale en dólares y bolívares con la tasa BCV del día.',
    ),
    (
      icono: '📦',
      titulo: 'Tu inventario siempre claro',
      detalle: 'Agrega productos con foto, precio y stock. La app te avisa '
          'cuando algo se está agotando.',
    ),
    (
      icono: '📈',
      titulo: 'Reportes de tu negocio',
      detalle: 'Mira cuánto vendiste hoy, tus productos más vendidos y envía '
          'reportes por WhatsApp.',
    ),
    (
      icono: '⚙️',
      titulo: 'Hazla tuya',
      detalle: 'Configura tu perfil, métodos de pago y empleados en Ajustes '
          'para una mejor experiencia.',
    ),
  ];

  Future<void> _salir() async {
    await TutorialScreen.marcarVisto();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final paso = _pasos[_paso];
    final ultimo = _paso == _pasos.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _salir,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Saltar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.textSec,
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NeuCard(
                      radius: 32,
                      width: 96,
                      height: 96,
                      child: Center(
                        child: Text(
                          paso.icono,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 280,
                      child: Text(
                        paso.titulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: t.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 280,
                      child: Text(
                        paso.detalle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: t.textSec,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Puntos ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pasos.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _paso ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _paso ? AppColors.marca : t.border,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              if (!ultimo)
                NeuButton(
                  label: 'Siguiente',
                  height: 50,
                  onPressed: () => setState(() => _paso++),
                )
              else ...[
                NeuButton(
                  label: 'Empezar a vender',
                  height: 50,
                  onPressed: _salir,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
