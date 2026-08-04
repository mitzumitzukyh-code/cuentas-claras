/// Fuerza [Plan.premium] en una compilación marcada para pruebas.
///
/// ```
/// flutter build apk --release --dart-define=PREMIUM_FORZADO=true
/// ```
///
/// **No es un ajuste ni un interruptor de la app: es de tiempo de
/// compilación.** Un APK compilado sin esa bandera no contiene el camino —
/// `bool.fromEnvironment` se resuelve al compilar y el `if` desaparece del
/// binario—, así que no hay nada que activar desde el teléfono ni que
/// descubrir hurgando. El de Play Store nunca lo llevará.
///
/// Existe porque los topes del plan gratis bloquean cosas que hay que poder
/// probar —invitar empleados, abrir una segunda sucursal, el catálogo sin
/// marca de agua— y la alternativa era escribir a mano en Firestore.
///
/// Cuando está puesto, la app lo dice en la pantalla de planes. Un override
/// que no se ve es un override que se olvida.
const bool premiumForzado = bool.fromEnvironment('PREMIUM_FORZADO');

/// El plan de un usuario y lo que le deja hacer (CLAUDE.md §6).
///
/// **El plan es de la persona, no del negocio.** Quien paga es un usuario, y
/// sus negocios heredan lo que él tenga: los empleados de un negocio Premium
/// disfrutan las ventajas sin pagar aparte. Es lo único coherente con el
/// límite de «1 negocio» del plan gratis — un tope sobre negocios solo tiene
/// sentido si lo lleva la persona.
///
/// Los topes viven aquí y en ningún otro sitio. Cuando el precio o los límites
/// cambien, se cambian en este archivo y la app entera se entera.
enum Plan {
  gratis,
  premium;

  /// `null` = sin tope.
  int? get maxNegocios => switch (this) {
        Plan.gratis => 1,
        Plan.premium => null,
      };

  /// `null` = sin tope.
  int? get maxProductos => switch (this) {
        Plan.gratis => 50,
        Plan.premium => null,
      };

  /// Cuántas personas pueden entrar al negocio, contando al dueño. En gratis
  /// es solo él: no se pueden invitar empleados.
  int? get maxUsuarios => switch (this) {
        Plan.gratis => 1,
        Plan.premium => null,
      };

  /// Cuántos días atrás se pueden consultar las ventas. `null` = sin tope.
  ///
  /// **Declarado pero no aplicado a propósito.** A diferencia de los otros
  /// topes, este no impide crear algo nuevo: escondería ventas que el dueño ya
  /// tiene registradas. Se decidió no bloquear nunca lo que ya existe, y
  /// ocultarle a alguien su propio trabajo de hace dos meses es justo eso.
  /// Queda aquí porque es parte del plan y porque el día que se aplique —con
  /// un aviso, no en silencio— este es el sitio.
  int? get diasHistorial => switch (this) {
        Plan.gratis => 30,
        Plan.premium => null,
      };

  /// Si el catálogo y el Estado salen con «Hecho con Cuenta Clara».
  bool get marcaDeAgua => this == Plan.gratis;

  bool get esPremium => this == Plan.premium;

  String get etiqueta => switch (this) {
        Plan.gratis => 'Plan gratis',
        Plan.premium => 'Plan Plus',
      };

  /// Id persistido en Firestore. Un valor desconocido cae en [gratis]: si no
  /// consta que alguien pagó, no pagó.
  String get id => name;

  static Plan fromId(String? id) =>
      id == Plan.premium.name ? Plan.premium : Plan.gratis;
}

/// Qué se puede crear todavía, dado un plan y lo que ya hay.
///
/// Los topes se miran **al crear**, nunca sobre lo que ya está guardado: un
/// negocio que cargó 60 productos cuando no había límite los conserva todos,
/// visibles y vendibles, y lo único que no puede es añadir el 61. Esconder o
/// bloquear trabajo ya hecho por un cambio de política de precios no es una
/// opción.
class LimitePlan {
  /// Se puede seguir.
  const LimitePlan.ok() : permitido = true, mensaje = null;

  /// Se llegó al tope. [mensaje] explica qué pasa y qué hacer.
  const LimitePlan.alcanzado(String this.mensaje) : permitido = false;

  final bool permitido;

  /// Frase para el usuario. `null` cuando [permitido] es `true`.
  final String? mensaje;

  /// ¿Cabe uno más? [actuales] es cuántos hay ya; [tope] el máximo, o `null`
  /// si no hay.
  static LimitePlan cabeUnoMas({
    required int actuales,
    required int? tope,
    required String mensaje,
  }) {
    if (tope == null || actuales < tope) return const LimitePlan.ok();
    return LimitePlan.alcanzado(mensaje);
  }
}
