import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/notificaciones/push_service.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../notificaciones/presentation/notificaciones_screen.dart';
import '../../productos/data/producto_repository.dart';
import '../../reportes/data/reportes_providers.dart';
import '../../reportes/domain/periodo_reporte.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/domain/venta.dart';
import '../../ventas/presentation/historial_screen.dart';
import '../../ventas/presentation/venta_detalle_screen.dart';
import '../../ventas/presentation/ventas_pendientes_screen.dart';

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
    // Antes las notificaciones de tasa solo se activaban si el dueño
    // encontraba el botón "Permitir avisos" en Ajustes — muchos nunca
    // llegaban a verlo y se quedaban sin ninguna, sin saber por qué. Esto lo
    // pide solo, una vez en la vida de la instalación (ver push_service.dart).
    ref.watch(autoPedirPermisoTasaProvider);
    // Deja el token de este dispositivo listo en la membresía del dueño para
    // el resumen de ventas del día (ver push_service.dart).
    ref.watch(registrarTokenVentasProvider);
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final ventas =
        ref.watch(ventasDelDiaProvider).valueOrNull ?? const <Venta>[];
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final tasa = ref.watch(bcvRateProvider).valueOrNull;
    final pendientes = ref.watch(ventasPendientesProvider);

    final totalUsdHoy = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    final gananciaHoy = ventas.fold<double>(0, (s, v) => s + v.gananciaUSD);
    final itemsHoy = ventas.fold<int>(0, (s, v) => s + v.items.length);
    final itemsSinCosto = ventas.fold<int>(0, (s, v) => s + v.itemsSinCosto);
    final stockBajo = productos.where((p) => p.stockBajo).length;
    final nombre = negocio?.nombre ?? 'Mi negocio';

    // Si Firestore rechaza las consultas (reglas no desplegadas, sin permiso),
    // el dashboard se vería vacío y sin explicación. Mejor decirlo.
    final falloDatos =
        ref.watch(negocioActivoProvider).hasError ||
        ref.watch(ventasDelDiaProvider).hasError ||
        ref.watch(productosProvider).hasError;

    // Foto de fondo opcional (Ajustes de la cuenta). Se muestra sin ningún
    // velo encima — hasta un blanco al 35 % se veía como neblina sobre una
    // foto con mucho color. Las tarjetas ya son opacas y no necesitan nada
    // más; los textos que quedan directo sobre la foto (fuera de cualquier
    // tarjeta) llevan su propio fondito opaco (`_ChipLegible`) en vez de
    // sombra — con texto oscuro, una sombra oscura no da suficiente
    // contraste contra una foto clara.
    final tieneFondo =
        (negocio?.fotoComoFondo ?? false) &&
        (negocio?.fotoUrl?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: tieneFondo ? Colors.transparent : null,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.inicio),
      body: Stack(
        children: [
          if (tieneFondo) ...[
            // Sin velo encima: cualquier color plano de por medio (hasta
            // blanco al 35 %) se veía como neblina sobre una foto con tanto
            // color. La foto se ve tal cual — los textos que quedan directo
            // sobre ella llevan su propio fondito opaco (`_ChipLegible`) en
            // vez de tapar la foto entera.
            Positioned.fill(
              child: FotoRed(
                negocio!.fotoUrl!,
                alError: Container(color: t.pageBg),
              ),
            ),
          ],
          SafeArea(
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

                  if (pendientes.isNotEmpty) ...[
                    _BannerVentasPendientes(cantidad: pendientes.length),
                    const SizedBox(height: 16),
                  ],

                  // --- Saludo + acciones ---
                  Row(
                    children: [
                      Expanded(
                        child: _ChipLegible(
                          activo: tieneFondo,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _saludo(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: t.textSec,
                                ),
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
                      ),
                      _Campana(
                        // Punto de aviso solo si hay algo que atender.
                        conAviso: stockBajo > 0,
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificacionesScreen(),
                              ),
                            ),
                      ),
                      const SizedBox(width: 10),
                      _AvatarNegocio(
                        fotoUrl: negocio?.fotoUrl,
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
                    // Sin ningún costo registrado la ganancia no existe: la
                    // tarjeta invita a registrarlos en vez de mostrar un cero
                    // falso o repetir el total como si todo fuera ganancia.
                    ganancia:
                        itemsHoy > 0 && itemsSinCosto < itemsHoy
                            ? gananciaHoy
                            : null,
                    gananciaParcial: itemsSinCosto > 0,
                    invitarACostos: itemsHoy > 0 && itemsSinCosto == itemsHoy,
                  ),
                  const SizedBox(height: 18),

                  // --- Tasa BCV ---
                  _FilaTasaBcv(
                    tasa: tasa?.tasa,
                    tasaAnterior: ref.watch(bcvRateAnteriorProvider)?.tasa,
                  ),
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
                      // La meta es del MES: suma todas sus ventas con la consulta
                      // por rango, no solo las de hoy. Mientras carga se muestra
                      // lo de hoy, que es el piso conocido.
                      logrado:
                          ref
                              .watch(ventasReporteProvider(PeriodoReporte.mes))
                              .valueOrNull
                              ?.where((v) => !v.anulada)
                              .fold<double>(0, (s, v) => s + v.totalUSD) ??
                          totalUsdHoy,
                      meta: negocio!.metaMensualUsd,
                    ),
                  ],

                  const SizedBox(height: 18),

                  // --- Actividad reciente ---
                  _ChipLegible(
                    activo: tieneFondo,
                    child: Row(
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
                          onTap:
                              () => Navigator.of(context).push(
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
        ],
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

/// Avisa de ventas hechas sin señal que todavía no confirma el servidor.
///
/// Se sincronizan solas; esto es solo visibilidad para que el dueño no tenga
/// que confiar a ciegas, sobre todo con varios vendedores cobrando a la vez.
class _BannerVentasPendientes extends StatelessWidget {
  const _BannerVentasPendientes({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const VentasPendientesScreen(),
            ),
          ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.avisoSuave,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('⏳', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cantidad == 1
                    ? '1 venta esperando señal para subirse'
                    : '$cantidad ventas esperando señal para subirse',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.aviso,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.aviso, size: 18),
          ],
        ),
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

/// Fondito opaco para el texto que, con la foto de fondo activada, quedaría
/// flotando directo sobre ella. Sin [activo] es un passthrough — no cambia
/// nada del layout normal (sin foto de fondo).
class _ChipLegible extends StatelessWidget {
  const _ChipLegible({required this.activo, required this.child});

  final bool activo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!activo) return child;
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        boxShadow: t.shadowRaisedSm,
      ),
      child: child,
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

/// Avatar circular con la foto del negocio (Ajustes), o su inicial si no hay.
class _AvatarNegocio extends StatelessWidget {
  const _AvatarNegocio({
    required this.fotoUrl,
    required this.inicial,
    required this.onTap,
  });

  final String? fotoUrl;
  final String inicial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tieneFoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.marca,
          shape: BoxShape.circle,
          boxShadow: t.shadowBtn,
        ),
        alignment: Alignment.center,
        child:
            tieneFoto
                ? FotoRed(
                  fotoUrl!,
                  width: 42,
                  height: 42,
                  alError: Text(
                    inicial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                : Text(
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
    this.ganancia,
    this.gananciaParcial = false,
    this.invitarACostos = false,
  });

  final double totalUsd;
  final double? tasa;
  final int cobros;

  /// Ganancia del día, o `null` si no hay forma de calcularla.
  final double? ganancia;

  /// `true` si alguna línea vendida no tenía costo y quedó fuera del cálculo.
  final bool gananciaParcial;

  /// `true` si hubo ventas pero ningún producto tiene costo registrado.
  final bool invitarACostos;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
              if (ganancia != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      // "≈" cuando alguna línea no tenía costo: la cifra es
                      // parcial y se nota, no se disimula.
                      'Ganancia: ${gananciaParcial ? "≈" : ""}'
                      '${MoneyFormatter.usd(ganancia!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (invitarACostos) ...[
            const SizedBox(height: 10),
            const Text(
              'Registra el costo de tus productos para ver tu ganancia real.',
              style: TextStyle(fontSize: 11.5, color: Color(0xD9FFFFFF)),
            ),
          ],
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
  const _FilaTasaBcv({required this.tasa, this.tasaAnterior});

  final double? tasa;

  /// Tasa del día anterior, para mostrar cuánto se movió hoy aunque el
  /// cambio sea demasiado chico para disparar una notificación (esas solo
  /// avisan a partir de 0,1 %; aquí se ve el movimiento exacto, sea el que
  /// sea).
  final double? tasaAnterior;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final variacion =
        (tasa != null && tasaAnterior != null && tasaAnterior! > 0)
            ? (tasa! - tasaAnterior!) / tasaAnterior! * 100
            : null;

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
          if (variacion == null)
            Text(
              'Referencia de hoy',
              style: TextStyle(fontSize: 11, color: t.muted),
            )
          else
            _ChipVariacion(variacion: variacion),
        ],
      ),
    );
  }
}

/// "▲ +0,04%" en verde, "▼ −0,04%" en rojo, o "Sin cambios" si es cero —
/// el movimiento exacto del día, por chico que sea.
class _ChipVariacion extends StatelessWidget {
  const _ChipVariacion({required this.variacion});

  final double variacion;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (variacion.abs() < 0.005) {
      return Text(
        'Sin cambios hoy',
        style: TextStyle(fontSize: 11, color: t.muted),
      );
    }
    final subio = variacion > 0;
    final color = subio ? AppColors.marca : AppColors.peligro;
    final flecha = subio ? '▲' : '▼';
    final texto =
        '$flecha ${subio ? '+' : '−'}${variacion.abs().toStringAsFixed(2).replaceAll('.', ',')}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
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
      onTap:
          () => Navigator.of(context).push(
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
