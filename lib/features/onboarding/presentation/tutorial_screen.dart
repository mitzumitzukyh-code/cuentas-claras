import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';

/// `true` si el tutorial de bienvenida todavía no se le ha mostrado al usuario.
///
/// Lo observa el Dashboard para abrirlo una sola vez, la primera vez que se
/// entra tras crear el negocio. Es un `FutureProvider` (se resuelve una vez por
/// arranque), así que el Dashboard puede escucharlo sin repetir la apertura.
final tutorialPendienteProvider = FutureProvider<bool>(
  (ref) => TutorialScreen.pendiente(),
);

/// Un paso del tutorial.
typedef _Paso = ({String icono, String tagline, String titulo, String detalle});

/// Tutorial de bienvenida (réplica visual de `P1 · TUTORIAL`, `Lote F ·
/// Onboarding y Sistema`).
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
  /// Los puntos de abajo dibujan un carrusel, así que la pantalla tiene que
  /// comportarse como uno: se desliza con el dedo y se puede volver atrás. Con
  /// solo el botón "Siguiente", pasarse de largo no tenía vuelta.
  final _controlador = PageController();
  int _paso = 0;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _avanzar() {
    _controlador.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  static const List<_Paso> _pasos = [
    (
      icono: AppAssets.accEfectivo,
      tagline: 'este es tu cuaderno',
      titulo: 'Cobra en segundos',
      detalle: 'Toca los productos o escanea su código de barras para armar la '
          'cuenta. El total sale en dólares y bolívares con la tasa BCV del día.',
    ),
    (
      icono: AppAssets.navProductos,
      tagline: 'todo bajo control',
      titulo: 'Tu inventario siempre claro',
      detalle: 'Agrega productos con foto, precio y stock. La app te avisa '
          'cuando algo se está agotando.',
    ),
    (
      icono: AppAssets.navReportes,
      tagline: 'cuentas claras',
      titulo: 'Reportes de tu negocio',
      detalle: 'Mira cuánto vendiste hoy, tus productos más vendidos y envía '
          'reportes por WhatsApp.',
    ),
    (
      icono: AppAssets.accAjustes,
      tagline: 'a tu manera',
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
    final ultimo = _paso == _pasos.length - 1;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: LibretaColors.degradadoMarca,
            stops: [0, 0.55, 1.2],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: LibretaEnlace(
                    texto: 'Saltar',
                    tamano: 13,
                    grosor: FontWeight.w600,
                    color: Colors.white70,
                    onTap: _salir,
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _controlador,
                    itemCount: _pasos.length,
                    onPageChanged: (i) => setState(() => _paso = i),
                    itemBuilder: (context, i) => _Paso3Vista(paso: _pasos[i]),
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
                        width: i == _paso ? 22 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _paso ? Colors.white : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: ultimo ? _salir : _avanzar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LibretaColors.papel,
                      foregroundColor: LibretaColors.degradadoMarca[0],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      ultimo ? 'Empezar a vender' : 'Siguiente',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Una lámina del carrusel: icono, tagline, título y detalle.
class _Paso3Vista extends StatelessWidget {
  const _Paso3Vista({required this.paso});

  final _Paso paso;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(28),
          ),
          child: LibretaIcono(paso.icono, size: 42, color: Colors.white),
        ),
        const SizedBox(height: 22),
        Text(
          paso.tagline,
          style: GoogleFonts.caveat(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: LibretaColors.tagline,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 280,
          child: Text(
            paso.titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: 280,
          child: Text(
            paso.detalle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}
