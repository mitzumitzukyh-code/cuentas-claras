import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/conectividad_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/impresora/impresora_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../fiados/data/fiado_repository.dart';
import '../../../shared/presentation/permiso_requerido.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../proveedores/data/proveedor_repository.dart';

/// "Más" (réplica visual de `P2 · MÁS`, `Lote N · Reportes y Más`).
///
/// Cajón de navegación: negocio activo arriba y los accesos agrupados en
/// Dinero / Negocio / Crecer / Cuenta. Ventas, Mercancía y Reportes viven en
/// la barra inferior (`Lote K · Navegación`) y ya no se repiten aquí.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final esDueno = ref.watch(esDuenoProvider);
    final membresias = ref.watch(misMembresiasProvider).valueOrNull ?? const [];

    final fiadosPendientes = (ref.watch(clientesFiadoProvider).valueOrNull ?? const [])
        .where((c) => c.saldoUSD > 0)
        .fold<double>(0, (s, c) => s + c.saldoUSD);
    final proveedoresPendientes = (ref.watch(proveedoresProvider).valueOrNull ?? const [])
        .fold<double>(0, (s, p) => s + p.saldoUSD);
    final impresoraLista = (ref.watch(impresoraConfigProvider).valueOrNull)?.configurada ?? false;

    final nombre = negocio?.nombre ?? 'Mi negocio';
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();

    return Scaffold(
      backgroundColor: t.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.perfil),
      body: LibretaPageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
            children: [
              Text(
                'Más',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: t.textoFuerte, letterSpacing: -0.4),
              ),
              const SizedBox(height: 14),

              // --- Negocio activo / selector ---
              InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => context.push(Routes.misNegocios),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.superficie,
                    border: Border.all(color: t.bordeSuave),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      _AvatarNegocio(fotoUrl: negocio?.fotoUrl, inicial: inicial),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.textoFuerte),
                            ),
                            Text(
                              membresias.length > 1 ? 'Cambiar de negocio' : (negocio?.rubro.etiqueta ?? '—'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textoMuted),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        membresias.length > 1 ? Icons.unfold_more : Icons.edit_outlined,
                        size: 20,
                        color: t.textoMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              _Grupo(
                titulo: 'Dinero',
                filas: [
                  _Fila(
                    icono: Icons.groups_outlined,
                    etiqueta: 'Fiados',
                    valor: fiadosPendientes > 0 ? MoneyFormatter.usd(fiadosPendientes) : null,
                    onTap: () => context.push(Routes.fiados),
                  ),
                  _Fila(
                    icono: Icons.payments_outlined,
                    etiqueta: 'Gastos',
                    onTap: () => context.push(Routes.gastos),
                  ),
                  _Fila(
                    icono: Icons.point_of_sale_outlined,
                    etiqueta: 'Cierre de caja',
                    onTap: () => context.push(Routes.arqueo),
                  ),
                  _Fila(
                    icono: Icons.local_shipping_outlined,
                    etiqueta: 'Cuentas por pagar',
                    valor: proveedoresPendientes > 0 ? MoneyFormatter.usd(proveedoresPendientes) : null,
                    onTap: () => context.push(Routes.proveedores),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _Grupo(
                titulo: 'Negocio',
                filas: [
                  if (ref.watch(puedeProvider(Permisos.gestionarEmpleados)))
                    _Fila(
                      icono: Icons.groups_2_outlined,
                      etiqueta: 'Empleados',
                      onTap: () => context.push(Routes.empleados),
                    ),
                  _Fila(
                    icono: Icons.credit_card_outlined,
                    etiqueta: 'Métodos de pago',
                    onTap: () => context.push(Routes.metodosPago),
                  ),
                  _Fila(
                    icono: Icons.print_outlined,
                    etiqueta: 'Impresora',
                    valor: impresoraLista ? 'Conectada' : null,
                    valorColor: LibretaColors.verde,
                    puntoVerde: impresoraLista,
                    onTap: () => context.push(Routes.impresora),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _Grupo(
                titulo: 'Crecer',
                filas: [
                  _Fila(
                    icono: Icons.auto_awesome_outlined,
                    etiqueta: 'Plan Plus',
                    badge: 'Mejora',
                    onTap: () => context.push(Routes.planes),
                  ),
                  _Fila(
                    icono: Icons.storefront_outlined,
                    etiqueta: 'Catálogo',
                    onTap: () => context.push(Routes.catalogo),
                  ),
                  _Fila(
                    icono: Icons.schedule_outlined,
                    etiqueta: 'Estado de WhatsApp',
                    onTap: () => context.push(Routes.catalogo),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _Grupo(
                titulo: 'Cuenta',
                filas: [
                  _Fila(
                    icono: Icons.settings_outlined,
                    etiqueta: 'Ajustes',
                    onTap: () => context.push(Routes.ajustes),
                  ),
                  _Fila(
                    icono: Icons.person_outline,
                    etiqueta: 'Perfil',
                    onTap: () => context.push(Routes.miPerfil),
                  ),
                  _Fila(
                    icono: Icons.help_outline,
                    etiqueta: 'Centro de ayuda',
                    onTap: () => context.push(Routes.ayuda),
                  ),
                ],
              ),

              if (!esDueno) ...[
                const SizedBox(height: 18),
                Text(
                  'Entraste como vendedor: no ves reportes financieros ni '
                  'puedes anular ventas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: t.textoMuted),
                ),
              ],

              const SizedBox(height: 24),
              LibretaSecondaryButton(
                label: 'Cerrar sesión',
                onPressed: () async {
                  final conectado =
                      ref.read(hayConexionProvider).valueOrNull ?? true;
                  final seguro = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('¿Cerrar sesión?'),
                      content: Text(
                        conectado
                            ? 'Se cerrará tu sesión y volverás a la pantalla de '
                                'inicio. Podrás entrar de nuevo cuando quieras.'
                            : 'Estás sin conexión. Si cierras sesión ahora, no '
                                'podrás volver a entrar hasta que vuelva la señal.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(true),
                          child: const Text('Cerrar sesión',
                              style: TextStyle(color: LibretaColors.peligro)),
                        ),
                      ],
                    ),
                  );
                  if (seguro != true) return;
                  await ref.read(authRepositoryProvider).cerrarSesion();
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Cuenta Clara',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: t.textoMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Avatar del negocio (44×44): la foto que se puso en Ajustes, o la inicial.
class _AvatarNegocio extends StatelessWidget {
  const _AvatarNegocio({required this.fotoUrl, required this.inicial});

  final String? fotoUrl;
  final String inicial;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: LibretaColors.verde, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: tieneFoto
          ? FotoRed(
              fotoUrl!,
              width: 44,
              height: 44,
              alError: Text(inicial, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            )
          : Text(inicial, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}

/// Hoja para elegir entre los negocios donde el usuario tiene membresía.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.titulo, required this.filas});

  final String titulo;
  final List<_Fila> filas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.libreta.textoMuted),
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
              for (var i = 0; i < filas.length; i++) filas[i].conDivisor(i != filas.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.valor,
    this.valorColor,
    this.badge,
    this.puntoVerde = false,
    this.divisor = true,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final String? valor;
  final Color? valorColor;
  final String? badge;
  final bool puntoVerde;
  final bool divisor;

  _Fila conDivisor(bool v) => _Fila(
        icono: icono,
        etiqueta: etiqueta,
        onTap: onTap,
        valor: valor,
        valorColor: valorColor,
        badge: badge,
        puntoVerde: puntoVerde,
        divisor: v,
      );

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: divisor ? Border(bottom: BorderSide(color: t.renglon)) : null,
        ),
        child: Row(
          children: [
            Icon(icono, size: 19, color: t.textoFuerte),
            const SizedBox(width: 13),
            Expanded(
              child: Text(etiqueta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: t.textoFuerte)),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: const Color(0x28F2A93C), borderRadius: BorderRadius.circular(100)),
                child: Text(badge!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: LibretaColors.aviso)),
              ),
              const SizedBox(width: 8),
            ],
            if (puntoVerde) ...[
              const _Punto(),
              const SizedBox(width: 5),
            ],
            if (valor != null) ...[
              Text(
                valor!,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valorColor ?? LibretaColors.aviso),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 20, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: LibretaColors.verde, shape: BoxShape.circle),
    );
  }
}
