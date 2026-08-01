import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../fiados/data/fiado_repository.dart';
import '../../fiados/domain/cliente_fiado.dart';
import '../../gastos/data/gasto_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/domain/venta.dart';
import '../data/cierre_repository.dart';
import '../domain/cierre_caja.dart';

/// Cierre de caja — arqueo (réplica visual de `P0 · CIERRE DE CAJA`,
/// `Lote H · Cierre y Proveedores`).
class ArqueoCajaScreen extends ConsumerStatefulWidget {
  const ArqueoCajaScreen({super.key});

  @override
  ConsumerState<ArqueoCajaScreen> createState() => _ArqueoCajaScreenState();
}

class _ArqueoCajaScreenState extends ConsumerState<ArqueoCajaScreen> {
  final _contado = TextEditingController();
  bool _cerrando = false;

  @override
  void dispose() {
    _contado.dispose();
    super.dispose();
  }

  double? get _contadoValor => double.tryParse(_contado.text.replaceAll(',', '.'));

  bool _esHoy(DateTime f) {
    final ahora = DateTime.now();
    return f.year == ahora.year && f.month == ahora.month && f.day == ahora.day;
  }

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  String _fecha(DateTime f) => '${_dias[f.weekday - 1]} ${f.day} ${_meses[f.month - 1]}';

  String _hora12(DateTime f) {
    final h = f.hour % 12 == 0 ? 12 : f.hour % 12;
    final m = f.minute.toString().padLeft(2, '0');
    return '$h:$m ${f.hour < 12 ? "a. m." : "p. m."}';
  }

