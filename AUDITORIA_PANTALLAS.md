# Auditoría de pantallas — Cuenta Clara

Inventario completo de las pantallas que existen hoy en `lib/`, para irlas
auditando una por una. 53 archivos `*_screen.dart` + 2 superficies que no son
`_screen` pero se comportan como pantalla.

Estado: `[ ]` sin auditar · `[~]` auditada con hallazgos abiertos · `[x]` limpia.

## Qué se revisa en cada una

Los mismos seis puntos en todas, para que el resultado sea comparable:

1. **Estados** — cargando / error / vacío se ven distintos (`LibretaCargando`,
   `LibretaErrorCarga`); nada de `valueOrNull ?? const []`.
2. **Errores** — todo lo que se le enseña al usuario pasa por
   `mensajeDeError(...)`; ningún `$e` crudo en pantalla.
3. **Permisos y plan** — el empleado no ve lo que no le toca (`PermisoRequerido`,
   `Permisos.*`) y los límites del plan gratis se aplican de verdad, no solo en
   la UI.
4. **Datos vivos** — nada crítico se pinta desde `s.extra`; lo que cambia
   mientras la pantalla está abierta viene de un provider.
5. **Diseño** — tokens de marca, sangrado 24, USD con coma (`MoneyFormatter`),
   números tabulares, sin scroll horizontal, cabe en el Z2464N.
6. **Vacíos y textos** — el estado vacío dice qué hacer, el vocabulario sale de
   `ref.vocab`, y ningún texto asume un rubro.

---

## Sesión y arranque

- [x] **Splash** — `/splash` · [splash_screen.dart](lib/shared/presentation/splash_screen.dart)
      · 5 hallazgos arreglados (blanco al cargar lento, mínimo con animaciones
      off, tokens, `quieto` muerto, semántica)
- [x] **Login** — `/login` · [login_screen.dart](lib/features/auth/presentation/login_screen.dart)
      · 7 hallazgos arreglados (mensaje crudo de Firebase, jerga de SHA-1,
      `catch` que culpaba a la red, objetivos táctiles, banner mudo y pegajoso,
      doble envío por teclado, color a mano)
- [x] **Registro** — push desde Login · [registro_screen.dart](lib/features/auth/presentation/registro_screen.dart)
      · 8 hallazgos arreglados (Términos/Privacidad no abrían, mensaje crudo,
      sin `AutofillGroup`, `catch` que culpaba a la red, botón apagado sin
      pista, objetivos táctiles, doble envío, banner duplicado)
- [x] **Recuperar contraseña** — push desde Login · [recuperar_screen.dart](lib/features/auth/presentation/recuperar_screen.dart)
      · 8 hallazgos arreglados (correo no registrado sin salida + enumeración,
      `too-many-requests`, banner, objetivo táctil, error pegajoso, autofill,
      copy del botón, estado «Enviado» sin salida)
- [x] **Sesión expirada** — `/sesion-expirada` · [sesion_expirada_screen.dart](lib/features/auth/presentation/sesion_expirada_screen.dart)
      · 3 arreglados (ancho del botón, color a mano, adorno sin excluir).
      · el copy ya describe la causa real: «Tus datos de acceso cambiaron»
- [x] **Error de sesión** — `/sesion-error` · [sesion_error_screen.dart](lib/shared/presentation/sesion_error_screen.dart)
      · 5 arreglados (mensaje de reglas de Firestore al usuario, detección por
      `toString()`, cierre de sesión sin esperar, cuarto ámbar a mano, texto
      genérico que culpaba a la conexión)
- [x] **Error de conexión** — envuelta por la anterior · [conexion_error_screen.dart](lib/shared/presentation/conexion_error_screen.dart)
      · 3 arreglados (cuarto ámbar a mano, ancho del botón, adorno sin excluir)
- [x] **Error de configuración de Firebase** — `home:` en [app.dart](lib/app/app.dart) · [firebase_config_error_screen.dart](lib/shared/presentation/firebase_config_error_screen.dart)
      · las instrucciones de `flutterfire configure` y la excepción ahora solo
      salen en debug; en release, un texto que el dueño puede entender y actuar
