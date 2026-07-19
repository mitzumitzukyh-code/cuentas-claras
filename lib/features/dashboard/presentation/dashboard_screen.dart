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
import '../../negocio/data/negocio_repository.dart';
import '../../notificaciones/presentation/notificaciones_screen.dart';
import '../../productos/data/producto_repository.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/domain/venta.dart';
import '../../ventas/presentation/historial_screen.dart';
import '../../ventas/presentation/venta_detalle_screen.dart';

/// Pantalla 4 — Inicio/Dashboard (bloque `isDashboard` del diseño).
///
/// Saludo + avatar, tarjeta verde de ventas del día, tasa BCV, contadores de
/// productos y stock bajo, y la actividad reciente.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  /// El diseño cambia el saludo según la hora.
  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final ventas = ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final tasa = ref.watch(bcvRateProvider).valueOrNull;

    final totalUsdHoy = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    final stockBajo = productos.where((p) => p.stockBajo).length;
    final nombre = negocio?.nombre ?? 'Mi negocio';

    // Si Firestore rechaza las consultas (reglas no desplegadas, sin permiso),
    // el dashboard se vería vacío y sin explicación. Mejor decirlo.
    final falloDatos = ref.watch(negocioActivoProvider).hasError ||
        ref.watch(ventasDelDiaProvider).hasError ||
        ref.watch(productosProvider).hasError;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(activa: NavTab.inicio),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.marca,
          onRefresh: () async => ref.invalidate(bcvRateProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              if (falloDatos) ...[
                const _BannerSinPermiso(),
                const SizedBox(height: 16),
              ],

              // --- Saludo + acciones ---
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _saludo(),
                          style: TextStyle(fontSize: 13, color: t.textSec),
                        ),
                        Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Campana(
                    // Punto de aviso solo si hay algo que atender.
                    conAviso: stockBajo > 0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificacionesScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _AvatarNegocio(
                    inicial: nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
                    onTap: () => context.go(Routes.perfil),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // --- Ventas de hoy ---
              _TarjetaVentas(
                totalUsd: totalUsdHoy,
                tasa: tasa?.tasa,
                cobros: ventas.length,
              ),
              const SizedBox(height: 18),

              // --- Tasa BCV ---
              _FilaTasaBcv(tasa: tasa?.tasa),
              const SizedBox(height: 18),

              // --- Contadores ---
              Row(
                children: [
                  Expanded(
                    child: _Contador(
                      etiqueta: 'Productos',
                      valor: '${productos.length}',
                      onTap: () => context.go(Routes.productos),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Contador(
                      etiqueta: 'Stock bajo',
                      valor: '$stockBajo',
                      alerta: stockBajo > 0,
                      onTap: () => context.go(Routes.productos),
                    ),
                  ),
                ],
              ),
              // --- Meta mensual (solo si el dueño la configuró) ---
              if ((negocio?.metaMensualUsd ?? 0) > 0) ...[
                const SizedBox(height: 18),
                _MetaMensual(
                  logrado: totalUsdHoy,
                  meta: negocio!.metaMensualUsd,
                ),
              ],

              const SizedBox(height: 18),

              // --- Actividad reciente ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Actividad reciente',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HistorialScreen(),
                      ),
                    ),
                    child: const Text(
                      'Ver todo',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.marca,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (ventas.isEmpty)
                NeuCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      const Text('🧾', style: TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(
                        'Aún no registras ventas',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: t.textSec,
                        ),
                      ),
                    ],
                  ),
                )
              else
                NeuCard(
                  clip: true,
                  child: Column(
                    children: [
                      for (var i = 0; i < ventas.length && i < 5; i++)
                        _FilaVenta(
                          venta: ventas[i],
                          ultima: i == ventas.length - 1 || i == 4,
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso cuando Firestore rechaza las lecturas del negocio.
class _BannerSinPermiso extends StatelessWidget {
  const _BannerSinPermiso();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.avisoSuave,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Text('⚠️', style: TextStyle(fontSize: 16)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No pudimos leer los datos de tu negocio. Revisa que las reglas '
              'de Firestore estén publicadas.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.aviso,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso de la meta mensual de ventas.
class _MetaMensual extends StatelessWidget {
  const _MetaMensual({required this.logrado, required this.meta});

  final double logrado;
  final double meta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fraccion = (logrado / meta).clamp(0.0, 1.0);
    final pct = (fraccion * 100).round();

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Meta mensual',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.textSec,
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: t.textSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: fraccion,
              minHeight: 8,
              backgroundColor: t.pageBg,
              valueColor: const AlwaysStoppedAnimation(AppColors.marca),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${MoneyFormatter.usd(logrado)} de ${MoneyFormatter.usd(meta)}',
            style: TextStyle(fontSize: 11.5, color: t.textSec),
          ),
        ],
      ),
    );
  }
}

/// Campana de notificaciones con el punto ámbar de "sin leer".
class _Campana extends StatelessWidget {
  const _Campana({required this.conAviso, required this.onTap});

  final bool conAviso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        NeuIconBtn(
          icon: Icons.notifications_none,
          size: 42,
          radius: 100,
          onTap: onTap,
        ),
        if (conAviso)
          Positioned(
            top: 8,
            right: 9,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.aviso,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Avatar circular verde con la inicial del negocio.
class _AvatarNegocio extends StatelessWidget {
  const _AvatarNegocio({required this.inicial, required this.onTap});

  final String inicial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta verde grande con el total del día.
class _TarjetaVentas extends StatelessWidget {
  const _TarjetaVentas({
    required this.totalUsd,
    required this.tasa,
    required this.cobros,
  });

  final double totalUsd;
  final double? tasa;
  final int cobros;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.marca,
        borderRadius: BorderRadius.circular(24),
        boxShadow: t.shadowBtn,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventas de hoy',
            style: TextStyle(fontSize: 13, color: Color(0xD9FFFFFF)),
          ),
          const SizedBox(height: 6),
          Text(
            MoneyFormatter.usd(totalUsd),
            style: AppTypography.money(fontSize: 34, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            tasa == null
                ? 'Tasa BCV no disponible'
                : MoneyFormatter.usdComoBs(totalUsd, tasa!),
            style: const TextStyle(fontSize: 14, color: Color(0xD9FFFFFF)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$cobros ${cobros == 1 ? "cobro" : "cobros"} hoy',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila con la tasa del dólar BCV.
///
/// Es solo informativa: sin `onTap` ni flecha, para que no invite a pulsarla y
/// luego no pase nada.
class _FilaTasaBcv extends StatelessWidget {
  const _FilaTasaBcv({required this.tasa});

  final double? tasa;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuCard(
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
                  'Dólar BCV',
                  style: TextStyle(fontSize: 11.5, color: t.textSec),
                ),
                Text(
                  tasa == null ? 'Cargando…' : MoneyFormatter.bs(tasa!),
                  style: AppTypography.money(fontSize: 15, color: t.text),
                ),
              ],
            ),
          ),
          Text(
            'Referencia de hoy',
            style: TextStyle(fontSize: 11, color: t.muted),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de contador (Productos / Stock bajo).
class _Contador extends StatelessWidget {
  const _Contador({
    required this.etiqueta,
    required this.valor,
    required this.onTap,
    this.alerta = false,
  });

  final String etiqueta;
  final String valor;
  final VoidCallback onTap;

  /// Stock bajo con existencias pendientes se pinta en ámbar.
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = alerta ? AppColors.aviso : t.text;

    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      color: alerta ? AppColors.avisoSuave : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 12,
              color: alerta ? AppColors.aviso : t.textSec,
            ),
          ),
          const SizedBox(height: 4),
          Text(valor, style: AppTypography.money(fontSize: 22, color: color)),
        ],
      ),
    );
  }
}

/// Fila de la lista de actividad reciente.
class _FilaVenta extends StatelessWidget {
  const _FilaVenta({required this.venta, required this.ultima});

  final Venta venta;
  final bool ultima;

  String _hora(DateTime f) {
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final m = f.minute.toString().padLeft(2, '0');
    return '$h:$m ${f.hour < 12 ? "am" : "pm"}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Las líneas por peso no son "unidades", así que se cuentan como productos.
    final lineas = venta.items.length;

    return NeuListTile(
      divider: !ultima,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VentaDetalleScreen(ventaId: venta.id),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text(
              '\$',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.marca,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Venta · $lineas ${lineas == 1 ? "producto" : "productos"}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
                Text(
                  _hora(venta.fecha),
                  style: TextStyle(fontSize: 12, color: t.textSec),
                ),
              ],
            ),
          ),
          Text(
            MoneyFormatter.usd(venta.totalUSD),
            style: AppTypography.money(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}
