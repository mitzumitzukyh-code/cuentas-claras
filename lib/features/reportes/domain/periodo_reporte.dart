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

  /// Momento en que arranca el periodo anterior equivalente — para el
  /// comparativo "▲ 12% vs junio" del Lote N.
  DateTime get desdeAnterior {
    final ahora = DateTime.now();
    return switch (this) {
      PeriodoReporte.hoy =>
        DateTime(ahora.year, ahora.month, ahora.day - 1),
      PeriodoReporte.semana => desde.subtract(const Duration(days: 7)),
      PeriodoReporte.mes => DateTime(
          ahora.month == 1 ? ahora.year - 1 : ahora.year,
          ahora.month == 1 ? 12 : ahora.month - 1,
        ),
      PeriodoReporte.ano => DateTime(ahora.year - 1),
    };
  }

  /// Nombre corto del periodo anterior, para el rótulo del comparativo.
  String get etiquetaAnterior {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
      'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final ahora = DateTime.now();
    return switch (this) {
      PeriodoReporte.hoy => 'ayer',
      PeriodoReporte.semana => 'la semana pasada',
      PeriodoReporte.mes => meses[(ahora.month == 1 ? 12 : ahora.month - 1) - 1],
      PeriodoReporte.ano => '${ahora.year - 1}',
    };
  }
}
