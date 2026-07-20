/// Periodo del reporte.
enum PeriodoReporte {
  hoy,
  semana,
  mes,
  ano;

  String get etiqueta => switch (this) {
        PeriodoReporte.hoy => 'Hoy',
        PeriodoReporte.semana => 'Semana',
        PeriodoReporte.mes => 'Mes',
        PeriodoReporte.ano => 'Año',
      };

  /// Momento a partir del cual cuentan las ventas.
  DateTime get desde {
    final ahora = DateTime.now();
    return switch (this) {
      PeriodoReporte.hoy => DateTime(ahora.year, ahora.month, ahora.day),
      PeriodoReporte.semana => DateTime(ahora.year, ahora.month, ahora.day)
          .subtract(Duration(days: ahora.weekday - 1)),
      PeriodoReporte.mes => DateTime(ahora.year, ahora.month),
      PeriodoReporte.ano => DateTime(ahora.year),
    };
  }
}
