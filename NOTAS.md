# Notas al margen — sistema de perfiles de negocio

Cosas que aparecieron mientras se construía la capa de perfiles y que quedaron
fuera de alcance a propósito.

## Resueltas

- ~~`rubro` y `perfilNegocio` se solapan~~ — ya no hay dos ejes: el perfil
  cuelga 1:1 del rubro y el campo `perfilNegocio` se eliminó del modelo.
- ~~El mapeo 7 rubros → 5 perfiles pierde funciones~~ — ya no hay mapeo. Cada
  rubro tiene su preset propio (ocho, con panadería).
- ~~`extraFields` y las banderas dicen lo mismo dos veces~~ — `usaFechaVencimiento`
  se eliminó y el vencimiento es un `ExtraField`. Las banderas que quedan
  encienden bloques enteros del formulario, no campos sueltos.

## BLOQUEANTE DE LANZAMIENTO

- **La sesión no sobrevive al reinicio en release, y el parche que lo tapa
  necesita internet.** En release, sobre el Z2464N, `FirebaseAuth.currentUser`
  amanecía en `null` tras cerrar y reabrir (sondeado a 3,5 s, 9,5 s y 14 s: no
  es una carrera, es que no restaura). El parche vigente es
  `AuthRepository.restaurarSesion`, que guarda **cómo** se entró y vuelve a
  autenticar al arrancar.

  Dos costos que lo hacen bloqueante, no una nota al pie:
  1. **Requiere red.** La persistencia nativa de Firebase no. Un dueño que abre
     la app sin señal cae al login y lee "perdí mis datos" — el escenario que
     hace desinstalar. Ya no es un problema de un ROM: es de cualquiera con
     mala cobertura.
  2. **Guarda la contraseña** (cifrada, `flutter_secure_storage`) para poder
     re-autenticar. Firebase guarda un *refresh token*, que es revocable y
     acotado. Es una postura más débil.

  **Lo que falta comprobar, y por qué nadie lo comprobó:** el SHA-1 de release
  se registró en Firebase y el parche entraron en el **mismo commit**
  (`d1deb31`, 2026-07-22). Nunca se probó release *con* el SHA-1 registrado y
  *sin* el parche, así que no se sabe si la causa original ya está resuelta —
  el parche la tapa en silencio. Sospecha principal: el token se refresca
  contra el servidor al restaurar, y si esa llamada se rechaza porque el
  certificado de firma no se reconoce (SHA-1 ausente, o la API key de Android
  restringida en Google Cloud al SHA-1 de debug), el SDK **descarta la sesión
  guardada** — lo que explica exactamente "en debug sí, en release no".

  Cómo confirmarlo (necesita dispositivo, no código): desactivar
  `restaurarSesionProvider` en un build de release, entrar, forzar cierre,
  reabrir y mirar `currentUser`; revisar las restricciones de la API key de
  Android en Google Cloud → Credenciales; y `adb logcat | grep -i FirebaseAuth`
  en un arranque en frío. Descartado de entrada: el fabricante matando el
  proceso — un proceso muerto vuelve a leer la sesión del disco al reabrir.

## Pendientes

- **El Worker sigue mandando un push por negocio.** La regla nueva
  (`resumenesAEnviar`) solo evita la contradicción "vendiste / no vendiste" en
  el mismo teléfono. Un dueño con tres negocios que vendieron sigue recibiendo
  tres avisos seguidos, y ninguno dice de cuál negocio habla. El arreglo de
  fondo es nombrar el negocio en el texto, o mandar un resumen consolidado por
  teléfono. Hace falta decidir cuál antes de que alguien tenga cinco sucursales.

