import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../productos/data/producto_repository.dart';
import '../../reportes/presentation/reportes_screen.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/presentation/historial_screen.dart';

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
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final ventasHoy = ref.watch(ventasDelDiaProvider).valueOrNull ?? const [];

    final avisos = <_Aviso>[];

    // Cerrar esta pantalla antes de navegar evita apilar Notificaciones debajo
    // de la pantalla destino.
    void irA(Widget destino) {
      Navigator.of(context)
        ..pop()
        ..push(MaterialPageRoute<void>(builder: (_) => destino));
    }

    void irAProductos() {
      Navigator.of(context).pop();
      context.go(Routes.productos);
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
        onTap: () => irA(const HistorialScreen()),
      ));
    }

    // --- Meta mensual ---
    final meta = negocio?.metaMensualUsd ?? 0;
    if (meta > 0) {
      final total = ventasHoy.fold<double>(0, (s, v) => s + v.totalUSD);
      final pct = ((total / meta) * 100).clamp(0, 100).toStringAsFixed(0);
      avisos.add(_Aviso(
        icono: '🎯',
        titulo: 'Vas al $pct % de tu meta',
        detalle: 'Meta mensual: ${MoneyFormatter.usd(meta)}',
        onTap: () => irA(const ReportesScreen()),
      ));
    }

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
                  'Notificaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (avisos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    const Text('🔔', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 10),
                    Text(
                      'Todo en orden',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No hay nada que requiera tu atención.',
                      style: TextStyle(fontSize: 13, color: t.textSec),
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

  /// A dónde lleva el aviso. Un aviso que no hace nada al tocarlo frustra más
  /// que informar, así que todos llevan a la pantalla donde se resuelve.
  final VoidCallback onTap;

  /// Los urgentes (algo agotado) se pintan en rojo suave.
  final bool urgente;
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso});

  final _Aviso aviso;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuCard(
      small: true,
      radius: 20,
      onTap: aviso.onTap,
      padding: const EdgeInsets.all(14),
      color: aviso.urgente ? AppColors.peligroSuave : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: aviso.urgente ? Colors.white : t.tint,
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
                    color: aviso.urgente ? AppColors.peligro : t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  aviso.detalle,
                  style: TextStyle(fontSize: 13, color: t.textSec),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
