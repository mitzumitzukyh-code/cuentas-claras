import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';

/// Escáner de código de barras. Devuelve el código leído con `Navigator.pop`.
///
/// El prototipo confirma cada lectura con vibración y un pitido (`feedbackScan`).
/// Aquí se replica con háptica + sonido del sistema, y además el marco se pone
/// verde con un check antes de cerrar, para que el usuario vea que funcionó y no
/// se quede dudando si escaneó o no.
class EscanerCodigoBarras extends StatefulWidget {
  const EscanerCodigoBarras({super.key});

  @override
  State<EscanerCodigoBarras> createState() => _EscanerCodigoBarrasState();
}

class _EscanerCodigoBarrasState extends State<EscanerCodigoBarras> {
  final _controller = MobileScannerController();

  bool _detectado = false;
  String? _codigo;

  /// Se enciende si pasa mucho rato sin leer nada, para sugerir qué hacer.
  bool _mostrarAyuda = false;
  Timer? _timerAyuda;

  @override
  void initState() {
    super.initState();
    _timerAyuda = Timer(const Duration(seconds: 8), () {
      if (mounted && !_detectado) setState(() => _mostrarAyuda = true);
    });
  }

  @override
  void dispose() {
    _timerAyuda?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_detectado) return;
    final codigo = capture.barcodes.firstOrNull?.rawValue;
    if (codigo == null || codigo.isEmpty) return;

    setState(() {
      _detectado = true;
      _codigo = codigo;
    });

    // Confirmación perceptible: vibración + clic del sistema.
    unawaited(HapticFeedback.mediumImpact());
    unawaited(SystemSound.play(SystemSoundType.click));

    // Pausa breve para que se vea el marco verde antes de cerrar.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final colorMarco = _detectado ? AppColors.marca : Colors.white;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear código'),
        actions: [
          // El icono refleja el estado real de la linterna.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, estado, _) {
              final encendida = estado.torchState == TorchState.on;
              final disponible = estado.torchState != TorchState.unavailable;
              return IconButton(
                tooltip: encendida ? 'Apagar linterna' : 'Encender linterna',
                onPressed: disponible ? () => _controller.toggleTorch() : null,
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: encendida ? AppColors.aviso : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    encendida ? Icons.flash_on : Icons.flash_off,
                    color: encendida ? Colors.black : Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            // Sin esto, un fallo de cámara o de permisos deja pantalla negra.
            errorBuilder: (context, error, _) => _ErrorCamara(error: error),
          ),

          // --- Marco guía ---
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 260,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: colorMarco, width: 3),
              borderRadius: BorderRadius.circular(12),
              color: _detectado
                  ? AppColors.marca.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: _detectado
                ? const Icon(Icons.check_circle, color: Colors.white, size: 48)
                : null,
          ),

          // --- Estado ---
          Positioned(
            bottom: 80,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _detectado
                        ? AppColors.marca
                        : Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _detectado
                        ? '✓ Código leído: $_codigo'
                        : 'Apunta al código de barras',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_mostrarAyuda && !_detectado) ...[
                  const SizedBox(height: 12),
                  Text(
                    '¿No lo lee? Acerca o aleja un poco el código, y enciende '
                    'la linterna si hay poca luz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mensaje cuando la cámara no arranca (permiso denegado, cámara ocupada…).
class _ErrorCamara extends StatelessWidget {
  const _ErrorCamara({required this.error});

  final MobileScannerException error;

  String get _mensaje {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Cuenta Clara necesita permiso de cámara para escanear. '
            'Actívalo en los ajustes del teléfono.';
      case MobileScannerErrorCode.unsupported:
        return 'Este dispositivo no soporta el escáner.';
      default:
        return 'No se pudo abrir la cámara. Ciérrala en otras apps e '
            'intenta de nuevo.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              _mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