- **`RangoFechasVE` — endurecimiento pendiente, no un fix.** La app calcula los
  rangos de fecha con la zona **del dispositivo** (`DateTime(y, m, d)` y luego
  `Timestamp.fromDate`, que convierte bien); el Worker los calcula con una zona
  **fija** UTC−4 (`hoyEnVenezuela` / `inicioDiaVenezuela`, `worker/src/index.js`).
  Coinciden mientras el teléfono esté en hora de Venezuela y divergen en cuanto
  no lo esté — un viaje, una zona mal configurada, un emulador en UTC. No hay
  mezcla de local y UTC dentro de Dart: no existe un solo `.toUtc()` en `lib/`.
  Los sitios que de verdad calculan un rango son seis:
  - `VentaRepository.ventasDelDia`, `.ventasDeAyer`, `.contarRacha`
  - `gastosDelMesProvider` (`gasto_repository.dart`)
  - `movimientosFiadoHoyProvider` (`fiado_repository.dart`)
  - `PeriodoReporte.desde` / `.desdeAnterior` (`periodo_reporte.dart`)
  - `reportes_providers.dart:23`
  - `historial_tasa_provider.dart` (3 usos)

  El resto de los ~40 `DateTime.now()` fuera de `presentation` son sellos de
  escritura (`fecha: DateTime.now()`) o *fallbacks* de `fromDoc`, que un helper
  de rangos no toca.

- **Los negocios de servicio no están modelados.** Una barbería, un taller
  mecánico o un salón de belleza que cobra por trabajo —no por mercancía— hoy
  entra por el rubro `otro`, que es un cajón de sastre con `hora` entre sus
  unidades y el atajo `cotizar`. Les falta lo propio: no descontar stock, un
  catálogo de servicios en vez de inventario, y una agenda. La bandera
  `tracksStock` existía para esto y **se borró** por no tener ningún rubro que
  la leyera; cuando se agregue el rubro `servicios` habrá que reponerla (o
  resolverlo de otra forma) junto con el atajo `agenda`, que también se borró.

- **`tallas` sigue apagado** (`enabled: false`): falta un cuadro de existencias
  por talla. Por eso `GridAtajos` puede dibujar menos atajos de los que el
  preset declara, y con `cobrar` excluido hay perfiles que muestran uno solo.

- **`negocios/{id}.configuracion` es un espejo de solo escritura.** Ya no lo
  lee ni la app ni el Worker. Se sigue escribiendo para no romper documentos
  existentes; el día que se limpie, sale de `Negocio.toMap()` y de
  `RubroConfig.toMap()`.

- **`negocios/{id}.perfilNegocio` quedó escrito** en los documentos donde se
  haya guardado algo con una versión intermedia (probablemente ninguno fuera de
  desarrollo). Nadie lo lee.

- **La unidad solo se muestra en la lista de mercancía.** `cantidadCon` está
  cableado ahí; el catálogo, las urgencias del Inicio, el aviso de stock al
  cobrar y el mensaje de reabastecimiento siguen usando `cantidadLabel` a
  secas. Son cinco sitios que quieren el perfil a mano.

- **El plural de la unidad es aproximado.** `Producto._plural` solo agrega "s"
  a las que terminan en vocal, así que "par" y "ración" se quedan en singular
  ("quedan 3 par"). Se arregla con un pluralizador de verdad o con un plural
  explícito por unidad en el preset.

- **Los `extraFields` que duplicaban otro bloque se quitaron de los presets.**
  Al cablear la sección, `talla`/`color` en ropa y `tono` en belleza habrían
  salido dos veces: una como campo plano y otra como dimensión del editor de
  variantes —que es el único que lleva stock por combinación—; igual la
  `garantia` de electrónica, que ya tiene su columna bajo el bloque de serial.
  Hoy solo panadería y belleza declaran un campo extra (`vencimiento`). Con eso
  se fue también `tallasPorDefecto`: vuelve si algún día un rubro captura la
  talla como dato plano, o cuando exista el cuadro de existencias por talla.

- **El `select` de `ExtraFieldsSection` no lo usa ningún preset todavía.** El
  tipo y su `allowsCustom` están implementados y sin consumidor. Es el primer
  candidato a romperse sin que nadie se entere.

- **`ExtraFieldsSection` no valida `required`.** Ningún preset lo usa todavía
  (todos los campos extra son opcionales), así que el guardado no lo comprueba.
  El día que un rubro declare un campo obligatorio hay que cablearlo en
  `_puedeGuardar`.
