import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../data/proveedor_repository.dart';
import '../domain/proveedor.dart';

/// Detalle de un proveedor (réplica visual de `P3 · DETALLE PROVEEDOR`,
/// `Lote H · Cierre y Proveedores`).
class ProveedorDetalleScreen extends ConsumerWidget {
  const ProveedorDetalleScreen({super.key, required this.proveedorInicial});

  /// El del `extra` de la ruta, congelado al navegar. Solo arranca la pantalla:
  /// lo que se pinta es el proveedor vivo, porque el saldo cambia al anotar una
  /// compra o un pago sin salir de aquí.
  final Proveedor proveedorInicial;

  String _fechaCorta(DateTime f) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${f.day} ${meses[f.month - 1]}';
  }

  String _vence(DateTime? f) {
    if (f == null) return '';
    final dias = f.difference(DateTime.now()).inDays;
    if (dias < 0) return ' · venció hace ${-dias} días';
    if (dias == 0) return ' · vence hoy';
    return ' · vence en $dias días';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedor =
        ref.watch(proveedorPorIdProvider(proveedorInicial.id)) ??
            proveedorInicial;
    final movimientosAsync = ref.watch(movimientosProveedorProvider(proveedor.id));
    final tasa = ref.watch(tasaActivaValorProvider);

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(oscuro: true, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proveedor.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte, letterSpacing: -0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('SALDO POR PAGAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.libreta.textoMuted)),
                    Text(
                      MoneyFormatter.usd(proveedor.saldoUSD),
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte, letterSpacing: -0.6),
                    ),
                    Text(
                      '${tasa == null ? "—" : MoneyFormatter.usdComoBs(proveedor.saldoUSD, tasa)}${_vence(proveedor.proximoVencimiento)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.libreta.textoFuerte),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              LibretaButton(
                label: 'Registrar pago',
                height: 48,
                onPressed: () => context.push(
                  Routes.proveedorMovimiento.replaceAll(':proveedorId', proveedor.id),
                  extra: {
                    'proveedorPreseleccionado': proveedor,
                    'tipoInicial': TipoMovimientoProveedor.pago,
                  },
                ),
              ),
              const SizedBox(height: 10),
              _BotonPedido(proveedor: proveedor),
              const SizedBox(height: 20),
              Text('MOVIMIENTOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.libreta.textoMuted)),
              const SizedBox(height: 4),
              movimientosAsync.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('No se pudo cargar: $e')),
                data: (movs) => movs.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('Sin movimientos todavía.', style: TextStyle(fontSize: 13, color: context.libreta.textoMuted)),
                      )
                    : Column(
                        children: [
                          for (final m in movs)
                            Container(
                              constraints: const BoxConstraints(minHeight: 52),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.libreta.renglon))),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.tipo == TipoMovimientoProveedor.pago ? 'Pago' : (m.concepto.isEmpty ? 'Compra de mercancía' : m.concepto),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte),
                                        ),
                                        Text(
                                          m.tipo == TipoMovimientoProveedor.compra
                                              ? '${_fechaCorta(m.fecha)} · a crédito'
                                              : m.concepto.isEmpty
                                                  ? _fechaCorta(m.fecha)
                                                  : '${_fechaCorta(m.fecha)} · ${m.concepto}',
                                          style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    m.tipo == TipoMovimientoProveedor.pago ? '−${MoneyFormatter.usd(m.montoUSD)}' : '+${MoneyFormatter.usd(m.montoUSD)}',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m.tipo == TipoMovimientoProveedor.pago ? LibretaColors.verde : context.libreta.textoFuerte),
                                  ),
                                ],
                              ),
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

/// "Pedir reabastecimiento": arma el pedido solo con los productos que están
/// en stock bajo y lo manda por WhatsApp (Lote H · F7).
///
/// La lista no se escribe a mano — se saca del inventario, que es justamente
/// el dato que la app ya tiene y el dueño tendría que ir a mirar producto por
/// producto.
class _BotonPedido extends ConsumerWidget {
  const _BotonPedido({required this.proveedor});

  final Proveedor proveedor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bajos = (ref.watch(productosProvider).valueOrNull ?? const <Producto>[])
        .where((p) => p.stockBajo)
        .toList();
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;

    Future<void> enviar() async {
      if (bajos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay productos en stock bajo por ahora.'),
          ),
        );
        return;
      }
      final lista = bajos
          .map((p) => '• ${p.nombre} — quedan ${p.cantidadLabel}')
          .join('\n');
      final borrador =
          'Hola ${proveedor.nombre} 👋 te escribo de '
          '${negocio?.nombre ?? "la bodega"}. Necesito reponer:\n\n'
          '$lista\n\n'
          '¿Me confirmas disponibilidad y precio? ¡Gracias!';
      final texto = await editarMensaje(
        context,
        titulo: 'Pedido a ${proveedor.nombre}',
        inicial: borrador,
      );
      if (texto == null || texto.isEmpty) return;
      final r =
          await abrirWhatsApp(texto: texto, telefono: proveedor.telefono);
      final aviso = avisoDe(r);
      if (aviso != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(aviso)));
      }
    }

    return LibretaSecondaryButton(
      label: bajos.isEmpty
          ? 'Nada en stock bajo'
          : 'Pedir reabastecimiento (${bajos.length})',
      onPressed: bajos.isEmpty ? null : enviar,
      icon: const LibretaIcono(AppAssets.catServicios,
        size: 18,
        color: LibretaColors.verde,
      ),
    );
  }
}
