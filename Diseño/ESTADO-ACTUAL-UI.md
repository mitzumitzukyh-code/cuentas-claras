# Cuenta Clara — Estado real de la UI implementada

> Pásale este documento a Claude Design **antes** de que rehaga o extienda
> cualquier Lote. Describe lo que la app construida hace hoy, no lo que
> proponían los prototipos originales. Donde el prototipo y el código no
> coinciden, **manda el código**: es lo que el usuario ya tiene instalado.

---

## 0. Qué te estoy pidiendo

La app en Flutter ya está construida y en uso. Los Lotes A–Q de los
prototipos HTML se hicieron antes y en varios puntos se desviaron de lo que
finalmente se implementó. Quiero que **rehagas los Lotes tomando como fuente
de verdad el sistema descrito aquí**, para no terminar con dos UI/UX
distintas conviviendo.

Cuando propongas algo nuevo, respeta estos tokens, estas animaciones y estos
patrones de navegación. Si crees que algo de aquí es un error de diseño,
dilo explícitamente en vez de cambiarlo por tu cuenta.

---

## 1. El sistema se llama "libreta"

Todo el chrome imita un **cuaderno de espiral venezolano**. Es la metáfora
central y no es decorativa: el usuario objetivo (bodegas, quincallerías y
puestos de comida en Venezuela) lleva las cuentas en un cuaderno de papel, y
la app se presenta como el mismo cuaderno.

### Reglas del chrome — recién cambiadas, importante

- **Banda de huecos del resorte:** franja horizontal de círculos en el borde
  superior de cada pantalla interna. Alto 18 px, a 8 px por debajo del área
  segura (debajo de la barra de estado / notch, nunca detrás). Color:
  `textoFuerte` al 30 % de opacidad. **Es el único elemento de "cuaderno" que
  queda, y cae en la misma posición en todas las pantallas.**
- **La raya coral vertical se ELIMINÓ.** Antes había una línea vertical
  `#C1503A` al 40 % a 38 px del borde izquierdo, imitando el margen de una
  hoja. Se quitó de toda la app: quedaba a distinta altura según lo que cada
  pantalla reservara arriba y ensuciaba la lectura. **No la reintroduzcas en
  ningún Lote.**
- El contenido de las pantallas internas mantiene un sangrado izquierdo de
  **54 px** (era para esquivar la raya; se conserva como sangrado del
  sistema).
- Sí sigue existiendo una raya coral **dentro de la ilustración** del estado
  vacío (el dibujito de una hoja de cuaderno) y **dentro de las imágenes que
  se exportan a WhatsApp**. Ahí es parte del dibujo, no del chrome.

---

## 2. Tokens de color (`LibretaColors`)

| Token | Hex | Uso |
|---|---|---|
| `verde` | `#0E9F6E` | Marca, acciones primarias, positivo |
| `textoFuerte` | `#1E2A38` | Títulos, texto principal |
| `textoMuted` | `#8A9A96` | Texto secundario |
| `papel` | `#FAF8F3` | Fondo general (nunca blanco puro) |
| `superficie` | `#FFFFFF` | Tarjetas |
| `tarjetaOscura` | `#1E2A38` | Tarjetas "hero" de totales |
| `bordeSuave` | `rgba(30,42,56,.15)` | Bordes |
| `renglon` | `rgba(30,42,56,.12)` | Separadores |
| `peligro` | `#C74A3A` | Eliminar, vaciar |
| `aviso` | `#B07D1E` | Stock bajo, vencimientos |
| `tagline` | `#F7E7C6` | Frases manuscritas sobre fondo oscuro |
| `margenCoral` | `rgba(193,80,58,.40)` | **Solo** dentro de ilustraciones |

**Degradado de marca** (`#8C2F22 → #5A3A28 → #0E9F6E`, vinotinto a verde):
exclusivo de splash, login/registro y tutorial. **Nunca en pantallas
internas** — ahí siempre fondo papel.

**Modo oscuro** implementado (Lote J): el papel oscuro es `#1C1B18`, cálido,
**nunca negro puro**. `tarjetaOscura` NO se invierte en oscuro.

### Tipografía

- **Plus Jakarta Sans** empaquetada como asset (no se baja en runtime).
  Pesos 400–800. Números tabulares para montos.
- **Caveat** (vía `google_fonts`) solo para *taglines* manuscritos —
  frases cortas y emocionales bajo los títulos. Se usa en 14 sitios.
  Ejemplos reales: *"tus cuentas, claras como el agua"*, *"cuentas claras,
  amistades largas"*, *"deuda cero, mente tranquila"*, *"lo que no se
  muestra, no se vende"*, *"casi listo"*, *"tus cuentas te esperan"*.

Ese registro —cercano, en tuteo, venezolano, nunca corporativo— es parte
del diseño. Mantenlo.

---

## 3. Animaciones emocionales (todas implementadas)

1. **Splash de arranque** (`SplashScreen`, ~3,5 s garantizados). Sobre el
   degradado de marca: la tapa del cuaderno se abre en perspectiva
   (`rotateY`, 1,6 s), el check verde se dibuja trazo a trazo, el título y
   el tagline entran escalonados con un subrayado ondulado que se dibuja
   solo, y un resplandor cálido late detrás. **Sin fundido de salida por
   temporizador** (lo tenía y causaba pantallas en negro: la salida la anima
   la transición de página).
