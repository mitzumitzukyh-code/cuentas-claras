import 'package:intl/intl.dart';

/// Estrategia de redondeo del monto en bolívares (CLAUDE.md §6).
enum RedondeoBs {
  /// Sin redondeo, dos decimales.
  ninguno,

  /// Al bolívar entero más cercano.
  bolivarCercano,

  /// Al múltiplo de 5 más cercano.
  multiplo5,
}

/// Formateo de moneda para Cuenta Clara.
///
/// Los precios se capturan en USD; el monto en Bs se calcula con la tasa BCV
/// cacheada (CLAUDE.md §6). Usa números tabulares vía [AppTypography.money] al
/// pintarlos.
abstract final class MoneyFormatter {
  const MoneyFormatter._();

  static final NumberFormat _usd = NumberFormat('#,##0.00', 'es');

  static final NumberFormat _bsConDecimales = NumberFormat('#,##0.00', 'es');
  static final NumberFormat _bsEntero = NumberFormat('#,##0', 'es');

  /// Ej: `$1.284.590,50` — formato es-VE (punto = miles, coma = decimal),
  /// igual que [bs]. Antes usaba separadores de EE. UU.; lo expuso la
  /// pantalla de "datos feos" del Lote L (montos grandes con formato mixto).
  static String usd(double valor) => '\$${_usd.format(valor)}';

  /// Convierte USD → Bs aplicando la tasa y el redondeo indicado.
  static double convertirABs(
    double usd,
    double tasa, {
    RedondeoBs redondeo = RedondeoBs.ninguno,
  }) {
    final bruto = usd * tasa;
    switch (redondeo) {
      case RedondeoBs.ninguno:
        return bruto;
      case RedondeoBs.bolivarCercano:
        return bruto.roundToDouble();
      case RedondeoBs.multiplo5:
        return (bruto / 5).round() * 5.0;
    }
  }

  /// Ej: `Bs 1.250,00` — o sin decimales si el redondeo los elimina.
  static String bs(double valorBs, {RedondeoBs redondeo = RedondeoBs.ninguno}) {
    final f = redondeo == RedondeoBs.ninguno ? _bsConDecimales : _bsEntero;
    return 'Bs ${f.format(valorBs)}';
  }

  /// Atajo: formatea directamente un monto USD como Bs con la tasa dada.
  static String usdComoBs(
    double usd,
    double tasa, {
    RedondeoBs redondeo = RedondeoBs.ninguno,
  }) {
    return bs(convertirABs(usd, tasa, redondeo: redondeo), redondeo: redondeo);
  }
}
