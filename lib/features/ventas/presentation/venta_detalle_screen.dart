import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/impresora/impresora_service.dart';
import '../../../services/impresora/ticket_esc_pos.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/presentation/impresora_screen.dart';
import '../data/venta_repository.dart';
import '../domain/venta.dart';

/// Detalle de una venta (bloque `isVentaDetalle` del diseño).
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

  Future<void> _imprimir(Venta venta) async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (negocio == null) return;

    final config = await ref.read(impresoraServiceProvider).cargar();
    if (!mounted) return;

    // Sin impresora configurada, mandar a configurarla es más útil que un
    // error seco.
    if (!config.configurada) {
      final ir = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
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
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ImpresoraScreen()),
        );
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  Future<void> _anular(Venta venta) async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
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
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final m = f.minute.toString().padLeft(2, '0');
    return '${f.day}/${f.month}/${f.year} · $h:$m ${f.hour < 12 ? "am" : "pm"}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final esDueno = ref.watch(esDuenoProvider);
    final ventas = ref.watch(historialVentasProvider).valueOrNull ?? const [];
    final venta = ventas.where((v) => v.id == widget.ventaId).firstOrNull;

    if (venta == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  'Venta #${venta.id.substring(0, venta.id.length.clamp(0, 6))}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Líneas de la venta ---
            NeuCard(
              clip: true,
              child: Column(
                children: [
                  for (var i = 0; i < venta.items.length; i++)
                    NeuListTile(
                      divider: i != venta.items.length - 1,
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
                                    color: t.text,
                                  ),
                                ),
                                Text(
                                  '${venta.items[i].cantidadLabel} × '
                                  '${MoneyFormatter.usd(venta.items[i].precioUnitario)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.textSec,
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
                              color: t.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            if (venta.anulada) ...[
              const SizedBox(height: 18),
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
              const SizedBox(height: 18),
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
                  '⏳ Guardada sin señal — se confirmará sola con conexión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.aviso,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),

            // --- Total ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.marca,
                borderRadius: BorderRadius.circular(16),
                boxShadow: t.shadowBtn,
              ),
              child: Column(
                children: [
                  const Text(
                    'Total cobrado',
                    style: TextStyle(fontSize: 12, color: Color(0xD9FFFFFF)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    MoneyFormatter.usd(venta.totalUSD),
                    style: AppTypography.money(
                      fontSize: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MoneyFormatter.bs(venta.totalBs),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xD9FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // --- Datos ---
            NeuCard(
              clip: true,
              child: Column(
                children: [
                  _Dato(etiqueta: 'Fecha', valor: _fechaHora(venta.fecha)),
                  _Dato(
                    etiqueta: 'Método de pago',
                    valor: venta.metodoPago.etiqueta,
                  ),
                  if (venta.descuentoPct > 0) ...[
                    _Dato(
                      etiqueta: 'Subtotal',
                      valor: MoneyFormatter.usd(venta.subtotalUSD),
                    ),
                    _Dato(
                      etiqueta: 'Descuento (${venta.descuentoPct}%)',
                      valor: '− ${MoneyFormatter.usd(venta.descuentoUSD)}',
                    ),
                  ],
                  if (venta.ivaUSD > 0)
                    _Dato(
                      etiqueta: 'IVA (16%)',
                      valor: MoneyFormatter.usd(venta.ivaUSD),
                    ),
                  _Dato(
                    etiqueta: 'Tasa BCV usada',
                    valor: MoneyFormatter.bs(venta.tasaBcvUsada),
                  ),
                  _Dato(
                    etiqueta: 'N.º de recibo',
                    valor: venta.id.substring(0, venta.id.length.clamp(0, 6)),
                    ultima: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            NeuSecondaryButton(
              label: _imprimiendo ? 'Enviando…' : '🖨️ Imprimir ticket',
              onPressed: _imprimiendo ? null : () => _imprimir(venta),
            ),

            // Anular: solo el dueño, y solo si sigue activa (CLAUDE.md §6).
            //
            // Mientras la venta esté pendiente de sincronizar, anular exige
            // una transacción con el servidor igual que registrarla — sin
            // señal se quedaría esperando para siempre. Se deshabilita en vez
            // de dejar al dueño con un botón que gira sin fin.
            if (esDueno && !venta.anulada) ...[
              const SizedBox(height: 12),
              NeuSecondaryButton(
                label: venta.pendiente
                    ? 'Espera a que se confirme para anular'
                    : (_anulando ? 'Anulando…' : 'Anular venta'),
                color: AppColors.peligro,
                background: AppColors.peligroSuave,
                onPressed: (_anulando || venta.pendiente)
                    ? null
                    : () => _anular(venta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Miniatura de un item de venta: la foto congelada al vender, o el
/// paquete genérico si no había foto (o falló al cargar).
class _FotoItem extends StatelessWidget {
  const _FotoItem({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tieneFoto = url != null && url!.isNotEmpty;
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.pageBg,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: tieneFoto
          ? Image.network(
              url!,
              fit: BoxFit.cover,
              width: 42,
              height: 42,
              errorBuilder: (_, __, ___) =>
                  const Text('📦', style: TextStyle(fontSize: 18)),
            )
          : const Text('📦', style: TextStyle(fontSize: 18)),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({
    required this.etiqueta,
    required this.valor,
    this.ultima = false,
  });

  final String etiqueta;
  final String valor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return NeuListTile(
      divider: !ultima,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 13, color: t.textSec)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}
