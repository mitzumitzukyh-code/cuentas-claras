import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/presentation/libreta/libreta.dart';

/// "¿Vienes de otra app?" (réplica visual de `P2 · MIGRAR DESDE TREINTA`,
/// `Lote K · Navegación`, generalizada sin nombrar a ningún competidor).
///
/// Explica el mismo camino de 3 pasos que "Importar inventario" (foto o
/// Excel/CSV): esta pantalla es solo el enganche para quien llega de otra
/// app de gestión de negocio.
class MigrarOtraAppScreen extends StatelessWidget {
  const MigrarOtraAppScreen({super.key});

  void _proximamente(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Muy pronto podrás importar desde Excel o CSV.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '¿Vienes de otra app?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  // Los extremos del degradado de marca, sin el tono
                  // intermedio. Estaban copiados a mano.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      LibretaColors.degradadoMarca.first,
                      LibretaColors.degradadoMarca.last,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trae tus datos contigo',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Importa tus productos y clientes desde tu app anterior en '
                      '3 pasos. Sin volver a escribir todo.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xE6FFFFFF), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _PasoMigracion(
                numero: 1,
                titulo: 'Exporta tu lista',
                detalle: 'En tu app anterior, descarga tus productos como Excel/CSV.',
              ),
              _PasoMigracion(
                numero: 2,
                titulo: 'Súbela aquí',
                detalle: 'Cuenta Clara reconoce nombres, precios y stock.',
              ),
              _PasoMigracion(
                numero: 3,
                titulo: 'Revisa y confirma',
                detalle: 'Ajusta lo que quieras y listo, ya está en tu cuaderno.',
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'te ayudamos a mudarte sin perder nada',
                  style: GoogleFonts.caveat(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: LibretaColors.verde,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              LibretaButton(
                label: 'Empezar migración',
                onPressed: () => _proximamente(context),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Lo haré después',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: t.textoMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasoMigracion extends StatelessWidget {
  const _PasoMigracion({
    required this.numero,
    required this.titulo,
    required this.detalle,
  });

  final int numero;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: LibretaColors.verde,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$numero',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.textoFuerte),
                ),
                Text(
                  detalle,
                  style: TextStyle(fontSize: 13, color: t.textoMuted, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
