import 'package:flutter/material.dart';

import 'libreta/libreta.dart';

/// Lo que se pinta cuando una consulta falla.
///
/// Existe porque `valueOrNull ?? const []` hacía que un error de permisos o de
/// red se viera **idéntico** a "no hay nada": la pantalla de Gastos decía "Aún
/// no registras gastos este mes · −$0,00" con el gasto ya guardado en el
/// servidor. Cargando, error y vacío son tres cosas distintas y tienen que
/// verse distintas.
///
/// El texto del error nunca sale del `toString()` de la excepción: un
/// bodeguero no sabe qué es un `ClientException` y lo único que entiende de esa
/// pantalla es que la app se rompió. El detalle técnico va a la consola.
class LibretaErrorCarga extends StatelessWidget {
  const LibretaErrorCarga({
    super.key,
    required this.onReintentar,
    this.mensaje = 'No pudimos cargar esto. Revisa tu internet e intenta de '
        'nuevo.',
    this.detalleTecnico,
  });

  /// Qué se le dice al usuario. Una frase, en su idioma, con una salida.
  final String mensaje;

  /// La excepción real. No se pinta: se registra.
  final Object? detalleTecnico;

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (detalleTecnico != null) {
      debugPrint('[carga] $detalleTecnico');
    }
    final t = context.libreta;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 30, color: t.textoMuted),
          const SizedBox(height: 12),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: t.textoFuerte,
            ),
          ),
          const SizedBox(height: 14),
          LibretaSecondaryButton(
            label: 'Reintentar',
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: onReintentar,
          ),
        ],
      ),
    );
  }
}

/// El hueco de "todavía estoy leyendo". Ni vacío ni error: en blanco y con el
/// indicador, para que nadie lea un cero que aún no se sabe si es cero.
class LibretaCargando extends StatelessWidget {
  const LibretaCargando({super.key, this.alto = 120});

  final double alto;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: alto,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: LibretaColors.verde,
          ),
        ),
      ),
    );
  }
}
