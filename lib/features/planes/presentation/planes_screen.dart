import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/presentation/libreta/libreta.dart';

/// Un plan del catálogo comercial (CLAUDE.md §6).
class _Plan {
  const _Plan({
    required this.nombre,
    required this.precio,
    required this.periodo,
    required this.beneficios,
    this.actual = false,
    this.destacado = false,
  });

  final String nombre;
  final String precio;
  final String periodo;
  final List<String> beneficios;

  final bool actual;

  /// El plan Plus lleva el degradado de marca (réplica de `P0 · PLANES`).
  final bool destacado;
}

/// Planes premium (réplica visual de `P0 · PLANES`, `Lote D · Planes y
/// Catálogo`).
///
/// Muestra la oferta pero **no cobra**: el pago va por `in_app_purchase` y
/// requiere los productos dados de alta en Google Play Console, que todavía no
/// existen. Ver el aviso al pie de la pantalla.
class PlanesScreen extends ConsumerWidget {
  const PlanesScreen({super.key});

  static const _planes = [
    _Plan(
      nombre: 'Cuenta Clara Plus',
      precio: '\$5',
      periodo: '/mes',
      destacado: true,
      // Orden del diseño (Lote D · P0) menos "Pedidos por WhatsApp
      // automáticos": describía un bot con webhook que no existe, y no se
      // puede cobrar $5 al mes por algo que la app no hace. Si algún día se
      // construye, va de primero como en el lote.
      beneficios: [
        'Catálogo y estados sin marca de agua',
        'Recordatorios de fiado automáticos',
        'Pedido a proveedor con 1 toque',
        'Reportes avanzados y respaldo en la nube',
        'Empleados ilimitados',
      ],
    ),
    _Plan(
      nombre: 'Plan gratis',
      precio: '\$0',
      periodo: '',
      actual: true,
      beneficios: [
        'Ventas, gastos e inventario',
        'Catálogo con marca de agua',
        '1 negocio · 1 empleado',
        'Sin respaldo en la nube',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tu plan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 2),
                child: Text(
                  'desbloquea más páginas de tu cuaderno',
                  style: GoogleFonts.caveat(
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    color: LibretaColors.verde,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              for (final plan in _planes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _TarjetaPlan(plan: plan),
                ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x21F2A93C),
                  border: Border.all(color: const Color(0x59F2A93C)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'El cobro todavía no está activo: falta dar de alta las '
                  'suscripciones en Google Play Console. Hasta entonces sigues '
                  'en el plan Gratis sin límites aplicados.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: LibretaColors.aviso,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cancela cuando quieras. El cobro lo hace Google Play en la '
                'moneda de tu cuenta; el monto en Bs puede variar según el '
                'cambio de Google.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.libreta.textoMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaPlan extends StatelessWidget {
  const _TarjetaPlan({required this.plan});

  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    if (plan.destacado) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: LibretaColors.degradadoMarca,
            stops: [0.0, 0.52, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x478C2F22),
              offset: Offset(0, 16),
              blurRadius: 32,
            ),
          ],
        ),
        child: Stack(
          children: [
            // La tarjeta Plus es una hoja de la libreta, no un rectángulo de
            // color: la espiral se lo recuerda.
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: 0.5,
                child: LibretaSpiralStrip(height: 14, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x2EFFFFFF),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        plan.nombre.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        plan.precio,
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        plan.periodo,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xD9FFFFFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final b in plan.beneficios)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.libreta.papel,
                        disabledBackgroundColor: context.libreta.papel,
                        foregroundColor: const Color(0xFF8C2F22),
                        disabledForegroundColor: const Color(0xFF8C2F22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Próximamente',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: context.libreta.superficie,
        border: Border.all(color: const Color(0x1A1E2A38)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plan gratis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.libreta.textoFuerte,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x1F0E9F6E),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'ACTIVO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.verde,
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Tu plan actual',
            style: TextStyle(
              fontSize: 13,
              color: context.libreta.textoMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final b in plan.beneficios)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color: context.libreta.textoMuted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.libreta.textoFuerte,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
