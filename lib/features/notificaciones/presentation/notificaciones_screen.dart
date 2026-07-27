import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import 'aviso_notificaciones.dart';
import '../../productos/data/producto_repository.dart';
import '../../reportes/data/reportes_providers.dart';
import '../../reportes/domain/periodo_reporte.dart';
import '../../ventas/data/venta_repository.dart';

/// Notificaciones (bloque `isNotificaciones` del diseño).
///
/// No hay colección de notificaciones en Firestore: se derivan del estado real
/// del negocio (stock bajo, vencimientos, ventas del día, meta mensual). Cuando
/// existan las push por Cloud Functions, esta pantalla las mostrará junto a
/// estas locales.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final ventasHoy = ref.watch(ventasDelDiaProvider).valueOrNull ?? const [];

    final avisos = <_Aviso>[];

    void irA(String ruta) {
      Navigator.of(context).pop();
      context.push(ruta);
    }

    void irAProductos() {
      Navigator.of(context).pop();
      context.go(Routes.productos);
    }

    void irAReportes() {
      Navigator.of(context).pop();
      context.go(Routes.reportes);
    }

    // --- Stock bajo ---
    if (negocio?.alertaStockActiva ?? true) {
      final bajos = productos.where((p) => p.stockBajo).toList();
      final agotados = bajos.where((p) => p.cantidad == 0).toList();

      if (agotados.isNotEmpty) {
        avisos.add(_Aviso(
          icono: '🛑',
          titulo: agotados.length == 1
              ? '${agotados.first.nombre} se agotó'
              : '${agotados.length} productos agotados',
          detalle: agotados.map((p) => p.nombre).take(3).join(', '),
          urgente: true,
          onTap: irAProductos,
        ));
      }

      final porAgotarse = bajos.where((p) => p.cantidad > 0).toList();
      if (porAgotarse.isNotEmpty) {
        avisos.add(_Aviso(
          icono: '⚠️',
          titulo: porAgotarse.length == 1
              ? 'Queda poco de ${porAgotarse.first.nombre}'
              : '${porAgotarse.length} productos por agotarse',
          detalle: porAgotarse
              .map((p) => '${p.nombre} (${p.cantidadLabel})')
              .take(3)
              .join(', '),
          onTap: irAProductos,
        ));
      }
    }

    // --- Vencimientos próximos (rubro belleza) ---
    final limite = DateTime.now().add(const Duration(days: 30));
    final porVencer = productos
        .where((p) =>
            p.fechaVencimiento != null && p.fechaVencimiento!.isBefore(limite))
        .toList();
    if (porVencer.isNotEmpty) {
      avisos.add(_Aviso(
        icono: '📅',
        titulo: '${porVencer.length} '
            '${porVencer.length == 1 ? "producto vence" : "productos vencen"} pronto',
        detalle: porVencer.map((p) => p.nombre).take(3).join(', '),
        onTap: irAProductos,
      ));
    }

    // --- Resumen del día ---
    if (ventasHoy.isNotEmpty) {
      final total = ventasHoy.fold<double>(0, (s, v) => s + v.totalUSD);
      avisos.add(_Aviso(
        icono: '💰',
        titulo: 'Llevas ${MoneyFormatter.usd(total)} hoy',
        detalle: '${ventasHoy.length} '
            '${ventasHoy.length == 1 ? "cobro registrado" : "cobros registrados"}',
        onTap: () => irA(Routes.historialVentas),
      ));
    }

    // --- Meta mensual ---
    final meta = negocio?.metaMensualUsd ?? 0;
    if (meta > 0) {
      final inicioMes = DateTime(DateTime.now().year, DateTime.now().month);
      final ventasMes = ref.watch(ventasReporteProvider(PeriodoReporte.mes));
      final total =
          ventasMes.valueOrNull
              ?.where((v) => !v.anulada && !v.fecha.isBefore(inicioMes))
              .fold<double>(0, (s, v) => s + v.totalUSD) ??
          ventasHoy.fold<double>(0, (s, v) => s + v.totalUSD);
      final pct = ((total / meta) * 100).clamp(0, 100).toStringAsFixed(0);
      avisos.add(_Aviso(
        icono: '🎯',
        titulo: 'Vas al $pct % de tu meta',
        detalle: 'Meta mensual: ${MoneyFormatter.usd(meta)}',
        onTap: irAReportes,
      ));
    }

    return Scaffold(
      backgroundColor: t.papel,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                LibretaBackButton(
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notificaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const AvisoNotificaciones(permitirDescartar: false),

            if (avisos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    _CampanaAnimada(),
                    const SizedBox(height: 10),
                    Text(
                      'Todo en orden',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.textoFuerte,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No hay nada que requiera tu atención.',
                      style: TextStyle(fontSize: 13, color: t.textoMuted),
                    ),
                  ],
                ),
              )
            else
              for (final a in avisos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TarjetaAviso(aviso: a),
                ),
          ],
        ),
      ),
    );
  }
}

/// Un aviso derivado del estado del negocio.
class _Aviso {
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
    this.urgente = false,
  });

  final String icono;
  final String titulo;
  final String detalle;

  final VoidCallback onTap;

  /// Los urgentes (algo agotado) se pintan en rojo suave.
  final bool urgente;
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso});

  final _Aviso aviso;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: aviso.onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: aviso.urgente
              ? LibretaColors.peligro.withValues(alpha: 0.1)
              : t.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.bordeSuave),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: aviso.urgente ? Colors.white : t.bordeSuave,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(aviso.icono, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aviso.titulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: aviso.urgente ? LibretaColors.peligro : t.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    aviso.detalle,
                    style: TextStyle(fontSize: 13, color: t.textoMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campana que entra con rebote y se mece suavemente.
class _CampanaAnimada extends StatefulWidget {
  @override
  State<_CampanaAnimada> createState() => _CampanaAnimadaState();
}

class _CampanaAnimadaState extends State<_CampanaAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final rotacion = Curves.elasticOut.transform(_ctrl.value);
        return Transform.rotate(
          angle: (-0.15 + 0.3 * rotacion).clamp(-0.15, 0.15),
          child: Opacity(opacity: _ctrl.value, child: child),
        );
      },
      child: const Text('🔔', style: TextStyle(fontSize: 32)),
    );
  }
}