- [x] **Bloqueo biométrico** — overlay sobre toda la app · [bloqueo_biometrico.dart](lib/features/auth/presentation/bloqueo_biometrico.dart)
      · 3 arreglados (`_pidiendo` sin `finally`, overlay sin tapar la semántica,
      color a mano) + cierre en `inactive` para tapar la miniatura del
      conmutador. **Y la causa de que nunca protegiera nada:** `MainActivity`
      era `FlutterActivity`, y `local_auth` exige `FragmentActivity`; cada
      `authenticate()` lanzaba `no_fragment_activity` y `pedir()` devolvía
      `true`. **Falta probarlo en dispositivo con huella registrada**
- [x] ~~**Configurando tu cuenta**~~ — **borrada**: nunca se instanció en toda
      la historia del repo, y su painter era un calco del `_CheckAnimadoPainter`
      del splash. `git show HEAD:lib/shared/presentation/configurando_screen.dart`
      la recupera

## Onboarding

- [x] **Selección de rubro** — `/onboarding` (también crea sucursal nueva) · [rubro_selection_screen.dart](lib/features/onboarding/presentation/rubro_selection_screen.dart)
      · 6 arreglados. El gordo: **el paso 2 no guardaba la moneda** —
      `crearNegocio` no tenía el parámetro, así que siempre se escribía `USD`.
      · `ModoPrecio` quedó cableado después en 9 superficies
- [x] **Unirse con código** — `/perfil/unirse-codigo` · [unirse_codigo_screen.dart](lib/features/onboarding/presentation/unirse_codigo_screen.dart)
      · 5 arreglados (desbordaba con el teclado por un `Spacer`, banner
      duplicado, `catch` que culpaba a la red, sin mayúsculas ni tecla de
      envío, colores a mano)
- [x] **Tutorial** — `/tutorial` · [tutorial_screen.dart](lib/features/onboarding/presentation/tutorial_screen.dart)
      · 3 arreglados (los puntos ya son un carrusel de verdad — `PageView`, se
      desliza y se vuelve atrás; «Saltar» con área de 48 y rol de botón;
      indentación)

## Inicio

- [x] **Dashboard** — `/` · [dashboard_screen.dart](lib/features/dashboard/presentation/dashboard_screen.dart)
      · 4 arreglados (el banner de error decía «revisa tu conexión» hasta para
      un `permission-denied`; tirar para refrescar no recargaba los datos que
      habían fallado; 8 colores a mano). Sus tres widgets acompañantes
      (`urgencias`, `coachmark`, `sugerencia_uso`) quedan sin auditar
      (revisar junto con [urgencias.dart](lib/features/dashboard/presentation/urgencias.dart),
      [coachmark_primer_uso.dart](lib/features/dashboard/presentation/coachmark_primer_uso.dart) y
      [sugerencia_uso.dart](lib/features/dashboard/presentation/sugerencia_uso.dart))

## Inventario

- [x] **Productos / Mercancía** — `/productos` · [productos_screen.dart](lib/features/productos/presentation/productos_screen.dart)
      · 5 arreglados. Dos de fondo: «Pedir reabastecimiento» abría el selector
      de contactos en vez del chat del proveedor (armaba la URL de `wa.me` a
      mano, sin código de país), y el CSV exportado se partía con un nombre
      con comillas. El escapado de CSV sale de `RespaldoService` a
      `shared/utils/csv.dart`, con pruebas
- [x] **Nuevo producto** — `/productos/nuevo` · [nuevo_producto_screen.dart](lib/features/productos/presentation/nuevo_producto_screen.dart)
      · 4 arreglados, tres de ellos dejaban el botón de guardar muerto sin
      decir por qué: un producto sin precio abría con la palabra «null» en la
      casilla, un precio escrito `1.250,50` no parseaba, y una cantidad
      decimal tampoco (validaba con `int` y guardaba con `double`). Las cifras
      pasan por `normalizarNumeroVE`, el mismo lector que ya usaba el
      importador de fotos
