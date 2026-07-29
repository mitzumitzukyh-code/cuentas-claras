import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/conectividad_provider.dart';
import '../../../core/providers/historial_tasa_provider.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/entrada_animada.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/binance/binance_p2p_service.dart';
import '../../../services/notificaciones/push_service.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../onboarding/presentation/tutorial_screen.dart';
import '../../productos/data/producto_repository.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/domain/venta.dart';
import 'coachmark_primer_uso.dart';
import 'urgencias.dart';

/// Inicio (`Lote P`).
///
/// La pantalla **propone acciones, no reporta números**: el protagonista es el
/// botón de Cobrar, y lo que lo rodea cambia según el estado del día — normal,
/// sin ventas, con urgencias o con la tasa vencida.
///
/// Scrollea (el diseño la define con `overflow:auto`); la barra inferior queda
/// fija fuera del scroll.
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

    final t = context.libreta;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final conectado = ref.watch(hayConexionProvider).valueOrNull ?? true;
    final pendientes = ref.watch(ventasPendientesProvider);

    final falloDatos = ref.watch(negocioActivoProvider).hasError ||
        ref.watch(ventasDelDiaProvider).hasError ||
        ref.watch(productosProvider).hasError;

    final ventas = ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final hayVentas = ventas.isNotEmpty;

    // La urgencia manda sobre todo lo demás: si hay una, ocupa el lugar del
    // héroe y el botón de Cobrar se degrada a su variante compacta.
    final urgencia = ref.watch(urgenciaPrincipalProvider);
    final tasaVieja = (ref.watch(diasDesdeTasaProvider) ?? 0) >= 2 &&
        ref.watch(tasaManualProvider) == null;

    final tieneFondo = (negocio?.fotoComoFondo ?? false) &&
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
          Column(
            children: [
              // Barra de sin conexión: pegada arriba del todo, fuera del
              // scroll, para que no se pierda al bajar.
              if (!conectado) _BarraSinConexion(pendientes: pendientes.length),
              Expanded(
                child: SafeArea(
                  top: conectado,
                  bottom: false,
                  child: RefreshIndicator(
                    color: LibretaColors.verde,
                    onRefresh: () async {
                      ref.invalidate(bcvRateProvider);
                      ref.invalidate(binanceP2PRateProvider);
                    },
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20, conectado ? 26 : 16, 20, 18),
                      children: [
                        if (falloDatos) ...[
                          const _BannerSinPermiso(),
                          const SizedBox(height: 16),
                        ],

                        const _Encabezado(),

                        if (hayVentas && urgencia == null && !tasaVieja) ...[
                          const SizedBox(height: 10),
                          const _PastillaRacha(),
                        ],

                        if (tasaVieja) ...[
                          const SizedBox(height: 13),
                          const TarjetaTasaVencida(),
                        ] else if (urgencia != null) ...[
                          const SizedBox(height: 14),
                          TarjetaUrgencia(urgencia: urgencia),
                        ] else ...[
                          const SizedBox(height: 12),
                          const _FilaTasaDeHoy(),
                        ],

                        SizedBox(height: urgencia != null ? 12 : 16),
                        _BotonCobrarHero(
                          compacto: urgencia != null,
                          hayVentas: hayVentas,
                          sinInternet: !conectado || tasaVieja,
                        ),

                        const CoachmarkPrimerUso(),

                        if (hayVentas) ...[
                          const SizedBox(height: 16),
                          const _TarjetaVentasDeHoy(),
                        ] else ...[
                          const SizedBox(height: 16),
                          const _HojaEnBlanco(),
                        ],

                        const SizedBox(height: 20),
                        ListaPendientes(
                          titulo: urgencia != null
                              ? 'También pendiente'
                              : hayVentas
                                  ? 'Pendientes'
                                  : 'Mientras esperas',
                          excluir: urgencia?.clave,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra de sin conexión
// ---------------------------------------------------------------------------

/// Franja navy de 34px pegada al borde superior (`Lote P · P3`).
class _BarraSinConexion extends StatelessWidget {
  const _BarraSinConexion({required this.pendientes});

  final int pendientes;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LibretaColors.tarjetaOscura,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: SizedBox(
        height: 34,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 14,
              color: Color(0xFFF2A93C),
            ),
            const SizedBox(width: 7),
            Text(
              pendientes == 0
                  ? 'Sin internet · sigues vendiendo'
                  : 'Sin internet · $pendientes '
                      '${pendientes == 1 ? "movimiento" : "movimientos"} '
                      'sin sincronizar',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Encabezado: saludo, nombre, campana y avatar
// ---------------------------------------------------------------------------
class _Encabezado extends ConsumerWidget {
  const _Encabezado();

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
    final urgencias = ref.watch(urgenciasProvider).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push(Routes.misNegocios),
            behavior: HitTestBehavior.opaque,
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
                    Icon(_iconoSaludo(), size: 15, color: LibretaColors.aviso),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.15,
                          color: t.textoFuerte,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down,
                        size: 20, color: t.textoMuted),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _CampanaNotificaciones(hayNoLeidas: urgencias > 0),
        const SizedBox(width: 10),
        _AvatarNegocio(
          fotoUrl: negocio?.fotoUrl,
          iniciales: _iniciales(nombre),
          insignia: urgencias,
          onTap: () => context.go(Routes.perfil),
        ),
      ],
    );
  }
}

class _CampanaNotificaciones extends StatelessWidget {
  const _CampanaNotificaciones({required this.hayNoLeidas});

  final bool hayNoLeidas;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: () => context.push(Routes.notificaciones),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.superficie,
                shape: BoxShape.circle,
                border: Border.all(color: t.renglon),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 20,
                color: t.textoFuerte,
              ),
            ),
            if (hayNoLeidas)
              Positioned(
                top: 6,
                right: 7,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC1503A),
                    shape: BoxShape.circle,
                    border: Border.all(color: t.papel, width: 1.5),
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
// Racha y tasa
// ---------------------------------------------------------------------------

/// Pastilla verde "Racha de N días al día" (`Lote P · P0`).
class _PastillaRacha extends ConsumerWidget {
  const _PastillaRacha();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final racha = ref.watch(rachaDiasProvider).valueOrNull ?? 0;
    // Con hoy incluido: la racha del provider cuenta hasta ayer.
    final dias = racha + 1;
    if (dias < 2) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 13, 6),
        decoration: BoxDecoration(
          color: const Color(0x1A0E9F6E),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: LibretaColors.verde,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'Racha de $dias días al día',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: LibretaColors.verde,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renglón blanco "Tasa de hoy · Bs X" con punto verde (`Lote P · P0`).
class _FilaTasaDeHoy extends ConsumerWidget {
  const _FilaTasaDeHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final tipo = ref.watch(tasaActivaProvider);
    final valor = ref.watch(tasaActivaValorProvider);

    return GestureDetector(
      onTap: () => context.push(Routes.ajustes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.renglon),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: valor == null ? t.textoMuted : LibretaColors.verde,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                valor == null
                    ? 'Tasa no disponible'
                    : 'Tasa de hoy · ${MoneyFormatter.bs(valor)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.textoFuerte,
                ),
              ),
            ),
            Text(
              tipo == TipoTasa.bcv ? 'BCV' : 'Paralelo',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: t.textoMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Botón Cobrar — el protagonista
// ---------------------------------------------------------------------------

/// Botón de Cobrar (`Lote P`). Cambia de jerarquía según el día:
///
/// - **Completo** (104px, verde, sombra): es la acción del día.
/// - **Compacto** (76px, blanco con borde verde): hay algo más urgente que
///   atender primero, y el botón cede el puesto sin desaparecer.
class _BotonCobrarHero extends ConsumerWidget {
  const _BotonCobrarHero({
    required this.compacto,
    required this.hayVentas,
    required this.sinInternet,
  });

  final bool compacto;
  final bool hayVentas;
  final bool sinInternet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final ventas = ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final total = ventas.fold<double>(0, (s, v) => s + v.totalUSD);

    if (compacto) {
      return GestureDetector(
        onTap: () => context.go(Routes.cobrar),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: t.superficie,
            border: Border.all(color: const Color(0x590E9F6E), width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x210E9F6E),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.shopping_cart_outlined,
                  size: 24,
                  color: LibretaColors.verde,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cobrar',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: t.textoFuerte,
                      ),
                    ),
                    Text(
                      hayVentas
                          ? 'hoy: ${MoneyFormatter.usd(total)} · '
                              '${ventas.length} ${ventas.length == 1 ? "venta" : "ventas"}'
                          : 'anota la primera de hoy',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: t.textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: LibretaColors.verde,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => context.go(Routes.cobrar),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: LibretaColors.verde,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x520E9F6E),
              offset: Offset(0, 16),
              blurRadius: 32,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x2EFFFFFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cobrar',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sinInternet
                        ? 'funciona sin internet'
                        : hayVentas
                            ? 'anotar una venta'
                            : 'anota la primera de hoy',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xD9FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ventas de hoy / hoja en blanco
// ---------------------------------------------------------------------------

/// Tarjeta blanca con el total del día y el comparativo (`Lote P · P0`).
class _TarjetaVentasDeHoy extends ConsumerWidget {
  const _TarjetaVentasDeHoy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final ventas = ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final tasa = ref.watch(tasaActivaValorProvider);
    final pendientes = ref.watch(ventasPendientesProvider).length;
    final total = ventas.fold<double>(0, (s, v) => s + v.totalUSD);

    final ayer = ref.watch(ventasDeAyerProvider).valueOrNull ?? const <Venta>[];
    final ahora = DateTime.now();
    final ayerHastaAhora = ayer
        .where((v) =>
            v.fecha.hour < ahora.hour ||
            (v.fecha.hour == ahora.hour && v.fecha.minute <= ahora.minute))
        .fold<double>(0, (s, v) => s + v.totalUSD);

    return EntradaAnimada(
      retardo: const Duration(milliseconds: 130),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.renglon),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'VENTAS DE HOY',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: t.textoMuted,
                    ),
                  ),
                ),
                Text(
                  '${ventas.length} ${ventas.length == 1 ? "venta" : "ventas"}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyFormatter.usd(total),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1.05,
                  color: t.textoFuerte,
                ),
              ),
            ),
            if (tasa != null)
              Text(
                MoneyFormatter.usdComoBs(total, tasa),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.textoMuted,
                ),
              ),
            if (ayerHastaAhora > 0 || pendientes > 0) ...[
              const SizedBox(height: 11),
              Container(
                padding: const EdgeInsets.only(top: 11),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.renglon)),
                ),
                child: Row(
                  children: [
                    Icon(
                      pendientes > 0
                          ? Icons.schedule_rounded
                          : total >= ayerHastaAhora
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                      size: 15,
                      color: pendientes > 0
                          ? t.textoMuted
                          : total >= ayerHastaAhora
                              ? LibretaColors.verde
                              : LibretaColors.aviso,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        pendientes > 0
                            ? '$pendientes ${pendientes == 1 ? "venta esperando" : "ventas esperando"} subir'
                            : 'Ayer a esta hora ibas por '
                                '${MoneyFormatter.usd(ayerHastaAhora)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: pendientes > 0 ? t.textoMuted : t.textoFuerte,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "La hoja de hoy está en blanco" (`Lote P · P1`) — tarjeta punteada con la
/// libreta dibujada, el tagline en cursiva y el contexto histórico.
class _HojaEnBlanco extends ConsumerWidget {
  const _HojaEnBlanco();

  static const _dias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final ayer = ref.watch(ventasDeAyerProvider).valueOrNull ?? const <Venta>[];
    final totalAyer = ayer.fold<double>(0, (s, v) => s + v.totalUSD);
    final hoy = _dias[DateTime.now().weekday - 1];

    return EntradaAnimada(
      retardo: const Duration(milliseconds: 130),
      child: DottedBorderBox(
        radius: 18,
        color: t.textoMuted.withValues(alpha: 0.4),
        fondo: t.superficie,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Column(
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: CustomPaint(
                  painter: _LibretaPainter(
                    trazo: t.textoFuerte.withValues(alpha: 0.28),
                    renglon: t.textoFuerte.withValues(alpha: 0.16),
                    papel: t.papel,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La hoja de hoy está en blanco',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: t.textoFuerte,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'todavía es temprano',
                style: GoogleFonts.caveat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: LibretaColors.verde,
                ),
              ),
              if (totalAyer > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Los $hoy normalmente arrancas más tarde. '
                  'Ayer cerraste con ${MoneyFormatter.usd(totalAyer)}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: t.textoMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// La libretita del estado vacío: hoja con tres renglones.
class _LibretaPainter extends CustomPainter {
  const _LibretaPainter({
    required this.trazo,
    required this.renglon,
    required this.papel,
  });

  final Color trazo, renglon, papel;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 64;
    final hoja = RRect.fromRectAndRadius(
      Rect.fromLTWH(12 * k, 10 * k, 40 * k, 46 * k),
      Radius.circular(6 * k),
    );
    canvas.drawRRect(hoja, Paint()..color = papel);
    canvas.drawRRect(
      hoja,
      Paint()
        ..color = trazo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * k,
    );

    final linea = Paint()
      ..color = renglon
      ..strokeWidth = 2.5 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(21 * k, 26 * k), Offset(43 * k, 26 * k), linea);
    canvas.drawLine(Offset(21 * k, 34 * k), Offset(43 * k, 34 * k), linea);
    canvas.drawLine(Offset(21 * k, 42 * k), Offset(34 * k, 42 * k), linea);
  }

  @override
  bool shouldRepaint(covariant _LibretaPainter old) =>
      old.trazo != trazo || old.renglon != renglon || old.papel != papel;
}

// ---------------------------------------------------------------------------
// Auxiliares
// ---------------------------------------------------------------------------

class _BannerSinPermiso extends StatelessWidget {
  const _BannerSinPermiso();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0x1FF2A93C),
        border: Border.all(color: const Color(0x59F2A93C)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 17, color: LibretaColors.aviso),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'No pudimos cargar algunos datos. Revisa tu conexión.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.textoFuerte,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarNegocio extends StatelessWidget {
  const _AvatarNegocio({
    required this.fotoUrl,
    required this.iniciales,
    required this.onTap,
    this.insignia = 0,
  });

  final String? fotoUrl;
  final String iniciales;
  final VoidCallback onTap;

  /// Cuántas urgencias hay; `0` = sin insignia.
  final int insignia;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: LibretaColors.tarjetaOscura,
                shape: BoxShape.circle,
              ),
              child: fotoUrl != null && fotoUrl!.isNotEmpty
                  ? FotoRed(
                      fotoUrl!,
                      alError: Text(
                        iniciales,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : Text(
                      iniciales,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            if (insignia > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2A93C),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: t.papel, width: 2),
                  ),
                  child: Text(
                    '$insignia',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: LibretaColors.tarjetaOscura,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
