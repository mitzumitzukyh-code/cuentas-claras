import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../negocio/data/negocio_repository.dart';
import '../../ventas/data/venta_repository.dart';
import '../../ventas/domain/venta.dart';
import '../domain/periodo_reporte.dart';

/// Ventas del periodo pedido, consultadas al servidor por rango de fechas.
///
/// Antes los reportes se calculaban sobre `historialVentasProvider`, que trae
/// las últimas 200 ventas: en un negocio con movimiento, "Mes" y "Año"
/// mostraban cifras truncadas sin avisar. Pedir el rango completo a Firestore
/// es la única forma de que el total sea el total.
///
/// El rango arranca en lo más antiguo entre el periodo elegido y hace 7 días,
/// porque el gráfico "Ventas por día" siempre pinta la última semana aunque el
/// periodo sea "Hoy". Así un solo listener alimenta KPIs y gráfico.
final ventasReporteProvider =
    StreamProvider.family<List<Venta>, PeriodoReporte>((ref, periodo) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);

  final hoy = DateTime.now();
  final hace7dias = DateTime(hoy.year, hoy.month, hoy.day)
      .subtract(const Duration(days: 6));
  final desde =
      periodo.desde.isBefore(hace7dias) ? periodo.desde : hace7dias;

  return ref
      .watch(ventaRepositoryProvider)
      .ventasDesde(membresia.negocioId, desde);
});

/// Ventas desde el inicio del periodo ANTERIOR hasta hoy — de aquí se sacan
/// tanto el total actual como el del periodo pasado, para el comparativo
/// "▲ 12% vs junio" (`Lote N · Reportes y Más`). Un solo listener cubre
/// ambos periodos: Firestore no permite acotar un rango por el extremo
/// superior sin un segundo índice, así que se filtra el borde en el cliente.
final ventasComparativoProvider =
    StreamProvider.family<List<Venta>, PeriodoReporte>((ref, periodo) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);

  return ref
      .watch(ventaRepositoryProvider)
      .ventasDesde(membresia.negocioId, periodo.desdeAnterior);
});