  Future<void> _cerrar(
    Map<String, double> metodos,
    double efectivoEsperado,
    double gastosHoy,
    double fiadoHoy,
    double abonosHoy,
    double ventasHoy,
  ) async {
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final contado = _contadoValor;
    if (membresia == null || user == null || contado == null) return;

    setState(() => _cerrando = true);
    final cierre = CierreCaja(
      id: CierreCaja.idDe(DateTime.now()),
      ventasUSD: ventasHoy,
      gastosUSD: gastosHoy,
      fiadoOtorgadoUSD: fiadoHoy,
      abonosUSD: abonosHoy,
      metodosEsperados: metodos,
      efectivoEsperado: efectivoEsperado,
      efectivoContado: contado,
      cerradoPor: user.uid,
      cerradaEn: DateTime.now(),
    );
    try {
      await ref.read(cierreCajaRepositoryProvider).crearCierre(membresia.negocioId, cierre);
      if (!mounted) return;
      context.pushReplacement(Routes.resumenDia.replaceAll(':cierreId', cierre.id), extra: cierre);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cerrando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar la caja: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ventasAsync = ref.watch(ventasDelDiaProvider);
    final gastosAsync = ref.watch(gastosDelMesProvider);
    final fiadosAsync = ref.watch(movimientosFiadoHoyProvider);
    final cierreHoy = ref.watch(cierreDeHoyProvider).valueOrNull;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(tasaActivaValorProvider);

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ventasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (ventas) {
              final gastos = (gastosAsync.valueOrNull ?? const [])
                  .where((g) => _esHoy(g.fecha))
                  .toList();
              final fiados = fiadosAsync.valueOrNull ?? const [];

              // Una venta fiada NO entra en lo esperado por método: esa plata
              // todavía no llegó a la caja. Si se sumara, el dueño contaría el
              // efectivo, le faltaría justo lo que fió y pensaría que se lo
              // robaron. Ya está contada en `fiadoOtorgado`, que sale del libro
              // mayor del cliente.
              final metodos = <String, double>{};
              for (final v in ventas.where((v) => !v.esFiada)) {
                metodos[v.metodoPago.id] = (metodos[v.metodoPago.id] ?? 0) + v.totalUSD;
              }
              final ventasTotal = ventas.fold<double>(0, (s, v) => s + v.totalUSD);
              final gastosTotal = gastos.fold<double>(0, (s, g) => s + g.monto);
              final fiadoOtorgado = fiados
                  .where((m) => m.tipo == TipoMovimientoFiado.fiado)
                  .fold<double>(0, (s, m) => s + m.montoUSD);
              final abonos = fiados
                  .where((m) => m.tipo == TipoMovimientoFiado.abono)
                  .fold<double>(0, (s, m) => s + m.montoUSD);
              final efectivoEsperado = metodos[MetodoPago.efectivo.id] ?? 0;
              final contado = _contadoValor;
              final descuadre = contado == null ? null : contado - efectivoEsperado;
              final activos = negocio?.metodosActivos ?? const [];
              final primeraVenta = ventas.isEmpty
                  ? null
                  : ventas.map((v) => v.fecha).reduce((a, b) => a.isBefore(b) ? a : b);

              if (cierreHoy != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 40, color: LibretaColors.verde),
                        const SizedBox(height: 14),
                        Text(
                          'Ya cerraste la caja de hoy',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte),
                        ),
                        const SizedBox(height: 18),
                        LibretaButton(
                          label: 'Ver resumen del día',
                          onPressed: () => context.pushReplacement(Routes.resumenDia.replaceAll(':cierreId', cierreHoy.id), extra: cierreHoy),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(24, 30, 22, 100),
                    children: [
                      Text(
                        'Cierre de caja',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.libreta.textoFuerte,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        primeraVenta == null
                            ? _fecha(DateTime.now())
                            : '${_fecha(DateTime.now())} · abierta desde ${_hora12(primeraVenta)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'ESPERADO SEGÚN EL SISTEMA',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.libreta.textoMuted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: context.libreta.superficie,
                          border: Border.all(color: const Color(0x141E2A38)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final c in activos)
                              _FilaMetodo(
                                etiqueta: _sinEmoji(c.metodo.etiqueta),
                                monto: metodos[c.metodo.id] ?? 0,
                                ultima: c == activos.last,
                              ),
                            if (activos.isEmpty)
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Configura tus métodos de pago para ver el arqueo.', style: TextStyle(color: context.libreta.textoMuted)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'ARQUEO DE EFECTIVO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: context.libreta.textoMuted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.libreta.superficie,
                          border: Border.all(color: const Color(0x141E2A38)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '¿Cuánto efectivo contaste?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.libreta.textoMuted),
                            ),
                            const SizedBox(height: 8),
                            LibretaInput(
                              controller: _contado,
                              hint: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (contado != null && tasa != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                MoneyFormatter.usdComoBs(contado, tasa),
                                style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                              ),
                            ],
                            if (descuadre != null) ...[
                              const SizedBox(height: 12),
                              Container(height: 1, color: context.libreta.renglon),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Esperado ${MoneyFormatter.usd(efectivoEsperado)} · '
                                      'contado ${MoneyFormatter.usd(contado!)}',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.libreta.textoMuted),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: descuadre == 0 ? const Color(0x1F0E9F6E) : const Color(0x26F2A93C),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      descuadre == 0
                                          ? 'cuadrado'
                                          : descuadre > 0
                                              ? 'sobran ${MoneyFormatter.usd(descuadre)}'
                                              : 'falta ${MoneyFormatter.usd(-descuadre)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: descuadre == 0 ? LibretaColors.verde : LibretaColors.aviso,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 54,
                    right: 22,
                    bottom: 16,
                    child: LibretaButton(
                      label: 'Cerrar caja del día',
                      loading: _cerrando,
                      icon: const LibretaIcono(AppAssets.navProductos, size: 19, color: Colors.white),
                      onPressed: contado == null || _cerrando
                          ? null
                          : () => _cerrar(metodos, efectivoEsperado, gastosTotal, fiadoOtorgado, abonos, ventasTotal),
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

String _sinEmoji(String etiqueta) => etiqueta.replaceFirst(RegExp(r'^\S+\s'), '');

class _FilaMetodo extends StatelessWidget {
  const _FilaMetodo({required this.etiqueta, required this.monto, required this.ultima});

  final String etiqueta;
  final double monto;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: ultima ? null : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte)),
          Text(
            MoneyFormatter.usd(monto),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.libreta.textoFuerte),
          ),
        ],
      ),
    );
  }
}
