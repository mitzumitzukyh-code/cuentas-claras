import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/historial_tasa_provider.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/entrada_animada.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../cierre/data/cierre_repository.dart';
import '../../fiados/data/fiado_repository.dart';
import '../../gastos/data/gasto_repository.dart';
import '../../productos/data/producto_repository.dart';
import '../../proveedores/data/proveedor_repository.dart';
import '../../ventas/data/venta_repository.dart';

/// Algo que el dueño debería atender (`Lote P · P0/P2`).
///
/// Todas las urgencias comparten forma para que la lista sea homogénea; lo
/// que cambia es el peso: la de mayor [prioridad] sube a tarjeta destacada y
/// el resto quedan como renglones.
class Urgencia {
  const Urgencia({
    required this.clave,
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.ruta,
    required this.prioridad,
    this.accion,
    this.grave = false,
  });

  /// Identificador estable, para poder excluirla de la lista cuando ya está
  /// ocupando el lugar destacado.
  final String clave;

  final String titulo;
  final String detalle;
  final IconData icono;
  final String ruta;

  /// Menor = más urgente.
  final int prioridad;

  /// Texto del botón cuando se muestra destacada.
  final String? accion;

  /// `true` pinta el renglón con borde ámbar (plata en juego).
  final bool grave;
}

/// Todo lo pendiente, ya ordenado por prioridad.
///
/// El orden no es arbitrario: primero lo que descuadra la caja, después lo que
/// es plata sin cobrar, después lo que impide vender, y de último lo que solo
/// deja de traer clientes.
final urgenciasProvider = Provider<List<Urgencia>>((ref) {
  final lista = <Urgencia>[];

  // 1 · Caja sin cerrar.
  final cierreHoy = ref.watch(cierreDeHoyProvider).valueOrNull;
  final ventas = ref.watch(ventasDelDiaProvider).valueOrNull ?? const [];
  if (cierreHoy == null && ventas.isNotEmpty) {
    final total = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
    lista.add(Urgencia(
      clave: 'caja',
      titulo: 'Te falta cerrar la caja de hoy',
      detalle: 'Llevas ${MoneyFormatter.usd(total)} sin cuadrar.',
      icono: Icons.warning_amber_rounded,
      ruta: Routes.arqueo,
      accion: 'Cerrar caja ahora',
      prioridad: 1,
      grave: true,
    ));
  }

  // 2 · Fiados vencidos.
  final clientes = ref.watch(clientesFiadoProvider).valueOrNull ?? const [];
  final ahora = DateTime.now();
  final vencidos = clientes
      .where((c) =>
          c.saldoUSD > 0 && ahora.difference(c.actualizadoEn).inDays >= 15)
      .toList()
    ..sort((a, b) => a.actualizadoEn.compareTo(b.actualizadoEn));
  if (vencidos.isNotEmpty) {
    final deuda = vencidos.fold<double>(0, (s, c) => s + c.saldoUSD);
    final masViejo = ahora.difference(vencidos.first.actualizadoEn).inDays;
    lista.add(Urgencia(
      clave: 'fiados',
      titulo: vencidos.length == 1
          ? '1 fiado vencido'
          : '${vencidos.length} fiados vencidos',
      detalle: '${MoneyFormatter.usd(deuda)} por cobrar · '
          'el más viejo, $masViejo días',
      icono: Icons.schedule_rounded,
      ruta: Routes.fiados,
      accion: 'Ver fiados',
      prioridad: 2,
      grave: true,
    ));
  }

  // 3 · Productos en cero.
  final productos = ref.watch(productosConAlertaProvider).valueOrNull ?? const [];
  final enCero = productos.where((p) => p.cantidad <= 0).toList();
  final bajos = productos.where((p) => p.cantidad > 0 && p.stockBajo).toList();
  if (enCero.isNotEmpty) {
    lista.add(Urgencia(
      clave: 'cero',
      titulo: enCero.length == 1
          ? 'Se acabó ${enCero.first.nombre}'
          : 'Se acabaron ${enCero.length} productos',
      detalle: enCero.take(2).map((p) => p.nombre).join(' y ') +
          (enCero.length > 2 ? ' y otros' : ' en cero'),
      icono: Icons.inventory_2_outlined,
      ruta: Routes.productos,
      accion: 'Ver mercancía',
      prioridad: 3,
      grave: true,
    ));
  } else if (bajos.isNotEmpty) {
    final p = bajos.first;
    lista.add(Urgencia(
      clave: 'bajo',
      titulo: 'Se está acabando ${p.nombre}',
      detalle: 'quedan ${p.cantidadLabel}',
      icono: Icons.inventory_2_outlined,
      ruta: Routes.productos,
      prioridad: 5,
    ));
  }

  // 4 · Deuda a proveedor.
  final proveedores = ref.watch(proveedoresProvider).valueOrNull ?? const [];
  final conDeuda = proveedores.where((p) => p.saldoUSD > 0).toList()
    ..sort((a, b) => b.saldoUSD.compareTo(a.saldoUSD));
  if (conDeuda.isNotEmpty) {
    final p = conDeuda.first;
    lista.add(Urgencia(
      clave: 'proveedor',
      titulo: 'Le debes a ${p.nombre}',
      detalle: MoneyFormatter.usd(p.saldoUSD),
      icono: Icons.local_shipping_outlined,
      ruta: Routes.proveedores,
      prioridad: 4,
    ));
  }

  // 5 · Gastos sin anotar (Lote P · P1, "Mientras esperas").
  //
  // Con un par de días sin registrar nada, la ganancia del mes queda inflada:
  // se vio lo que entró y no lo que salió. Es la única forma de llegar a
  // Gastos desde Inicio, y es la que el diseño eligió.
  final gastos = ref.watch(gastosDelMesProvider).valueOrNull ?? const [];
  final ahoraG = DateTime.now();
  final ultimoGasto = gastos.isEmpty
      ? null
      : gastos.map((g) => g.fecha).reduce((a, b) => a.isAfter(b) ? a : b);
  final diasSinGastos =
      ultimoGasto == null ? null : ahoraG.difference(ultimoGasto).inDays;
  if (diasSinGastos == null || diasSinGastos >= 2) {
    lista.add(Urgencia(
      clave: 'gastos',
      titulo: 'Anota lo que compraste',
      detalle: diasSinGastos == null
          ? 'todavía no registras gastos este mes'
          : 'llevas $diasSinGastos días sin registrar ninguno',
      icono: Icons.edit_outlined,
      ruta: Routes.gastos,
      prioridad: 7,
    ));
  }

  // 6 · Ventas sin subir.
  final pendientes = ref.watch(ventasPendientesProvider);
  if (pendientes.isNotEmpty) {
    lista.add(Urgencia(
      clave: 'pendientes',
      titulo: pendientes.length == 1
          ? '1 venta sin subir'
          : '${pendientes.length} ventas sin subir',
      detalle: 'se suben solas al volver el internet',
      icono: Icons.cloud_upload_outlined,
      ruta: Routes.ventasPendientes,
      prioridad: 8,
    ));
  }

  lista.sort((a, b) => a.prioridad.compareTo(b.prioridad));
  return lista;
});