- [x] **Insumos** — `/productos/insumos` · [insumos_screen.dart](lib/features/productos/presentation/insumos_screen.dart)
      · 5 arreglados: `valueOrNull ?? const []` (el antipatrón que CLAUDE.md
      nombra), «1.500 gramos» se guardaban como 1,5, guardar y eliminar sin
      `try`, el botón «Guardar» que no hacía nada, y un color a mano.
      · la fila ya tiene su papelera visible (la pulsación larga sigue
      funcionando)
- [x] **Contar inventario (arqueo)** — `/productos/contar` · [arqueo_inventario_screen.dart](lib/features/productos/presentation/arqueo_inventario_screen.dart)
      · 4 arreglados (`valueOrNull ?? const []`, «1.500» contado como 1,5,
      `Text('$e')` crudo, color a mano)
- [x] **Importar inventario (foto / Excel)** — `/productos/importar` · [importar_inventario_screen.dart](lib/features/productos/presentation/importar_inventario_screen.dart)
      · 3 arreglados (dos `$e` crudos en pantalla, color a mano)
- [x] **Migrar desde otra app** — `/productos/migrar` · [migrar_otra_app_screen.dart](lib/features/productos/presentation/migrar_otra_app_screen.dart)
      · 1 arreglado (degradado de marca copiado a mano). La pantalla es un
      enganche a una importación que todavía dice «muy pronto»

## Ventas

- [x] **Cobrar** — `/cobrar` (+ `?modo=cotizacion`, `?escanear=1`) · [cobrar_screen.dart](lib/features/ventas/presentation/cobrar_screen.dart)
      · 5 arreglados: la excepción cruda al fallar el cobro, «1.500» kg leído
      como 1,5, un monto libre ilegible que se ponía en cero (cobro regalado),
      y colores a mano
- [x] **Historial de ventas** — `/ventas/historial` · [historial_screen.dart](lib/features/ventas/presentation/historial_screen.dart)
      · 1 (color a mano)
- [x] **Detalle de venta** — `/ventas/detalle/:ventaId` · [venta_detalle_screen.dart](lib/features/ventas/presentation/venta_detalle_screen.dart)
      · 2 arreglados: spinner infinito si el historial fallaba, colores
- [x] **Filtro de ventas** — push desde Historial · [filtro_ventas_screen.dart](lib/features/ventas/presentation/filtro_ventas_screen.dart)
      · limpia
- [x] **Ventas pendientes (offline)** — `/ventas/pendientes` · [ventas_pendientes_screen.dart](lib/features/ventas/presentation/ventas_pendientes_screen.dart)
      · 3 (colores a mano)

## Gastos

- [x] **Gastos del mes** — `/gastos` · [gastos_screen.dart](lib/features/gastos/presentation/gastos_screen.dart)
      · 3 colores. Los estados de carga/error/vacío ya estaban bien
- [x] **Registrar / editar gasto** — `/gastos/nuevo` · [registrar_gasto_screen.dart](lib/features/gastos/presentation/registrar_gasto_screen.dart)
      · 2 arreglados («1.500» registrado como 1,5; color)
- [x] **Detalle de gasto** — push desde Gastos · [gasto_detalle_screen.dart](lib/features/gastos/presentation/gasto_detalle_screen.dart)
      · limpia

## Fiados (por cobrar)

- [x] **Clientes fiados** — `/fiados` · [fiados_screen.dart](lib/features/fiados/presentation/fiados_screen.dart)
      · 4 (error sin Reintentar, 3 colores)
- [x] **Detalle de cliente** — `/fiados/:clienteId` · [cliente_fiado_detalle_screen.dart](lib/features/fiados/presentation/cliente_fiado_detalle_screen.dart)
      · 1 color. Ya usaba `ModoPrecio` desde el cableado
