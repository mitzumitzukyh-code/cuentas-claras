import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/impresora/impresora_service.dart';
import '../../../services/impresora/ticket_esc_pos.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/auditoria_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/venta_repository.dart';
import '../domain/venta.dart';

/// Detalle de una venta (réplica visual de `P2 · DETALLE`, `Lote B · Ventas`).
///
/// Muestra las líneas, el total en USD/Bs y permite anular — solo al dueño
/// (CLAUDE.md §6), con confirmación previa.
class VentaDetalleScreen extends ConsumerStatefulWidget {
  const VentaDetalleScreen({super.key, required this.ventaId});

  final String ventaId;

  @override
  ConsumerState<VentaDetalleScreen> createState() => _VentaDetalleScreenState();
}

class _VentaDetalleScreenState extends ConsumerState<VentaDetalleScreen> {
  bool _anulando = false;
  bool _imprimiendo = false;

  /// Manda el detalle como texto por WhatsApp/lo que el teléfono ofrezca.
  /// No es una factura fiscal y el texto no pretende serlo.
  Future<void> _compartir(Venta venta) async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    final lineas = venta.items
        .map(
          (i) =>
              '• ${i.nombreCompleto} ×${i.cantidadLabel} — '
              '${MoneyFormatter.usd(i.subtotal)}',
        )
        .join('\n');

    final texto =
        StringBuffer()
          ..writeln(negocio?.nombre ?? 'Cuenta Clara')
          ..writeln('Venta del ${_fechaLarga(venta.fecha)}')
          ..writeln()
          ..writeln(lineas)
          ..writeln()
          ..writeln(
            'Total: ${MoneyFormatter.usd(venta.totalUSD)} · '
            '${MoneyFormatter.bs(venta.totalBs)}',
          )
          ..write('Pago: ${venta.metodoPago.etiquetaCorta}');

