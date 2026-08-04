import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/telefono_ve.dart';
import '../presentation/libreta/libreta.dart';

/// Cómo terminó un intento de abrir WhatsApp.
enum ResultadoWhatsApp {
  /// Se abrió el chat de esa persona.
  chatDirecto,

  /// Se abrió WhatsApp sin destinatario (no había número que usar).
  sinDestinatario,

  /// Había algo escrito como teléfono, pero no es un número venezolano que se
  /// pueda marcar.
  telefonoInvalido,

  /// WhatsApp no está instalado: se cayó al compartir genérico.
  compartirGenerico,
}

/// Abre WhatsApp con un mensaje ya escrito.
///
/// El número se normaliza a E.164 sin `+` ([normalizarTelefonoVE]): `wa.me`
/// solo abre el chat si viene con código de país y sin el cero nacional. Con
/// `04145100255` crudo WhatsApp no resuelve a nadie y termina mostrando el
/// selector de contactos — que es exactamente lo que hacía antes.
///
/// `wa.me` abre el chat **esté o no el contacto en la agenda**, que es el caso
/// del bodeguero con cuarenta fiados y ninguno guardado.
///
/// Devuelve cómo terminó para que quien llama pueda decirlo: un teléfono que no
/// se puede marcar no se manda en silencio al selector de contactos.
Future<ResultadoWhatsApp> abrirWhatsApp({
  required String texto,
  String? telefono,
}) async {
  final teniaAlgo = (telefono ?? '').trim().isNotEmpty;
  final numero = normalizarTelefonoVE(telefono);

  if (teniaAlgo && numero == null) return ResultadoWhatsApp.telefonoInvalido;

  final uri = Uri.parse(
    numero != null
        ? 'https://wa.me/$numero?text=${Uri.encodeComponent(texto)}'
        : 'https://wa.me/?text=${Uri.encodeComponent(texto)}',
  );
  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    return numero != null
        ? ResultadoWhatsApp.chatDirecto
        : ResultadoWhatsApp.sinDestinatario;
  }
  // Sin WhatsApp instalado, el compartir genérico es lo único que queda.
  await Share.share(texto);
  return ResultadoWhatsApp.compartirGenerico;
}

/// Frase para el usuario cuando el envío no llegó al chat directo, o `null` si
/// llegó y no hay nada que decir.
String? avisoDe(ResultadoWhatsApp r) => switch (r) {
  ResultadoWhatsApp.chatDirecto => null,
  ResultadoWhatsApp.sinDestinatario => null,
  ResultadoWhatsApp.telefonoInvalido =>
    'El teléfono guardado no es un número venezolano válido. Corrígelo para '
        'escribirle directo.',
  ResultadoWhatsApp.compartirGenerico =>
    'No encontramos WhatsApp: se abrió el menú de compartir.',
};

/// Muestra el mensaje antes de mandarlo, para que se pueda editar.
///
/// Cobrarle a alguien es delicado: el tono lo pone el dueño, no la app. Un
/// mensaje que sale sin que lo hayan leído es la forma más rápida de que la
/// función deje de usarse.
Future<String?> editarMensaje(
  BuildContext context, {
  required String titulo,
  required String inicial,
  String accion = 'Enviar',
}) async {
  final ctrl = TextEditingController(text: inicial);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.libreta.papel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final t = ctx.libreta;
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Puedes cambiarlo antes de mandarlo.',
              style: TextStyle(fontSize: 12.5, color: t.textoMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 7,
              minLines: 4,
              style: TextStyle(fontSize: 14, color: t.textoFuerte),
              decoration: InputDecoration(
                filled: true,
                fillColor: t.superficie,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.renglon),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.renglon),
                ),
              ),
            ),
            const SizedBox(height: 14),
            LibretaButton(
              label: accion,
              icon: const Icon(
                Icons.send_rounded,
                size: 18,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Ahora no',
                style: TextStyle(color: t.textoMuted),
              ),
            ),
          ],
        ),
      );
    },
  );
}