- [x] **Anotar fiado / abono** — `/fiados/:clienteId/movimiento` · [anotar_movimiento_screen.dart](lib/features/fiados/presentation/anotar_movimiento_screen.dart)
      · 2 («1.500» anotado como 1,5 en el libro mayor; `accion` vaga)

## Proveedores (por pagar)

- [x] **Proveedores** — `/proveedores` · [proveedores_screen.dart](lib/features/proveedores/presentation/proveedores_screen.dart)
      · 2 (error sin Reintentar, color)
- [x] **Detalle de proveedor** — `/proveedores/:proveedorId` · [proveedor_detalle_screen.dart](lib/features/proveedores/presentation/proveedor_detalle_screen.dart)
      · 2 (error de movimientos sin Reintentar, color)
- [x] **Anotar compra / pago** — `/proveedores/:proveedorId/movimiento` · [anotar_movimiento_proveedor_screen.dart](lib/features/proveedores/presentation/anotar_movimiento_proveedor_screen.dart)
      · 2 («1.500» anotado como 1,5; `accion` vaga)

## Cierre de caja

- [x] **Arqueo de caja** — `/arqueo` · [arqueo_caja_screen.dart](lib/features/cierre/presentation/arqueo_caja_screen.dart)
      · 5 (efectivo «1.500» contado como 1,5, `Text('$e')` crudo, carga sin
      Reintentar, 3 colores) + `ModoPrecio` cableado
- [x] **Resumen del día** — `/arqueo/resumen/:cierreId` · [resumen_dia_screen.dart](lib/features/cierre/presentation/resumen_dia_screen.dart)
      · 4 colores + `ModoPrecio` cableado

## Reportes

- [x] **Reportes** — `/reportes` · [reportes_screen.dart](lib/features/reportes/presentation/reportes_screen.dart)
      · 4 (un fallo de carga pintaba $0,00 y gráfico plano — «no vendiste
      nada»; 3 colores)
- [x] **Exportar reporte (Excel / PDF)** — push desde Reportes · [exportar_reporte_screen.dart](lib/features/reportes/presentation/exportar_reporte_screen.dart)
      · limpia

## Catálogo

- [x] **Catálogo** — `/catalogo` · [catalogo_screen.dart](lib/features/catalogo/presentation/catalogo_screen.dart)
      · 3 (spinner infinito si falla el negocio, `$e` crudo, color)
- [x] **Publicar en estado** — `/catalogo/estado` · [estado_screen.dart](lib/features/catalogo/presentation/estado_screen.dart)
      · 1 (spinner infinito). Los ~38 colores son paletas de plantilla, no
      tokens de marca: se dejan

## Negocio y equipo

- [x] **Mis negocios** — `/mis-negocios` · [mis_negocios_screen.dart](lib/features/negocio/presentation/mis_negocios_screen.dart)
      · 2 colores. Su `valueOrNull ?? const []` se deja: si las membresías
      fallan, el router manda a `/sesion-error` y esta pantalla no se pinta
- [x] **Empleados** — `/perfil/empleados` · [empleados_screen.dart](lib/features/negocio/presentation/empleados_screen.dart)
      · 5 (3 `$e` crudos, 2 colores)
- [x] **Detalle de empleado** — `/perfil/empleados/:membresiaId` · [detalle_empleado_screen.dart](lib/features/negocio/presentation/detalle_empleado_screen.dart)
      · 3 (`$e` crudo, 2 colores)
- [x] **Auditoría** — `/perfil/auditoria` · [auditoria_screen.dart](lib/features/negocio/presentation/auditoria_screen.dart)
      · 1 (un fallo pintaba «aquí no ha pasado nada» en el registro que existe
      para saber qué pasó)
- [x] **Métodos de pago** — `/perfil/metodos-pago` · [metodos_pago_screen.dart](lib/features/negocio/presentation/metodos_pago_screen.dart)
      · 5 (spinner infinito, `$e` crudo, 3 colores)
- [x] **Hoja de bancos** — sheet desde Métodos de pago · [hoja_bancos.dart](lib/features/negocio/presentation/hoja_bancos.dart)
      · 1 color
