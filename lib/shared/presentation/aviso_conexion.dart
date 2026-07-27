import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/conectividad_provider.dart';
import 'libreta/libreta.dart';

/// Franja global que aparece arriba cuando el teléfono pierde la señal.
///
/// Va en el `builder` de `MaterialApp`, por encima de todas las pantallas:
/// antes la app se quedaba callada sin internet y el usuario no sabía por qué
/// no cargaban las fotos ni se guardaban los cambios. Al volver la señal
/// muestra "Conexión restablecida" un momento y se esconde sola.
///
/// La franja NO flota sobre la pantalla: ocupa su propio espacio en un
/// `Column` y empuja el contenido hacia abajo (la primera versión tapaba el
/// encabezado del dashboard). Mientras está visible, ella misma absorbe el
/// alto de la barra de estado y se lo quita al `MediaQuery` del contenido,
/// para que el `SafeArea` de cada pantalla no duplique ese espacio.
class AvisoConexion extends ConsumerStatefulWidget {
  const AvisoConexion({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AvisoConexion> createState() => _AvisoConexionState();
}

class _AvisoConexionState extends ConsumerState<AvisoConexion> {
  bool _visible = false;
  bool _sinConexion = false;
  Timer? _ocultarLuego;

  /// Último estado procesado. Android dispara varios eventos seguidos al
  /// reconectar (wifi, wifi+vpn…): sin este filtro, el segundo evento
  /// cancelaba el temporizador que esconde el aviso verde y "Conexión
  /// restablecida" se quedaba pegado en pantalla para siempre.
  bool? _ultimo;

  @override
  void dispose() {
    _ocultarLuego?.cancel();
    super.dispose();
  }

  void _alCambiar(bool ahora) {
    if (ahora == _ultimo) return;
    _ultimo = ahora;
    _ocultarLuego?.cancel();
    if (!ahora) {
      setState(() {
        _sinConexion = true;
        _visible = true;
      });
    } else if (_visible) {
      // Solo celebra la vuelta si el aviso de "sin conexión" estaba en
      // pantalla — al abrir la app con señal normal no hay nada que anunciar.
      setState(() => _sinConexion = false);
      _ocultarLuego = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(hayConexionProvider, (_, ahora) {
      final valor = ahora.valueOrNull;
      if (valor != null) _alCambiar(valor);
    });

    final media = MediaQuery.of(context);

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child:
              _visible
                  ? Material(
                    color: _sinConexion
                        ? LibretaColors.aviso
                        : LibretaColors.verde,
                    child: Padding(
                      // La franja se pone ella misma debajo de la barra de
                      // estado (hora, batería…) en vez de dejárselo al
                      // SafeArea de la pantalla de abajo.
                      padding: EdgeInsets.only(top: media.padding.top),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _sinConexion
                                  ? Icons.wifi_off_rounded
                                  : Icons.wifi,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _sinConexion
                                    ? 'Sin conexión — tus cambios se '
                                        'guardarán al volver la señal'
                                    : 'Conexión restablecida ✓',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child:
              _visible
                  // La franja ya gastó el alto de la barra de estado: se lo
                  // quitamos al contenido para que su SafeArea no deje un
                  // hueco vacío extra.
                  ? MediaQuery(
                    data: media.copyWith(
                      padding: media.padding.copyWith(top: 0),
                      viewPadding: media.viewPadding.copyWith(top: 0),
                    ),
                    child: widget.child,
                  )
                  : widget.child,
        ),
      ],
    );
  }
}
