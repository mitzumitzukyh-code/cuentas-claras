import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/binance/binance_p2p_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/entrada_animada.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../services/notificaciones/push_service.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../notificaciones/presentation/aviso_notificaciones.dart';
import '../../onboarding/presentation/tutorial_screen.dart';
import '../../productos/data/producto_repository.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/domain/venta.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoPedirPermisoTasaProvider);
    ref.watch(registrarTokenVentasProvider);
    ref.listen(tutorialPendienteProvider, (_, estado) {
      if (estado.valueOrNull != true) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        context.push(Routes.tutorial);
      });
    });

    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final t = context.libreta;

    final falloDatos =
        ref.watch(negocioActivoProvider).hasError ||
        ref.watch(ventasDelDiaProvider).hasError ||
        ref.watch(productosProvider).hasError;

    final ventas = ref.watch(ventasDelDiaProvider).valueOrNull ?? const [];
    final tieneVentasHoy = ventas.isNotEmpty;

    final tieneFondo =
        (negocio?.fotoComoFondo ?? false) &&
        (negocio?.fotoUrl?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: tieneFondo ? Colors.transparent : t.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.inicio),
      body: Stack(
        children: [
          if (tieneFondo)
            Positioned.fill(
              child: FotoRed(
                negocio!.fotoUrl!,
                alError: Container(color: t.papel),
              ),
            ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: LibretaColors.verde,
              onRefresh: () async {
                ref.invalidate(bcvRateProvider);
                ref.invalidate(binanceP2PRateProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  if (falloDatos) ...[
                    const _BannerSinPermiso(),
                    const SizedBox(height: 16),
                  ],

                  const _SeccionSaludo(),
                  const SizedBox(height: 12),

                  const AvisoNotificaciones(),

                  const _NotaTasaWidget(),
                  const SizedBox(height: 16),

                  if (tieneVentasHoy) ...[
                    const _TarjetaVentasWidget(),
                    const SizedBox(height: 12),

                    const _FilaGananciaTicket(),
                    const SizedBox(height: 12),

                    const _ComparativoWidget(),
                    const SizedBox(height: 12),

                    const _RachaWidget(),
                  ] else ...[
                    const _DiaSinVentasWidget(),
                  ],

                  const _BloqueUrgencias(),

                  const SizedBox(height: 16),
                  EntradaAnimada(
                    retardo: const Duration(milliseconds: 270),
                    child: _TituloAccesos(),
                  ),
                  const SizedBox(height: 12),
                  const _GridAccesosRapidos(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Saludo + nombre + avatar
// ---------------------------------------------------------------------------
class _SeccionSaludo extends ConsumerWidget {
  const _SeccionSaludo();

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  IconData _iconoSaludo() {
    final h = DateTime.now().hour;
    if (h < 12) return Icons.wb_sunny_outlined;
    if (h < 19) return Icons.wb_twilight;
    return Icons.nightlight_outlined;
  }

  String _iniciales(String nombre) {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0].substring(0, 1) + partes[1].substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final nombre = negocio?.nombre ?? 'Mi negocio';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _saludo(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.textoMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_iconoSaludo(), size: 16, color: t.textoMuted),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: t.textoFuerte,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      size: 20, color: t.textoMuted),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _AvatarNegocio(
          fotoUrl: negocio?.fotoUrl,
          iniciales: _iniciales(nombre),
          onTap: () => context.go(Routes.perfil),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tasa del día (BCV + Binance)
// ---------------------------------------------------------------------------
class _NotaTasaWidget extends ConsumerWidget {
  const _NotaTasaWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasa = ref.watch(bcvRateProvider).valueOrNull;
    final binance = ref.watch(binanceP2PRateProvider).valueOrNull;
    return EntradaAnimada(
      retardo: const Duration(milliseconds: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 208),
          child: _NotaTasa(bcv: tasa?.tasa, binance: binance?.precio),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta de ventas del día
// ---------------------------------------------------------------------------
class _TarjetaVentasWidget extends ConsumerWidget {
  const _TarjetaVentasWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas =
        ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final tasa = ref.watch(bcvRateProvider).valueOrNull;
    final totalUsd = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    return EntradaAnimada(
      retardo: const Duration(milliseconds: 130),
      child: _TarjetaVentas(
        totalUsd: totalUsd,
        tasa: tasa?.tasa,
        ventas: ventas.length,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ganancia / Ticket promedio
// ---------------------------------------------------------------------------
class _FilaGananciaTicket extends ConsumerWidget {
  const _FilaGananciaTicket();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas =
        ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final itemsHoy = ventas.fold<int>(0, (s, v) => s + v.items.length);
    final itemsSinCosto = ventas.fold<int>(0, (s, v) => s + v.itemsSinCosto);
    final totalUsdHoy = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    final gananciaHoy = ventas.fold<double>(0, (s, v) => s + v.gananciaUSD);

    final hayGanancia = itemsHoy > 0 && itemsSinCosto < itemsHoy;
    final gananciaParcial = itemsSinCosto > 0;
    final ticketProm = ventas.isEmpty ? null : totalUsdHoy / ventas.length;

    return EntradaAnimada(
      retardo: const Duration(milliseconds: 200),
      child: Row(
        children: [
          Expanded(
            child: _TarjetaMini(
              etiqueta: 'Ganancia',
              valor: hayGanancia
                  ? '${gananciaParcial ? "≈" : ""}'
                      '${MoneyFormatter.usd(gananciaHoy)}'
                  : '—',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TarjetaMini(
              etiqueta: 'Ticket prom.',
              valor: ticketProm == null ? '—' : MoneyFormatter.usd(ticketProm),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Día sin ventas — "hoja en blanco" + sugerencias (Lote P · P2)
// ---------------------------------------------------------------------------
class _DiaSinVentasWidget extends StatelessWidget {
  const _DiaSinVentasWidget();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return EntradaAnimada(
      retardo: const Duration(milliseconds: 130),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.bordeSuave),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.auto_stories_outlined, size: 40, color: t.textoMuted),
            const SizedBox(height: 12),
            Text(
              'Hoja en blanco',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Todavía no registras ventas hoy',
              style: TextStyle(fontSize: 13.5, color: t.textoMuted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _AccesoRapido(
                    etiqueta: 'Cobrar',
                    icono: Icons.shopping_cart_outlined,
                    color: LibretaColors.verde,
                    onTap: () => context.go(Routes.cobrar),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AccesoRapido(
                    etiqueta: 'Productos',
                    icono: Icons.inventory_2_outlined,
                    color: t.textoFuerte,
                    onTap: () => context.go(Routes.productos),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comparativo vs ayer (Lote P · P1)
// ---------------------------------------------------------------------------
class _ComparativoWidget extends ConsumerWidget {
  const _ComparativoWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventasHoy =
        ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final ayerAsync = ref.watch(ventasDeAyerProvider);

    final totalHoy = ventasHoy.fold<double>(0, (s, v) => s + v.totalUSD);
    final totalAyer =
        ayerAsync.valueOrNull?.fold<double>(0, (s, v) => s + v.totalUSD) ?? 0;

    if (totalAyer == 0) return const SizedBox.shrink();

    final diff = totalHoy - totalAyer;
    final pct = (diff / totalAyer) * 100;
    final esMejor = diff >= 0;
    final t = context.libreta;

    return EntradaAnimada(
      retardo: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.bordeSuave),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              esMejor ? Icons.trending_up : Icons.trending_down,
              size: 20,
              color: esMejor ? LibretaColors.verde : LibretaColors.peligro,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: esMejor ? 'Superaste ayer por ' : 'Debajo de ayer por ',
                  style: TextStyle(fontSize: 13, color: t.textoFuerte),
                  children: [
                    TextSpan(
                      text: MoneyFormatter.usd(diff.abs()),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: esMejor ? LibretaColors.verde : LibretaColors.peligro,
                      ),
                    ),
                    TextSpan(
                      text: ' (${pct.toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 12, color: t.textoMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Racha de días consecutivos con ventas (Lote P · P1)
// ---------------------------------------------------------------------------
class _RachaWidget extends ConsumerWidget {
  const _RachaWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rachaAsync = ref.watch(rachaDiasProvider);
    final racha = rachaAsync.valueOrNull ?? 0;
    if (racha < 2) return const SizedBox.shrink();

    final t = context.libreta;
    return EntradaAnimada(
      retardo: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x1F0E9F6E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '$racha día${racha == 1 ? '' : 's'} ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.verde,
                  ),
                  children: [
                    TextSpan(
                      text: 'consecutivos con ventas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: t.textoFuerte,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bloque de urgencias (Lote P · P3)
// ---------------------------------------------------------------------------
class _BloqueUrgencias extends ConsumerWidget {
  const _BloqueUrgencias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos =
        ref.watch(productosConAlertaProvider).valueOrNull ?? const [];
    final stockBajo = productos.where((p) => p.stockBajo).length;
    final pendientes = ref.watch(ventasPendientesProvider);

    final items = <Widget>[];
    if (stockBajo > 0) {
      items.add(__UrgenciaItem(
        icono: Icons.inventory_2_outlined,
        texto: stockBajo == 1
            ? '1 producto con stock bajo'
            : '$stockBajo productos con stock bajo',
        onTap: () => context.go(Routes.productos),
      ));
    }
    if (pendientes.isNotEmpty) {
      items.add(__UrgenciaItem(
        icono: Icons.cloud_upload_outlined,
        texto: pendientes.length == 1
            ? '1 venta sin subir'
            : '${pendientes.length} ventas sin subir',
        onTap: () => context.push(Routes.ventasPendientes),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: EntradaAnimada(
        retardo: const Duration(milliseconds: 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANTES DE CERRAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: context.libreta.textoMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...items,
          ],
        ),
      ),
    );
  }
}

class __UrgenciaItem extends StatelessWidget {
  const __UrgenciaItem({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: t.superficie,
            border: Border.all(color: t.bordeSuave),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icono, size: 18, color: LibretaColors.aviso),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.textoFuerte,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: t.textoMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accesos rápidos
// ---------------------------------------------------------------------------
class _TituloAccesos extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      'ACCESOS RÁPIDOS',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: context.libreta.textoMuted,
      ),
    );
  }
}

class _GridAccesosRapidos extends StatelessWidget {
  const _GridAccesosRapidos();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Column(
      children: [
        EntradaAnimada(
          retardo: const Duration(milliseconds: 330),
          child: Row(
            children: [
              Expanded(
                child: _AccesoRapido(
                  etiqueta: 'Cobrar',
                  icono: Icons.shopping_cart_outlined,
                  color: LibretaColors.verde,
                  onTap: () => context.go(Routes.cobrar),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccesoRapido(
                  etiqueta: 'Productos',
                  icono: Icons.inventory_2_outlined,
                  color: t.textoFuerte,
                  onTap: () => context.go(Routes.productos),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EntradaAnimada(
          retardo: const Duration(milliseconds: 390),
          child: Row(
            children: [
              Expanded(
                child: _AccesoRapido(
                  etiqueta: 'Gastos',
                  icono: Icons.payments_outlined,
                  color: t.textoFuerte,
                  onTap: () => context.push(Routes.gastos),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AccesoRapido(
                  etiqueta: 'Reportes',
                  icono: Icons.show_chart,
                  color: const Color(0xFFF2A93B),
                  onTap: () => context.go(Routes.reportes),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares (sin providers)
// ---------------------------------------------------------------------------

class _BannerSinPermiso extends StatelessWidget {
  const _BannerSinPermiso();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x21F2A93C),
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
                color: LibretaColors.aviso,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotaTasa extends StatelessWidget {
  const _NotaTasa({required this.bcv, required this.binance});

  final double? bcv;
  final double? binance;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.026,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
        decoration: BoxDecoration(
          color: const Color(0xFFFCEFB4),
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2A1E2A38),
              offset: Offset(2, 5),
              blurRadius: 12,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TASA DEL DÍA · POR \$',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Color(0xFF9A7B1A),
              ),
            ),
            const SizedBox(height: 4),
            _LineaTasa(etiqueta: 'BCV', valor: bcv),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 5),
              color: const Color(0x4D9A7B1A),
            ),
            _LineaTasa(etiqueta: 'Paralelo', valor: binance, estrella: true),
          ],
        ),
      ),
    );
  }
}

class _LineaTasa extends StatelessWidget {
  const _LineaTasa({
    required this.etiqueta,
    required this.valor,
    this.estrella = false,
  });

  final String etiqueta;
  final double? valor;
  final bool estrella;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A7B1A),
              ),
            ),
            if (estrella) ...[
              const SizedBox(width: 3),
              const Text(
                '*',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9A7B1A),
                ),
              ),
            ],
          ],
        ),
        Text(
          valor == null ? '—' : MoneyFormatter.bs(valor!),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF9A7B1A),
          ),
        ),
      ],
    );
  }
}

class _TarjetaVentas extends StatelessWidget {
  const _TarjetaVentas({
    required this.totalUsd,
    required this.tasa,
    required this.ventas,
  });

  final double totalUsd;
  final double? tasa;
  final int ventas;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: LibretaColors.verde,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MoneyFormatter.usd(totalUsd),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tasa == null
                      ? 'calculando…'
                      : MoneyFormatter.usdComoBs(totalUsd, tasa!),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x21FFFFFF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '$ventas ${ventas == 1 ? 'venta' : 'ventas'}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMini extends StatelessWidget {
  const _TarjetaMini({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.bordeSuave),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.textoMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: t.textoFuerte,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccesoRapido extends StatelessWidget {
  const _AccesoRapido({
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  final String etiqueta;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: t.superficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.bordeSuave),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.textoFuerte,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarNegocio extends StatelessWidget {
  const _AvatarNegocio({
    required this.fotoUrl,
    required this.iniciales,
    required this.onTap,
  });

  final String? fotoUrl;
  final String iniciales;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: LibretaColors.verde,
          borderRadius: BorderRadius.circular(30),
        ),
        alignment: Alignment.center,
        child: tieneFoto
            ? FotoRed(
                fotoUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                alError: Text(
                  iniciales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Text(
                iniciales,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
