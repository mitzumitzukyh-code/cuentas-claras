import 'venta.dart';

/// Periodo del filtro de ventas (réplica de `P1 · FILTROS`, `Lote L ·
/// Búsqueda y Datos`). Distinto de `PeriodoReporte`: agrega "personalizado"
/// y no incluye "año", que no está en este mockup.
enum PeriodoFiltroVenta {
  hoy,
  semana,
  mes,
  personalizado;

  String get etiqueta => switch (this) {
        PeriodoFiltroVenta.hoy => 'Hoy',
        PeriodoFiltroVenta.semana => 'Semana',
        PeriodoFiltroVenta.mes => 'Mes',
        PeriodoFiltroVenta.personalizado => 'Personalizado',
      };
}

/// Estado de la venta a filtrar.
enum EstadoFiltroVenta {
  todas,
  completadas,
  anuladas;

  String get etiqueta => switch (this) {
        EstadoFiltroVenta.todas => 'Todas',
        EstadoFiltroVenta.completadas => 'Completadas',
        EstadoFiltroVenta.anuladas => 'Anuladas',
      };
}

/// Selección de filtros para el Historial de ventas.
///
/// `null` en [metodo] significa "todos los métodos". El rango
/// [personalizadoDesde]/[personalizadoHasta] solo aplica cuando
/// [periodo] es [PeriodoFiltroVenta.personalizado].
class FiltroVentas {
  const FiltroVentas({
    this.periodo = PeriodoFiltroVenta.hoy,
    this.personalizadoDesde,
    this.personalizadoHasta,
    this.metodo,
    this.estado = EstadoFiltroVenta.todas,
  });

  final PeriodoFiltroVenta periodo;
  final DateTime? personalizadoDesde;
  final DateTime? personalizadoHasta;
  final MetodoPago? metodo;
  final EstadoFiltroVenta estado;

  /// `true` si no restringe nada (equivalente a ver todo el historial).
  bool get esNeutro =>
      metodo == null &&
      estado == EstadoFiltroVenta.todas &&
      periodo == PeriodoFiltroVenta.personalizado &&
      personalizadoDesde == null &&
      personalizadoHasta == null;

  /// Desde cuándo cuentan las ventas — `null` si personalizado sin fecha.
  DateTime? get desde {
    final ahora = DateTime.now();
    return switch (periodo) {
      PeriodoFiltroVenta.hoy => DateTime(ahora.year, ahora.month, ahora.day),
      PeriodoFiltroVenta.semana => DateTime(ahora.year, ahora.month, ahora.day)
          .subtract(Duration(days: ahora.weekday - 1)),
      PeriodoFiltroVenta.mes => DateTime(ahora.year, ahora.month),
      PeriodoFiltroVenta.personalizado => personalizadoDesde,
    };
  }

  /// Hasta cuándo cuentan (exclusivo) — `null` si no aplica.
  DateTime? get hasta {
    if (periodo != PeriodoFiltroVenta.personalizado) return null;
    final h = personalizadoHasta;
    if (h == null) return null;
    return DateTime(h.year, h.month, h.day).add(const Duration(days: 1));
  }

  bool aplicaA(Venta v) {
    final desdeF = desde;
    final hastaF = hasta;
    if (desdeF != null && v.fecha.isBefore(desdeF)) return false;
    if (hastaF != null && !v.fecha.isBefore(hastaF)) return false;
    if (metodo != null && v.metodoPago != metodo) return false;
    switch (estado) {
      case EstadoFiltroVenta.todas:
        break;
      case EstadoFiltroVenta.completadas:
        if (v.anulada) return false;
      case EstadoFiltroVenta.anuladas:
        if (!v.anulada) return false;
    }
    return true;
  }

  FiltroVentas copyWith({
    PeriodoFiltroVenta? periodo,
    DateTime? personalizadoDesde,
    DateTime? personalizadoHasta,
    MetodoPago? metodo,
    bool sinMetodo = false,
    EstadoFiltroVenta? estado,
  }) {
    return FiltroVentas(
      periodo: periodo ?? this.periodo,
      personalizadoDesde: personalizadoDesde ?? this.personalizadoDesde,
      personalizadoHasta: personalizadoHasta ?? this.personalizadoHasta,
      metodo: sinMetodo ? null : (metodo ?? this.metodo),
      estado: estado ?? this.estado,
    );
  }
}
