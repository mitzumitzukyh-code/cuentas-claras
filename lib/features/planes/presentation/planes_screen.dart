import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';

/// Un plan del catálogo comercial (CLAUDE.md §6).
class _Plan {
  const _Plan({
    required this.nombre,
    required this.precio,
    required this.periodo,
    required this.beneficios,
    this.etiqueta,
    this.actual = false,
  });

  final String nombre;
  final String precio;
  final String periodo;
  final List<String> beneficios;

  /// Insignia flotante ("Más popular").
  final String? etiqueta;

  final bool actual;
}

/// Planes premium (bloque `isPlanes` del diseño).
///
/// Muestra la oferta pero **no cobra**: el pago va por `in_app_purchase` y
/// requiere los productos dados de alta en Google Play Console, que todavía no
/// existen. Ver el aviso al pie de la pantalla.
class PlanesScreen extends ConsumerWidget {
  const PlanesScreen({super.key});

  static const _planes = [
    _Plan(
      nombre: 'Gratis',
      precio: '\$0',
      periodo: '',
      actual: true,
      beneficios: [
        '1 negocio y 1 usuario',
        'Hasta 50 productos',
        'Historial de 30 días',
        'Catálogo y Estado con marca de agua',
      ],
    ),
    _Plan(
      nombre: 'Premium',
      precio: '\$5',
      periodo: '/mes',
      etiqueta: 'Más popular',
      beneficios: [
        'Negocios y empleados ilimitados',
        'Productos e historial sin límite',
        'Reportes avanzados y exportar a Excel/PDF',
        'Catálogo y Estado sin marca de agua',
        'Multi-moneda y facturación en PDF',
      ],
    ),
    _Plan(
      nombre: 'Premium anual',
      precio: '\$48',
      periodo: '/año',
      etiqueta: 'Ahorra 20%',
      beneficios: [
        'Todo lo de Premium',
        'Dos meses gratis frente al plan mensual',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                NeuIconBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  'Planes premium',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Elige el plan que más le convenga a tu negocio',
              style: TextStyle(fontSize: 13, color: t.textSec),
            ),
            const SizedBox(height: 20),

            for (final plan in _planes)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _TarjetaPlan(plan: plan),
              ),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.avisoSuave,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'El cobro todavía no está activo: falta dar de alta las '
                'suscripciones en Google Play Console. Hasta entonces sigues '
                'en el plan Gratis sin límites aplicados.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.aviso,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Los pagos se procesan por Google Play. Cuenta Clara nunca ve ni '
              'guarda los datos de tu tarjeta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: t.muted),
            ),
          ],
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
    final t = context.tokens;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(22),
            border: plan.etiqueta != null
                ? Border.all(color: AppColors.marca, width: 2)
                : null,
            boxShadow: plan.actual ? t.shadowBtn : t.shadowRaised,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      plan.nombre,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.text,
                      ),
                    ),
                  ),
                  Text(
                    plan.precio,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.marca,
                    ),
                  ),
                  Text(
                    plan.periodo,
                    style: TextStyle(fontSize: 13, color: t.textSec),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final b in plan.beneficios)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '✓',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.marca,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(fontSize: 13.5, color: t.textSec),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              if (plan.actual)
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: t.pageBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Tu plan actual',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.textSec,
                    ),
                  ),
                )
              else
                NeuButton(
                  label: 'Próximamente',
                  height: 46,
                  radius: 16,
                  // Sin productos en Play Console no hay nada que comprar;
                  // un botón que falla sería peor que uno deshabilitado.
                  onPressed: null,
                ),
            ],
          ),
        ),
        if (plan.etiqueta != null)
          Positioned(
            top: -10,
            right: 18,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.marca,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                plan.etiqueta!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