- [x] **Impresora** — `/perfil/impresora` · [impresora_screen.dart](lib/features/negocio/presentation/impresora_screen.dart)
      · 8 (2 `$e` crudos, 6 colores)

## Perfil y ajustes

- [x] **Perfil** — `/perfil` · [perfil_screen.dart](lib/features/perfil/presentation/perfil_screen.dart)
      · 2 colores
- [x] **Ajustes** — `/perfil/ajustes` · [ajustes_screen.dart](lib/features/perfil/presentation/ajustes_screen.dart)
      · 4 (spinner infinito, 3 colores)
- [x] **Mi perfil** — `/perfil/mi-perfil` · [mi_perfil_screen.dart](lib/features/perfil/presentation/mi_perfil_screen.dart)
      · 1 color
- [x] **Centro de ayuda** — `/perfil/ayuda` · [centro_ayuda_screen.dart](lib/features/perfil/presentation/centro_ayuda_screen.dart)
      · 1 color (los otros 3 no son tokens: degradado, blanco con alfa y el
      gris de WhatsApp)
- [x] **Legal** — `/perfil/legal` · [legal_screen.dart](lib/features/perfil/presentation/legal_screen.dart)
      · 1 color
- [x] **Eliminar cuenta** — `/perfil/eliminar-cuenta` · [eliminar_cuenta_screen.dart](lib/features/perfil/presentation/eliminar_cuenta_screen.dart)
      · 3 colores. Sus errores ya pasaban por `mensajeDeError`

## Otros

- [x] **Planes / Premium** — `/planes` · [planes_screen.dart](lib/features/planes/presentation/planes_screen.dart)
      · 7 colores. El botón dice «Próximamente» y está deshabilitado, que es
      honesto: no hay capa de planes (ver arriba)
- [x] **Notificaciones** — `/notificaciones` · [notificaciones_screen.dart](lib/features/notificaciones/presentation/notificaciones_screen.dart)
      · 5 colores. Sin estados asíncronos que auditar: son preferencias
      locales

---

## Capa de planes — construida menos la compra

`lib/features/planes/` ya tiene `domain/plan.dart` (los topes, en un solo
sitio) y `data/plan_repository.dart` (de dónde sale el plan de cada quien).

**El plan es de la persona y el negocio hereda el del dueño.** Un empleado de
un negocio Premium trabaja sin marca de agua sin pagar aparte.

Aplicado hoy, siempre al crear y nunca sobre lo que ya existe:

- **1 negocio** — al abrir otra sucursal desde el onboarding.
- **50 productos** — al dar de alta, no al editar.
- **1 usuario** — al generar el código de invitación.
- **Marca de agua** — catálogo y Estado la llevan solo en gratis.

`diasHistorial` está declarado pero **no aplicado a propósito**: a diferencia
de los otros, no impediría crear algo nuevo sino que escondería ventas ya
registradas. Queda en el modelo para el día que se decida aplicarlo con aviso.

### Lo que falta, y por qué

La **compra** no está. Necesita dos cosas que hoy no existen: los productos
dados de alta en Google Play Console, y una Cloud Function que verifique el
recibo. Sin la segunda, marcar Premium desde el cliente lo falsifica cualquiera
con el teléfono en la mano — por eso `suscripciones/{usuarioId}` está en
`allow write: if false` en las reglas: solo el Admin SDK de una función podrá
escribir ahí.

### Interruptor de pruebas

Para probar los caminos Premium sin tocar Firestore ni desplegar reglas:


Running Gradle task 'assembleRelease'...                           17.7s
√ Built buildpp\outputslutter-apkpp-release.apk (90.1MB)

Es de tiempo de compilación: un APK sin esa bandera no contiene el código, así
que no hay nada que activar desde el teléfono. La pantalla de planes avisa en
rojo cuando está puesto. Hay un test que falla si alguien lo deja encendido.

### Los negocios viejos no tienen `creadoPor`