2. **"Configurando tu cuenta…"** (`ConfigurandoScreen`, mínimo 2,6 s).
   Cuaderno que respira (escala ±3 %) mientras se crea el negocio.
3. **Transición de página global** (`_PageFlip`, 450 ms entrada / 300 ms
   salida): cada pantalla se levanta desde abajo rotando en el eje X
   (perspectiva 0.002, hasta 60°), como pasar la hoja de un cuaderno con el
   resorte arriba. Con sombra de pliegue en el borde inferior.
4. **Estado vacío** (`LibretaEstadoVacio`): hoja de cuaderno dibujada a mano
   (espiral, renglones, palomita a lápiz) que entra con rebote elástico
   desde abajo (800 ms) y luego flota suavemente en bucle (4,4 s). Título,
   detalle, tagline y botón aparecen escalonados a 500/700/900/1100 ms.
   Variante `busqueda: true` que cambia el garabato por una lupa tachada.
5. **`EntradaAnimada`**: fade + desplazamiento de 14 px hacia arriba, 460 ms,
   `easeOutCubic`, con retardo configurable. Se usa para escalonar la
   entrada de listas y tarjetas.

**Todas respetan `MediaQuery.disableAnimations`.**

> Nota técnica: en el dispositivo de prueba el ajuste
> `animator_duration_scale` viene nulo y eso hace que `disableAnimations`
> devuelva `true`, saltándose los bucles. No es un bug del diseño.

---

## 4. Inventario de pantallas (45 archivos `*_screen.dart`)

**Auth y arranque (8):** splash · login · registro · recuperar contraseña ·
error de sesión · error de conexión · error de config de Firebase ·
configurando cuenta.

**Onboarding (3):** selección de rubro (3 pasos: negocio+rubro → moneda →
resumen) · tutorial (4 láminas) · unirse con código.

**Núcleo (5):** dashboard · cobrar · productos · nuevo producto · reportes.

**Ventas (5):** historial · detalle de venta · ventas pendientes · filtro de
ventas · exportar reporte.

**Gastos (2):** lista · registrar.

**Fiados —Lote G— (3):** lista · detalle de cliente · anotar movimiento.

**Proveedores y cierre —Lote H— (5):** cuentas por pagar · detalle ·
anotar movimiento · arqueo de caja · resumen del día.

**Catálogo (2):** catálogo · publicar en Estado de WhatsApp.

**Perfil y negocio (9):** perfil · ajustes · mi perfil · empleados · métodos
de pago · impresora · centro de ayuda · eliminar cuenta · planes.

**Otros (3):** notificaciones · importar inventario · migrar de otra app.

### Navegación

- **`go_router`**, 5 pestañas en la barra inferior: Inicio · Cobrar ·
  Productos · Reportes · Perfil. Las pestañas usan `go` (reemplazan), el
  resto usa `push` (apila).
- **Botón de retroceso propio** (`LibretaBackButton`): cuadrado 40×40,
  esquinas 12, icono `arrow_back_ios_new` de 18 px. Variante `oscuro: true`
  sobre papel, clara sobre degradado. **No se usa `AppBar` en ninguna
  pantalla** — cada una arma su cabecera. Toda pantalla apilada lleva este
  botón; las 5 pestañas no.

---

## 5. Reglas de producto que condicionan la UI

- **Doble moneda.** Los precios se capturan en USD y el monto en Bs se
  calcula con la tasa BCV cacheada. En el onboarding se elige entre
  **Dólares / Bolívares / Ambas**; con "Ambas" los dos montos van con el
  mismo peso visual en la línea grande. Cualquier pantalla con dinero debe
  contemplar los dos importes.
- **Roles.** El dueño ve todo; el empleado registra ventas y ve inventario,
  pero **no** ve reportes financieros ni gastos, ni anula ventas.
- **Plan gratis vs Premium ($5/mes).** El gratis limita a 1 negocio, 50
  productos, 30 días de historial y pone **marca de agua** en el catálogo y
  el Estado.
- **Compartir por WhatsApp** es una superficie de diseño de primera clase,
  no un extra:
  - *Texto:* con emojis, agrupado por categoría, nombre y precio en líneas
    separadas (los nombres de producto son largos y en una línea WhatsApp
    los parte y esconde el precio).
  - *Imagen del catálogo:* lienzo de 460 px de ancho, grilla 3×2. **La
    proporción importa**: WhatsApp recorta la burbuja del chat a algo
    cercano al cuadrado, así que un lienzo alto y angosto pierde el
    encabezado y el pie.
  - *Estado (9:16):* reserva **90 px de zona segura abajo** para el pie y
    los botones que WhatsApp dibuja encima.

---

## 6. Qué necesito de ti

Rehaz los Lotes con este sistema. En concreto:

1. **Sin raya coral** en el chrome de ninguna pantalla.
2. **Banda de huecos** siempre en la misma posición (18 px de alto, 8 px por
   debajo del área segura).
3. Cabeceras propias con `LibretaBackButton`, **nunca `AppBar` de Material**.
4. Todo estado vacío con **ilustración animada + tagline en Caveat + botón
   de acción**, nunca un texto gris suelto centrado.
5. Fondo papel `#FAF8F3` en pantallas internas; el degradado vinotinto→verde
   solo en splash, auth y tutorial.
6. Registro de voz cercano y venezolano en todos los textos.

Si un Lote tuyo propone un patrón que contradiga algo de esto, márcalo y
explica por qué antes de aplicarlo.
