import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/neu.dart';
import '../../auth/data/auth_repository.dart';
import '../../catalogo/presentation/catalogo_screen.dart';
import '../../gastos/presentation/gastos_screen.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../planes/presentation/planes_screen.dart';
import '../../reportes/presentation/reportes_screen.dart';
import '../../negocio/presentation/empleados_screen.dart';
import '../../negocio/presentation/impresora_screen.dart';
import '../../negocio/presentation/metodos_pago_screen.dart';
import '../../ventas/presentation/historial_screen.dart';
import 'ajustes_screen.dart';

/// Perfil (bloque `isPerfil` del diseño).
///
/// Es el centro de navegación de la app: tarjeta del negocio, tasa BCV y los
/// accesos agrupados en Ventas / Negocio / Cuenta.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;
    final esDueno = ref.watch(esDuenoProvider);

    final nombre = negocio?.nombre ?? 'Mi negocio';
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(activa: NavTab.perfil),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            Text(
              'Perfil',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: t.text,
              ),
            ),
            const SizedBox(height: 18),

            // --- Tarjeta del negocio ---
            NeuCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.marca,
                      shape: BoxShape.circle,
                      boxShadow: t.shadowBtn,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      inicial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: t.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          negocio?.rubro.etiqueta ?? '—',
                          style: TextStyle(fontSize: 13, color: t.textSec),
                        ),
                      ],
                    ),
                  ),
                  NeuIconBtn(
                    emoji: '✏️',
                    size: 34,
                    radius: 12,
                    onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AjustesScreen(),
                    ),
                  ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // --- Tasa BCV ---
            NeuCard(
              small: true,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: t.tint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Bs',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.marca,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasa BCV',
                          style: TextStyle(fontSize: 12.5, color: t.textSec),
                        ),
                        Text(
                          'Dólares (USD)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: t.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    tasa == null ? '—' : MoneyFormatter.bs(tasa),
                    style: AppTypography.money(
                      fontSize: 16,
                      color: AppColors.marca,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // --- Ventas ---
            _Grupo(
              titulo: 'Ventas',
              filas: [
                _Fila(
                  emoji: '🧾',
                  etiqueta: 'Historial de ventas',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistorialScreen(),
                    ),
                  ),
                ),
                _Fila(
                  emoji: '📊',
                  etiqueta: 'Reportes de ventas',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportesScreen(),
                    ),
                  ),
                ),
                _Fila(
                  emoji: '💸',
                  etiqueta: 'Gastos',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GastosScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Negocio ---
            _Grupo(
              titulo: 'Negocio',
              filas: [
                _Fila(
                  emoji: '📦',
                  etiqueta: 'Gestionar productos',
                  onTap: () => context.go(Routes.productos),
                ),
                _Fila(
                  emoji: '👥',
                  etiqueta: 'Empleados',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmpleadosScreen(),
                    ),
                  ),
                ),
                _Fila(
                  emoji: '💬',
                  etiqueta: 'Catálogo y WhatsApp',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CatalogoScreen(),
                    ),
                  ),
                ),
                _Fila(
                  emoji: '🖨️',
                  etiqueta: 'Impresora de tickets',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ImpresoraScreen(),
                    ),
                  ),
                ),
                _Fila(
                  emoji: '💳',
                  etiqueta: 'Métodos de pago',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MetodosPagoScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Cuenta ---
            _Grupo(
              titulo: 'Cuenta',
              filas: [
                _Fila(
                  emoji: '✨',
                  etiqueta: 'Planes premium',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlanesScreen(),
                    ),
                  ),
                ),
                _Fila(
                  emoji: '⚙️',
                  etiqueta: 'Ajustes de la cuenta',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AjustesScreen(),
                    ),
                  ),
                ),
              ],
            ),

            if (!esDueno) ...[
              const SizedBox(height: 18),
              Text(
                'Entraste como empleado: no ves reportes financieros ni puedes '
                'anular ventas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textSec),
              ),
            ],

            const SizedBox(height: 24),
            NeuSecondaryButton(
              label: 'Cerrar sesión',
              color: AppColors.peligro,
              background: AppColors.peligroSuave,
              onPressed: () => ref.read(authRepositoryProvider).cerrarSesion(),
            ),
            const SizedBox(height: 12),
            Text(
              'Cuenta Clara v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de sección + tarjeta con filas.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.filas});

  final String titulo;
  final List<_Fila> filas;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.textSec,
          ),
        ),
        const SizedBox(height: 8),
        NeuCard(
          clip: true,
          child: Column(
            children: [
              for (var i = 0; i < filas.length; i++)
                filas[i].conDivisor(i != filas.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.emoji,
    required this.etiqueta,
    required this.onTap,
    this.divisor = true,
  });

  final String emoji;
  final String etiqueta;
  final VoidCallback onTap;
  final bool divisor;

  _Fila conDivisor(bool v) => _Fila(
        emoji: emoji,
        etiqueta: etiqueta,
        onTap: onTap,
        divisor: v,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuListTile(
      divider: divisor,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.text,
              ),
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: t.muted),
        ],
      ),
    );
  }
}