`planDelNegocioProvider` averigua el plan preguntándoselo al dueño, y sabe quién
es por `negocios/{id}.creadoPor`. Los negocios creados antes de que ese campo
existiera no lo traen, así que caen en `gratis` pase lo que pase: un dueño que
pagó Premium se vería en el plan gratis sin entender por qué.

No se puede arreglar desde la app. Las reglas declaran `creadoPor` inmutable en
el `update`, y no por descuido — es la prueba que autoriza a concederse la
membresía de dueño (`esFundador`). Reescribirlo desde el cliente permitiría
regalar o robar esa capacidad.

Va con el Admin SDK, ejecutado por una persona:

```
npm install firebase-admin
set GOOGLE_APPLICATION_CREDENTIALS=C:\ruta\a\tu-clave.json
node herramientas/rellenar_creado_por.js            # informe
node herramientas/rellenar_creado_por.js --aplicar  # escribe
```

Solo rellena los negocios con **exactamente una** membresía de dueño. Con cero o
con varias se listan aparte sin tocarlos: elegir sería repartir a dedo quién
puede fundar membresías.

### Antes de que esto sirva

**Hay que desplegar `firestore.rules`.** La regla de `suscripciones` está en el
archivo pero no en el proyecto. Mientras tanto la lectura se deniega y todo el
mundo sale `gratis`, que es el comportamiento correcto por defecto — pero un
Premium real no se vería hasta desplegarlas.

## Los dos ámbares — resuelto

`LibretaColors.aviso` (`#B07D1E`) es para **texto e iconos**; el nuevo
`LibretaColors.ambarSuperficie` es para **superficies** —halos, fondos de
aviso, bordes—. Son dos tonos distintos a propósito: el brillante no tiene
contraste suficiente para texto sobre papel.

Las 43 apariciones a mano ya están migradas al token, y el valor se alineó al
brief (`#F2A93B`, no el `#F2A93C` que usaba el código). La diferencia es de
1/255 en el canal azul: invisible.

## Widgets compartidos que salieron de la auditoría

Login y Registro tenían la misma pieza escrita dos veces. Viven ya en
`lib/shared/presentation/libreta/` y traen el área táctil de 48 y la semántica
puestas, así que la siguiente pantalla que las use no vuelve a nacer con esos
defectos:

- `LibretaEnlace` — texto pulsable con caja de 48 y rol de botón.
- `LibretaBannerError` — aviso de formulario con `liveRegion`.
- `LibretaOjoContrasena` — mostrar/ocultar contraseña, 48 de área sin mover el
  icono de sitio.

Las tres pantallas de auth ya los consumen. `LibretaEnlace` acepta `color` para
los enlaces que el diseño quiere discretos (gris en vez de verde).

## Notas de este inventario

- **`ConfigurandoScreen` no la usa nadie**: no aparece en el router ni en ningún
  `MaterialPageRoute`. O se conecta al flujo de alta de negocio o se borra.
- **Ocho rutas van envueltas en `PermisoRequerido`**: auditoría, contar
  inventario, insumos, nuevo producto, reportes, gastos, nuevo gasto, arqueo de
  caja. El resto no tiene guarda de permiso — verificar en la auditoría si
  alguna debería tenerla (fiados, proveedores, catálogo, métodos de pago).
- **Seis pantallas se abren por `Navigator.push` y no por ruta** (registro,
  recuperar, filtro de ventas, exportar reporte, detalle de gasto, hoja de
  bancos): no son enlazables ni recuperan estado al reabrir la app.

## Segunda pasada sobre Cobrar (2026-08-12)

La primera pasada miró la pantalla; esta miró el **camino del dinero**: qué se
guarda cuando se toca "Cobrar". Siete hallazgos, tres tocan plata.

### 1. Vender por peso cobra de más o regala — `cobrar_screen.dart:221-225`

`_pedirCantidad` pregunta «¿Cuántos kg?» y la respuesta pasa por
`kg.round()`, porque `ItemCarrito.cantidad` es `int`.

