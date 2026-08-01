import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/proveedor_repository.dart';
import '../domain/proveedor.dart';
import 'anotar_movimiento_proveedor_screen.dart';

final _busquedaProveedorProvider = StateProvider<String>((_) => '');

/// Cuentas por pagar (réplica visual de `P2 · CUENTAS POR PAGAR`, `Lote H ·
/// Cierre y Proveedores`).
class ProveedoresScreen extends ConsumerWidget {
  const ProveedoresScreen({super.key});

  String _vence(DateTime? f) {
    if (f == null) return '';
    final dias = f.difference(DateTime.now()).inDays;
    if (dias < 0) return 'venció hace ${-dias} días';
    if (dias == 0) return 'vence hoy';
    return 'vence en $dias días';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proveedoresAsync = ref.watch(proveedoresProvider);
    final tasa = ref.watch(tasaActivaValorProvider);
    final busqueda = ref.watch(_busquedaProveedorProvider);

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: proveedoresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar: $e', textAlign: TextAlign.center, style: TextStyle(color: context.libreta.textoMuted)),
              ),
            ),
            data: (todos) {
              final conDeuda = todos.where((p) => p.saldoUSD > 0).toList();
              final total = conDeuda.fold<double>(0, (s, p) => s + p.saldoUSD);

              final filtrados = busqueda.isEmpty
                  ? conDeuda
                  : conDeuda
                      .where((p) =>
                          p.nombre.toLowerCase().contains(busqueda.toLowerCase()))
                      .toList();

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(24, 30, 22, 100),
                    children: [
                      Text(
                        'Por pagar',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte, letterSpacing: -0.4),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        decoration: BoxDecoration(color: LibretaColors.tarjetaOscura, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.libreta.bordeHero, width: 1.5)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DEUDA A PROVEEDORES',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0x99FFFFFF)),
                            ),
                            Text(
                              MoneyFormatter.usd(total),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6),
                            ),
                            Text(
                              tasa == null
                                  ? '${conDeuda.length} ${conDeuda.length == 1 ? "proveedor" : "proveedores"}'
                                  : '${MoneyFormatter.usdComoBs(total, tasa)} · '
                                      '${conDeuda.length} ${conDeuda.length == 1 ? "proveedor" : "proveedores"}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xBFFFFFFF)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (conDeuda.isEmpty)
                        LibretaEstadoVacio(
                          ilustracion: Ilustracion.sinFiados,
                          titulo: 'No le debes a nadie',
                          detalle: 'Aquí verás tus deudas a proveedores y '
                              'cuándo vencen, para no perder la cuenta.',
                          tagline: 'deuda cero, mente tranquila',
                          boton: LibretaButton(
                            label: 'Nueva deuda',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AnotarMovimientoProveedorScreen(),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          'PROVEEDORES',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.libreta.textoMuted),
                        ),
                        const SizedBox(height: 8),
                        _BuscadorProveedores(),
                        const SizedBox(height: 4),
                        if (filtrados.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: LibretaEstadoVacio(
                              ilustracion: Ilustracion.sinResultados,
                              titulo: 'Sin resultados',
                              detalle: 'Ningún proveedor coincide con la búsqueda',
                            ),
                          )
                        else
                          for (final p in filtrados)
                            _FilaProveedor(
                              proveedor: p,
                              vence: _vence(p.proximoVencimiento),
                              tasa: tasa,
                              onTap: () => context.push(Routes.proveedorDetalle.replaceAll(':proveedorId', p.id), extra: p),
                            ),
                      ],
                    ],
                  ),
                  Positioned(
                    left: 54,
                    right: 22,
                    bottom: 16,
                    child: LibretaButton(
                      label: 'Nueva deuda',
                      icon: const Icon(Icons.add, size: 19, color: Colors.white),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const AnotarMovimientoProveedorScreen()),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Buscador de proveedores.
class _BuscadorProveedores extends ConsumerWidget {
  const _BuscadorProveedores();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (v) => ref.read(_busquedaProveedorProvider.notifier).state = v,
      style: TextStyle(fontSize: 14, color: context.libreta.textoFuerte),
      decoration: InputDecoration(
        hintText: 'Buscar proveedor…',
        hintStyle: TextStyle(color: context.libreta.textoMuted),
        prefixIcon: LibretaIcono(AppAssets.accBuscar, size: 20, color: context.libreta.textoMuted),
        filled: true,
        fillColor: context.libreta.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _FilaProveedor extends StatelessWidget {
  const _FilaProveedor({required this.proveedor, required this.vence, required this.tasa, required this.onTap});

  final Proveedor proveedor;
  final String vence;
  final double? tasa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final porVencerPronto = proveedor.proximoVencimiento != null &&
        proveedor.proximoVencimiento!.difference(DateTime.now()).inDays <= 5;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.libreta.renglon))),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0x1F0E9F6E), borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: const LibretaIcono(AppAssets.catBodega, size: 19, color: LibretaColors.verde),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(proveedor.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.libreta.textoFuerte)),
                  if (vence.isNotEmpty)
                    Text(vence, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: porVencerPronto ? LibretaColors.aviso : context.libreta.textoMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(MoneyFormatter.usd(proveedor.saldoUSD), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte)),
                if (tasa != null)
                  Text(
                    MoneyFormatter.bs(MoneyFormatter.convertirABs(proveedor.saldoUSD, tasa!)),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.libreta.textoMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