/// La urgencia que se lleva el lugar destacado. `null` = día tranquilo.
///
/// Solo asciende lo verdaderamente grave; una sugerencia suelta no merece
/// desplazar al botón de Cobrar.
final urgenciaPrincipalProvider = Provider<Urgencia?>((ref) {
  final lista = ref.watch(urgenciasProvider);
  final primera = lista.isEmpty ? null : lista.first;
  return (primera != null && primera.grave) ? primera : null;
});

// ---------------------------------------------------------------------------
// Tarjeta destacada "Antes de cerrar"
// ---------------------------------------------------------------------------

/// Tarjeta navy que ocupa el lugar del héroe cuando hay algo grave
/// (`Lote P · P2`).
class TarjetaUrgencia extends StatelessWidget {
  const TarjetaUrgencia({super.key, required this.urgencia});

  final Urgencia urgencia;

  @override
  Widget build(BuildContext context) {
    return EntradaAnimada(
      retardo: const Duration(milliseconds: 90),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: LibretaColors.tarjetaOscura,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.libreta.bordeHero, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(urgencia.icono, size: 18, color: const Color(0xFFF2A93C)),
                const SizedBox(width: 9),
                const Text(
                  'ANTES DE CERRAR',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: Color(0xFFF2A93C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              urgencia.titulo,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.25,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              urgencia.detalle,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: Color(0xB3FFFFFF),
              ),
            ),
            if (urgencia.accion != null) ...[
              const SizedBox(height: 13),
              GestureDetector(
                onTap: () => context.push(urgencia.ruta),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2A93C),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    urgencia.accion!,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: LibretaColors.tarjetaOscura,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasa vencida
// ---------------------------------------------------------------------------

/// Tarjeta blanca con borde ámbar (`Lote P · P3`).
///
/// Una tasa de anteayer puede dejar cada venta por debajo del costo, así que
/// avisar no basta: ofrece las dos salidas reales — escribir la de hoy a mano
/// o aceptar la vieja a sabiendas.
class TarjetaTasaVencida extends ConsumerStatefulWidget {
  const TarjetaTasaVencida({super.key});

  @override
  ConsumerState<TarjetaTasaVencida> createState() => _TarjetaTasaVencidaState();
}

class _TarjetaTasaVencidaState extends ConsumerState<TarjetaTasaVencida> {
  bool _aceptada = false;

  static const _dias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo',
  ];

  Future<void> _escribir() async {
    final ctrl = TextEditingController();
    final valor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escribir la tasa de hoy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se usa para cobrar hasta que llegue la automática. Mañana se '
              'descarta sola.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: 'Bs '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(
              double.tryParse(
                ctrl.text.replaceAll('.', '').replaceAll(',', '.'),
              ),
            ),
            child: const Text('Usar esta'),
          ),
        ],
      ),
    );
    if (valor != null && valor > 0) {
      ref.read(tasaManualProvider.notifier).escribir(valor);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_aceptada) return const SizedBox.shrink();

    final t = context.libreta;
    final dias = ref.watch(diasDesdeTasaProvider) ?? 0;
    final historial = ref.watch(historialTasaProvider);
    final ultima = historial.isEmpty ? null : historial.first;

    return EntradaAnimada(
      retardo: const Duration(milliseconds: 90),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: const Color(0x80F2A93C), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x2EF2A93C),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: LibretaColors.aviso,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'La tasa tiene $dias ${dias == 1 ? "día" : "días"}',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          color: t.textoFuerte,
                        ),
                      ),
                      if (ultima != null)
                        Text(
                          '${MoneyFormatter.bs(ultima.valor)} · del '
                          '${_dias[ultima.fecha.weekday - 1]} '
                          '${ultima.fecha.day}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: LibretaColors.aviso,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Si cobras con esta tasa puedes perder plata. Escríbela a mano '
              'hasta que vuelva el internet.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: t.textoMuted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _escribir,
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: LibretaColors.tarjetaOscura,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Text(
                        'Escribir la tasa',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                GestureDetector(
                  onTap: () => setState(() => _aceptada = true),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: t.bordeSuave, width: 1.5),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      'Usar esa',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: t.textoFuerte,
                      ),
                    ),
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
// Lista de pendientes
// ---------------------------------------------------------------------------