    await Share.share(texto.toString(), subject: 'Venta');
  }

  String _fechaLarga(DateTime f) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final m = f.minute.toString().padLeft(2, '0');
    return '${f.day} ${meses[f.month - 1]} · ${f.hour}:$m';
  }

  Future<void> _imprimir(Venta venta) async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (negocio == null) return;

    final config = await ref.read(impresoraServiceProvider).cargar();
    if (!mounted) return;

    if (!config.configurada) {
      final ir = await showDialog<bool>(
        context: context,
        builder:
            (d) => AlertDialog(
              title: const Text('Sin impresora'),
              content: const Text(
                'Todavía no has conectado una impresora de tickets. '
                '¿Quieres configurarla ahora?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(d).pop(false),
                  child: const Text('Ahora no'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(d).pop(true),
                  child: const Text('Configurar'),
                ),
              ],
            ),
      );
      if (ir == true && mounted) {
        await context.push(Routes.impresora);
      }
      return;
    }

    setState(() => _imprimiendo = true);
    try {
      final bytes = await TicketEscPos.generar(
        venta: venta,
        negocio: negocio,
        ancho: config.tamanoPapel,
      );
      await ref.read(impresoraServiceProvider).imprimir(config, bytes);
      if (mounted) _aviso('Ticket enviado a la impresora');
    } on ImpresoraException catch (e) {
      if (mounted) _aviso(e.mensaje);
    } catch (e) {
      if (mounted) _aviso('No se pudo imprimir: $e');
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  void _aviso(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _anular(Venta venta) async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (d) => AlertDialog(
            title: const Text('¿Anular esta venta?'),
            content: const Text(
              'La venta quedará marcada como anulada y el inventario volverá a su '
              'estado anterior. No se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(d).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
                child: const Text('Anular'),
              ),
            ],
          ),
    );
    if (confirmado != true) return;

    setState(() => _anulando = true);
    try {
      await ref
          .read(ventaRepositoryProvider)
          .anularVenta(membresia.negocioId, venta);
      // Anular es lo que más discusiones genera entre dueño y empleados:
      // queda anotado con nombre y hora (Lote E · P3).
      ref.read(auditoriaRepositoryProvider).anotar(
            membresia.negocioId,
            accion: 'anuló una venta',
            detalle: '${MoneyFormatter.usd(venta.totalUSD)} · '
                '${venta.items.length} '
                '${venta.items.length == 1 ? "producto" : "productos"}',
            autorNombre: membresia.nombreVisible,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta anulada y stock restituido')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo anular: $e'),
          backgroundColor: AppColors.peligro,
        ),
      );
    } finally {
      if (mounted) setState(() => _anulando = false);
    }
  }

  String _fechaHora(DateTime f) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final m = f.minute.toString().padLeft(2, '0');
    return '${f.day} ${meses[f.month - 1]} · $h:$m ${f.hour < 12 ? "am" : "pm"}';
  }

  @override
  Widget build(BuildContext context) {
    final esDueno = ref.watch(esDuenoProvider);
    final ventas = ref.watch(historialVentasProvider).valueOrNull ?? const [];
    final venta = ventas.where((v) => v.id == widget.ventaId).firstOrNull;

    if (venta == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Venta #${venta.id.substring(0, venta.id.length.clamp(0, 6))}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.libreta.textoFuerte,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        _fechaHora(venta.fecha),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // --- Líneas de la venta ---
              Container(
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < venta.items.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border:
                              i != venta.items.length - 1
                                  ? Border(
                                    bottom: BorderSide(
                                      color: context.libreta.renglon,
                                    ),
                                  )
                                  : null,
                        ),
                        child: Row(
                          children: [
                            _FotoItem(url: venta.items[i].fotoUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    venta.items[i].nombreCompleto,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.libreta.textoFuerte,
                                    ),
                                  ),
                                  Text(
                                    '${venta.items[i].cantidadLabel} × '
                                    '${MoneyFormatter.usd(venta.items[i].precioUnitario)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.libreta.textoMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              MoneyFormatter.usd(venta.items[i].subtotal),
                              style: AppTypography.money(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.libreta.textoFuerte,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              if (venta.anulada) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.peligroSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Esta venta fue anulada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.peligro,
                    ),
                  ),
                ),
              ] else if (venta.pendiente) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.avisoSuave,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Guardada sin señal — se confirmará sola con conexión',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.aviso,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // --- Productos + método + total ---
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _Dato(
                      etiqueta: 'Subtotal',
                      valor: MoneyFormatter.usd(venta.subtotalUSD),
                    ),
                    _Dato(
                      etiqueta: 'Método de pago',
                      valor: venta.metodoPago.etiqueta,
                    ),
                    if (venta.descuentoPct > 0)
                      _Dato(
                        etiqueta: 'Descuento (${venta.descuentoPct}%)',
                        valor: '− ${MoneyFormatter.usd(venta.descuentoUSD)}',
                      ),
                    if (venta.ivaUSD > 0)
                      _Dato(
                        etiqueta: 'IVA',
                        valor: MoneyFormatter.usd(venta.ivaUSD),
                      ),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: context.libreta.renglon),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: context.libreta.textoFuerte,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                MoneyFormatter.usd(venta.totalUSD),
                                style: AppTypography.money(
                                  fontSize: 20,
                                  color: LibretaColors.verde,
                                ),
                              ),
                              Text(
                                MoneyFormatter.bs(venta.totalBs),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.libreta.textoMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: LibretaSecondaryButton(
                      label: _imprimiendo ? 'Enviando…' : 'Reimprimir',
                      onPressed: _imprimiendo ? null : () => _imprimir(venta),
                      icon: Icon(
                        Icons.print_outlined,
                        size: 17,
                        color: context.libreta.textoFuerte,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LibretaSecondaryButton(
                      label: 'Compartir',
                      onPressed: () => _compartir(venta),
                      icon: const LibretaIcono(AppAssets.accCompartir,
                        size: 17,
                        color: LibretaColors.verde,
                      ),
                    ),
                  ),
                ],
              ),

              if (esDueno && !venta.anulada) ...[
                const SizedBox(height: 14),
                DottedBorderBox(
                  color: const Color(0x80F2A93C),
                  fondo: const Color(0x14F2A93C),
                  radius: 14,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 15,
                              color: LibretaColors.aviso,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'SOLO DUEÑO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                color: LibretaColors.aviso,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed:
                              (_anulando || venta.pendiente)
                                  ? null
                                  : () => _anular(venta),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF2A93C)),
                            foregroundColor: LibretaColors.aviso,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            venta.pendiente
                                ? 'Espera a que se confirme para anular'
                                : (_anulando ? 'Anulando…' : 'Anular venta'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _FotoItem extends StatelessWidget {
  const _FotoItem({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = url != null && url!.isNotEmpty;
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.libreta.papel,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child:
          tieneFoto
              ? FotoRed(
                url!,
                width: 42,
                height: 42,
                alError: LibretaIcono(AppAssets.navProductos,
                  size: 18,
                  color: context.libreta.textoMuted,
                ),
              )
              : LibretaIcono(AppAssets.navProductos,
                size: 18,
                color: context.libreta.textoMuted,
              ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.libreta.textoFuerte,
            ),
          ),
        ],
      ),
    );
  }
}
