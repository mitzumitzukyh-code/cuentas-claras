import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../presentation/libreta/libreta.dart';

/// Abre WhatsApp con un mensaje ya escrito.
///
/// Si hay número, va directo al chat de esa persona; si no, cae en el
/// compartir genérico del sistema para que el dueño elija a dónde mandarlo.
/// Devuelve `false` solo si no se pudo abrir nada.
Future<bool> abrirWhatsApp({required String texto, String? telefono}) async {
  final numero = (telefono ?? '').replaceAll(RegExp(r'\D'), '');
  if (numero.isNotEmpty) {
    final uri = Uri.parse(
      'https://wa.me/$numero?text=${Uri.encodeComponent(texto)}',
    );
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return true;
    }
  }
  await Share.share(texto);
  return true;
}

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
