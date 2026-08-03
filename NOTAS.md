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

## Pendientes

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
