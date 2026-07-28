import '../../../core/utils/money_formatter.dart';

/// En qué moneda maneja sus precios el negocio (paso 2 del onboarding,
/// `Lote F · P0 · RUBRO`).
///
/// Se guarda en `negocios/{id}.moneda`. El valor por defecto es [usd], que es
/// exactamente el comportamiento que la app tuvo siempre: el precio grande en
/// dólares y el de bolívares debajo como referencia. Por eso los negocios ya
/// creados no cambian de aspecto al aparecer este ajuste.
enum ModoPrecio {
  /// Precios base en $, el monto en Bs se calcula con la tasa BCV.
  usd,

  /// Precios base en Bs, el de $ queda como referencia.
  ves,

  /// Los dos con el mismo peso visual, sin uno "principal".
  ambas;

  /// ID persistido en Firestore. `VES` es el código ISO del bolívar, y es el
  /// que ya usaba [Negocio.monedaSecundaria].
  String get id => switch (this) {
        ModoPrecio.usd => 'USD',
        ModoPrecio.ves => 'VES',
        ModoPrecio.ambas => 'AMBAS',
      };

  /// Tolera el `'Bs'` que escribía el onboarding viejo y cualquier valor
  /// desconocido, que cae en [usd] para no dejar al negocio sin precios.
  static ModoPrecio fromId(String? id) => switch (id) {
        'VES' || 'Bs' || 'BS' => ModoPrecio.ves,
        'AMBAS' => ModoPrecio.ambas,
        _ => ModoPrecio.usd,
      };

  String get etiqueta => switch (this) {
        ModoPrecio.usd => 'Dólares (USD)',
        ModoPrecio.ves => 'Bolívares (Bs)',
        ModoPrecio.ambas => 'Ambas (\$ y Bs)',
      };

  String get detalle => switch (this) {
        ModoPrecio.usd => 'Precios base en \$, conversión automática',
        ModoPrecio.ves => 'Precios base en Bs, referencia en \$',
        ModoPrecio.ambas => 'Los dos precios con el mismo peso, siempre a la '
            'vista',
      };

  /// Resumen corto para el paso 3 y la pantalla de ajustes.
  String get etiquetaCorta => switch (this) {
        ModoPrecio.usd => 'Dólares',
        ModoPrecio.ves => 'Bolívares',
        ModoPrecio.ambas => 'Ambas',
      };

  /// Si el monto grande va en bolívares en vez de en dólares.
  bool get principalEnBs => this == ModoPrecio.ves;

  /// Si los dos montos se pintan igual de grandes, sin jerarquía.
  bool get sinJerarquia => this == ModoPrecio.ambas;

  /// Los dos montos ya formateados y en el orden que toca: el primero es el
  /// que va grande, el segundo el de referencia. Con [ModoPrecio.ambas] los
  /// dos van juntos en el primero y el segundo queda vacío, para que la
  /// pantalla los pinte del mismo tamaño sin tener que saber del modo.
  ///
  /// Sin [tasa] no hay conversión posible y solo se devuelven los dólares.
  (String, String?) montos(double usd, double? tasa) {
    final enBs = tasa == null ? null : MoneyFormatter.usdComoBs(usd, tasa);
    final enUsd = MoneyFormatter.usd(usd);
    if (enBs == null) return (enUsd, null);
    return switch (this) {
      ModoPrecio.usd => (enUsd, enBs),
      ModoPrecio.ves => (enBs, enUsd),
      ModoPrecio.ambas => ('$enUsd · $enBs', null),
    };
  }
}
