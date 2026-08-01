import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/routes.dart';
import '../../../core/constants/app_links.dart';
import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';

class _Pregunta {
  const _Pregunta(this.categoria, this.pregunta, this.respuesta);

  final String categoria;
  final String pregunta;
  final String respuesta;
}

/// Centro de ayuda (réplica visual de `P6 · CENTRO DE AYUDA`, `Lote E ·
/// Negocio y Perfil`).
///
/// FAQ en acordeón, agrupada por tema, con buscador que filtra en vivo y un
/// acceso directo para escribir a soporte. No había número de WhatsApp de
/// soporte configurado, así que ese contacto va por correo (CLAUDE.md §8).
class CentroAyudaScreen extends StatefulWidget {
  const CentroAyudaScreen({super.key});

  @override
  State<CentroAyudaScreen> createState() => _CentroAyudaScreenState();
}

class _CentroAyudaScreenState extends State<CentroAyudaScreen> {
  final _busqueda = TextEditingController();
  int _abierta = -1;

  static const _preguntas = [
    _Pregunta(
      'Cobros y tasa',
      '¿Cómo cobro en dólares y bolívares?',
      'Escribe el monto en dólares y la app calcula el equivalente en '
          'bolívares con la tasa activa. El cliente paga en la moneda que '
          'prefiera; el recibo muestra ambas.',
    ),
    _Pregunta(
      'Cobros y tasa',
      '¿De dónde sale la tasa BCV y Paralelo?',
      'Puedes usar la tasa del BCV (oficial) o la del Paralelo (P2P). '
          'Eliges cuál se aplica al cobrar en Ajustes › Tasa de cambio.',
    ),
    _Pregunta(
      'Cobros y tasa',
      '¿Puedo anular una venta?',
      'Sí. Abre la venta en Historial y toca «Anular venta». Solo el dueño '
          'puede hacerlo y el inventario se repone automáticamente.',
    ),
    _Pregunta(
      'Inventario',
      '¿Cómo agrego productos y su stock?',
      'Ve a Mercancía › + y agrega nombre, precio, stock y foto. También '
          'puedes escanear el código de barras para llenar los datos.',
    ),
    _Pregunta(
      'Inventario',
      'Alertas de stock bajo',
      'Cuando un producto baja de su mínimo aparece en ámbar y recibes una '
          'notificación para reponer a tiempo.',
    ),
    _Pregunta(
      'WhatsApp y pedidos',
      'Enviar mi catálogo por WhatsApp',
      'Desde Catálogo toca «Compartir por WhatsApp». Se envía como imagen '
          'con fotos, precios en \$ y Bs, y tus formas de pago activas.',
    ),
    _Pregunta(
      'WhatsApp y pedidos',
      'Publicar mis precios en el Estado',
      'Desde Estado de WhatsApp eliges una plantilla, escoges los productos '
          'y la app arma la imagen lista para subir a tu Estado.',
    ),
  ];

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _escribirSoporte() async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppLinks.correoSoporte,
      query: 'subject=${Uri.encodeComponent('Ayuda con Cuenta Clara')}',
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el correo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = _busqueda.text.trim().toLowerCase();
    final visibles = texto.isEmpty
        ? _preguntas
        : _preguntas
            .where((p) => p.pregunta.toLowerCase().contains(texto))
            .toList();

    final categorias = <String>[];
    for (final p in visibles) {
      if (!categorias.contains(p.categoria)) categorias.add(p.categoria);
    }

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Centro de ayuda',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              LibretaInput(
                controller: _busqueda,
                hint: 'Buscar en la ayuda…',
                height: 46,
                bordeVerde: true,
                leading: const LibretaIcono(AppAssets.accBuscar, size: 18, color: LibretaColors.verde),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [LibretaColors.verde, Color(0xFF0B7F58)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿No encuentras lo que buscas?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Escríbenos y te ayudamos en minutos.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xE6FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _escribirSoporte,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: LibretaColors.verde,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.mail_outline, size: 18),
                        label: const Text(
                          'Escríbenos por correo',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              for (final categoria in categorias) ...[
                const SizedBox(height: 20),
                Text(
                  categoria.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: context.libreta.textoMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: const Color(0x141E2A38)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final p in visibles.where((p) => p.categoria == categoria))
                        _FilaPregunta(
                          pregunta: p,
                          abierta: _abierta == _preguntas.indexOf(p),
                          ultima: p == visibles.where((x) => x.categoria == categoria).last,
                          onTap: () => setState(() {
                            final i = _preguntas.indexOf(p);
                            _abierta = _abierta == i ? -1 : i;
                          }),
                        ),
                    ],
                  ),
                ),
              ],

              if (visibles.isEmpty) ...[
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Sin resultados para tu búsqueda.',
                    style: TextStyle(fontSize: 14, color: context.libreta.textoMuted),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              LibretaSecondaryButton(
                label: 'Ver el tutorial de nuevo',
                onPressed: () => context.push(Routes.tutorial),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaPregunta extends StatelessWidget {
  const _FilaPregunta({
    required this.pregunta,
    required this.abierta,
    required this.ultima,
    required this.onTap,
  });

  final _Pregunta pregunta;
  final bool abierta;
  final bool ultima;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            pregunta.pregunta,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.libreta.textoFuerte,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: abierta ? 0.25 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.chevron_right,
                      size: 19,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                pregunta.respuesta,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF54656F),
                  height: 1.45,
                ),
              ),
            ),
            crossFadeState:
                abierta ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