| El cliente pide | Se guarda | Queso a $8/kg |
|---|---|---|
| 2,5 kg | 3 | cobra $24 en vez de $20 |
| 1,5 kg | 2 | cobra $16 en vez de $12 |
| 0,4 kg | **0** | **$0,00 — se regala** |

Lo llamativo es que **todo lo demás ya soporta decimales**:
`ItemVenta.cantidad` es `double` y su doc dice literalmente «Unidades, o kilos
si `vendidoPorPeso`»; `Producto.cantidad` es `double` «porque los productos
`vendidoPorPeso` se descuentan en kilos». Hasta existe `ItemCarrito.pesoKg`,
declarado y **jamás escrito ni leído por nadie** — el sitio donde el peso
tenía que ir, con el hueco a la vista. El carrito es el único eslabón entero
en enteros.

Dos rubros traen `vendePorPeso: true` de fábrica y hay un interruptor por
producto, así que no es una rama muerta.

### 2. La venta no recuerda que era por peso — `cobrar_screen.dart:803-813`

El `ItemVenta` se arma sin `vendidoPorPeso`, que por defecto es `false`. El
historial y los reportes enseñan «3» donde debería decir «3 kg»:
`ItemVenta.cantidadLabel` ya sabe formatearlo, pero nunca se entera.

### 3. Con variantes se puede vender más de lo que hay — `cobrar_screen.dart:724-734`

`_stockInsuficiente` recorre el carrito **línea a línea** y compara cada una
contra `p.cantidad`, que es el stock **total** del producto. Pero
`CarritoNotifier.agregar` fusiona por producto *y variante*, así que una
franela con talla M y L son dos líneas del mismo `productoId`.

Con 6 en total (3 M y 3 L) y `bloquearAlAgotarse`: 4 M + 4 L pasan el control
—cada línea compara 4 contra 6— y se venden 8. El stock por variante no se
comprueba en ningún momento: la hoja de variantes solo desactiva la que está
en cero, pero deja pedir 5 de la que tiene 1.

### 4. La cotización enseña líneas que no suman el total — `cobrar_screen.dart:892-904`

`lineas` recorre solo `carrito`, y el total sale de `_totalDe`, que **suma
`_montoLibre`**. Una cotización con monto libre se manda con un desglose al
que le falta plata: el cliente recibe tres renglones y un total mayor.

### 5. Cero `Semantics` en toda la pantalla, con once `GestureDetector`

Ni las pastillas BCV/Paralelo, ni el segmentado Venta/Cotización, ni las de
método de pago, ni las fichas del catálogo. Para un lector de pantalla la
pantalla de cobrar es un montón de texto suelto sin nada pulsable. Es la
pantalla que más se usa de la app.

### 6. Dos controladores de texto sin liberar — `cobrar_screen.dart:315, 344`

`_pedirCantidad` y `_abrirMontoLibre` crean su `TextEditingController` y no lo
liberan. `_pedirNumeroSuelto` sí lo hace con `whenComplete`, que es el patrón
correcto y está tres funciones más abajo.

### 7. La variante agotada no dice por qué no se puede tocar — `cobrar_screen.dart:301`

`onTap: v.cantidad <= 0 && p.bloquearAlAgotarse ? null : ...`. El renglón se
queda mudo con el mismo aspecto que los demás. Debajo dice «Quedan 0», pero
nada conecta las dos cosas.

### Estado

Arreglados **1, 2, 3 y 4** (2026-08-12). `ItemCarrito` gana `pesoKg` de verdad
—con `cantidadCobrada` y `cantidadLabel` derivados—, el carrito acumula kilos
en vez de unidades, `ItemVenta` recibe `vendidoPorPeso`, el control de stock
suma por producto y mira la casilla de la variante, y el desglose de la
cotización incluye el monto libre. Siete pruebas nuevas en
`test/domain/carrito_test.dart`.

Pendientes: **5** (cero `Semantics` con once `GestureDetector`), **6** (dos
controladores sin liberar) y **7** (la variante agotada no dice por qué).