/// Renglones de pendientes bajo un rótulo (`Lote P`). El rótulo cambia según
/// el estado del día: "Pendientes", "También pendiente" o "Mientras esperas".
class ListaPendientes extends ConsumerWidget {
  const ListaPendientes({super.key, required this.titulo, this.excluir});

  final String titulo;

  /// Clave de la urgencia que ya se está mostrando destacada arriba.
  final String? excluir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final items =
        ref.watch(urgenciasProvider).where((u) => u.clave != excluir).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return EntradaAnimada(
      retardo: const Duration(milliseconds: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: t.textoMuted,
                  ),
                ),
              ),
              if (items.length > 3)
                GestureDetector(
                  onTap: () => context.push(Routes.notificaciones),
                  child: const Text(
                    'Ver todo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: LibretaColors.verde,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          for (final u in items.take(3)) _FilaPendiente(urgencia: u),
        ],
      ),
    );
  }
}

class _FilaPendiente extends StatelessWidget {
  const _FilaPendiente({required this.urgencia});

  final Urgencia urgencia;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final grave = urgencia.grave;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.push(urgencia.ruta),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: t.superficie,
            border: Border.all(
              color: grave ? const Color(0x73F2A93C) : t.renglon,
              width: grave ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: grave
                      ? const Color(0x29F2A93C)
                      : t.textoFuerte.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  urgencia.icono,
                  size: 19,
                  color: grave ? LibretaColors.aviso : t.textoFuerte,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      urgencia.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: t.textoFuerte,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      urgencia.detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: grave ? LibretaColors.aviso : t.textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: t.textoMuted),
            ],
          ),
        ),
      ),
    );
  }
}
