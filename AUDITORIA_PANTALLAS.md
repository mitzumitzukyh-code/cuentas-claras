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
      **Pendiente de decisión:** el copy «Por seguridad cerramos tu sesión» no
      describe la causa real (credenciales que dejaron de servir)
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
      color a mano). **Pendiente:** cerrar también en `inactive` para que el
      candado tape la miniatura del conmutador de tareas — necesita prueba en
      dispositivo
- [x] ~~**Configurando tu cuenta**~~ — **borrada**: nunca se instanció en toda
      la historia del repo, y su painter era un calco del `_CheckAnimadoPainter`
      del splash. `git show HEAD:lib/shared/presentation/configurando_screen.dart`
      la recupera

## Onboarding

- [x] **Selección de rubro** — `/onboarding` (también crea sucursal nueva) · [rubro_selection_screen.dart](lib/features/onboarding/presentation/rubro_selection_screen.dart)
      · 6 arreglados. El gordo: **el paso 2 no guardaba la moneda** —
      `crearNegocio` no tenía el parámetro, así que siempre se escribía `USD`.
      **Pendiente de decisión:** `ModoPrecio` sigue sin consumidores, así que
      la elección se persiste pero todavía no cambia cómo se pintan los precios
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
      **Pendiente:** eliminar sigue siendo solo pulsación larga, sin ninguna
      pista visual — cambiarlo toca el diseño de la fila
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

- [ ] **Catálogo** — `/catalogo` · [catalogo_screen.dart](lib/features/catalogo/presentation/catalogo_screen.dart)
- [ ] **Publicar en estado** — `/catalogo/estado` · [estado_screen.dart](lib/features/catalogo/presentation/estado_screen.dart)

## Negocio y equipo

- [ ] **Mis negocios** — `/mis-negocios` · [mis_negocios_screen.dart](lib/features/negocio/presentation/mis_negocios_screen.dart)
- [ ] **Empleados** — `/perfil/empleados` · [empleados_screen.dart](lib/features/negocio/presentation/empleados_screen.dart)
- [ ] **Detalle de empleado** — `/perfil/empleados/:membresiaId` · [detalle_empleado_screen.dart](lib/features/negocio/presentation/detalle_empleado_screen.dart)
- [ ] **Auditoría** — `/perfil/auditoria` · [auditoria_screen.dart](lib/features/negocio/presentation/auditoria_screen.dart)
- [ ] **Métodos de pago** — `/perfil/metodos-pago` · [metodos_pago_screen.dart](lib/features/negocio/presentation/metodos_pago_screen.dart)
- [ ] **Hoja de bancos** — sheet desde Métodos de pago · [hoja_bancos.dart](lib/features/negocio/presentation/hoja_bancos.dart)
- [ ] **Impresora** — `/perfil/impresora` · [impresora_screen.dart](lib/features/negocio/presentation/impresora_screen.dart)

## Perfil y ajustes

- [ ] **Perfil** — `/perfil` · [perfil_screen.dart](lib/features/perfil/presentation/perfil_screen.dart)
- [ ] **Ajustes** — `/perfil/ajustes` · [ajustes_screen.dart](lib/features/perfil/presentation/ajustes_screen.dart)
- [ ] **Mi perfil** — `/perfil/mi-perfil` · [mi_perfil_screen.dart](lib/features/perfil/presentation/mi_perfil_screen.dart)
- [ ] **Centro de ayuda** — `/perfil/ayuda` · [centro_ayuda_screen.dart](lib/features/perfil/presentation/centro_ayuda_screen.dart)
- [ ] **Legal** — `/perfil/legal` · [legal_screen.dart](lib/features/perfil/presentation/legal_screen.dart)
- [ ] **Eliminar cuenta** — `/perfil/eliminar-cuenta` · [eliminar_cuenta_screen.dart](lib/features/perfil/presentation/eliminar_cuenta_screen.dart)

## Otros

- [ ] **Planes / Premium** — `/planes` · [planes_screen.dart](lib/features/planes/presentation/planes_screen.dart)
- [ ] **Notificaciones** — `/notificaciones` · [notificaciones_screen.dart](lib/features/notificaciones/presentation/notificaciones_screen.dart)

---

## Dos ámbares conviviendo — pendiente de tu decisión

`#F2A93C` está escrito a mano **43 veces en 22 archivos** para halos, fondos de
aviso y bordes. `LibretaColors.aviso` es `#B07D1E`, mucho más oscuro, y se usa
para texto e iconos. Son dos tonos distintos y con sentido —el brillante no
tiene contraste para texto sobre papel— pero solo uno era un token.

Añadí `LibretaColors.ambarSuperficie` con el valor tal cual (`#F2A93C`), sin
mover ningún píxel. Quedan dos cosas para ti:

1. El brief de marca dice **`#F2A93B`** y todo el código usa **`#F2A93C`**. Un
   dígito. Nadie lo decidió.
2. Migrar los 43 usos al token es un cambio mecánico de 22 archivos: mejor en
   un commit propio que mezclado con la auditoría.

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
