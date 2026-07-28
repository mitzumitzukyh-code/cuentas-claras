# Plan de implementación — pulido de diseño (Claude Design, 27-28 jul 2026)

> Origen: comparación de los 18 lotes pulidos del proyecto Claude Design
> `777ed08d-4e50-4489-bf96-ccf00333c065` contra el código en `master`
> (commit `0df12d5`). El handoff que se implementó es el del 23-jul
> (`design_handoff_cuenta_clara/`); los lotes pulidos son de 3-5 días después.
>
> **Estado: NO IMPLEMENTADO.** Este documento es el plan de trabajo.

---

## Decisiones cerradas (no volver a discutirlas)

| # | Decisión | Valor | Nota |
|---|---|---|---|
| D1 | Sangrado lateral | **24 px** | `Comparación sangrado.dc.html` col. B. Deroga los 54 px y también el "22 px" de `system-diseno-libreta.md`. |
| D2 | Formato USD | **coma decimal, punto de miles** (`$1.284.590,50`) | Se mantiene `MoneyFormatter.usd` tal cual. El diseño se contradice entre lotes (O/N usan punto; P/Q usan coma); gana la coma por consistencia con Bs y con lo ya corregido en el Lote L. **No tocar `money_formatter.dart`.** |
| D3 | Cobrar | **híbrido: carrito + monto libre en la misma pantalla** | El carrito descuenta inventario; el monto libre no (ya soportado por `VentaRepository`). |
| D4 | IVA en Ajustes | **se queda** | El diseño la quitó porque "no hay modelo"; sí lo hay (`Negocio.incluirIva`, `Negocio.tasaIva`, usado en `cobrar_screen.dart`). El diseño manda en color/tipografía/espaciado, el código manda en comportamiento (`system-diseno-libreta.md` § Precedencia). |

**Regla de precedencia para lo que salga durante la implementación:** el diseño
manda en color, tipografía, espaciado y superficie; el código manda en
navegación, rutas y lógica de estado.

---

## Cómo trabajar este plan

- Una rama por fase: `pulido/f1-tokens`, `pulido/f2-modelo`, …
- Cada fase termina con `flutter analyze` limpio + `flutter test` en verde + commit.
- Verificación en dispositivo: **`adb install -r`**, nunca `flutter install`
  (el reinstall borra la sesión y las suscripciones FCM).
- Probar el Z2464N **en vertical**, no forzar horizontal.
- Ojo con `animator_duration_scale` en null en el Z2464N: salta las animaciones,
  no es un bug de la app.
- Las fases 1→5 son secuenciales por dependencia. 6, 7 y 8 pueden reordenarse.

---

## FASE 0 · Preparación (~30 min)

**Objetivo:** que el repo refleje las decisiones antes de escribir widgets.

1. Actualizar `CLAUDE.md`:
   - §4 modelo de datos: añadir los campos nuevos de la Fase 2.
   - §7: quitar las funciones de IA del "fuera de alcance" (ya están construidas).
   - Añadir §10 apuntando a este plan.
2. Copiar `system-diseno-libreta.md` del proyecto de diseño a
   `design_handoff_cuenta_clara/` y anotar D1–D4 como resueltas.
3. Crear `pulido/f1-tokens` desde `master`.

**Criterio de aceptación:** `CLAUDE.md` ya no contradice el estado real del código.

---

## FASE 1 · Tokens globales (~3-4 h) — bajo riesgo, alto impacto visual

Toca casi toda la app pero es mecánica. Hacerla primero evita re-tocar pantallas
en fases posteriores.

### 1.1 Sangrado 54 → 24 px
- `lib/shared/presentation/libreta/libreta_chrome.dart:124` →
  `static const double padIzquierdo = 24;` y reescribir el docstring
  (ya no es "el sangrado del sistema que no conviene mover": ahora sí se mueve).
- Reemplazar `EdgeInsets.fromLTRB(54,` → `fromLTRB(24,` en los **38 archivos**
  que lo usan (`grep -rn "fromLTRB(54" lib/`).
- `dashboard_screen.dart`: el padding izquierdo hoy es `marginLeft + sidePadding`
  (48/56/60 px). Quitar `marginLeft` del `Padding` y dejar `sidePadding`
  = 20/24/26 por tier (el frame canónico "Normal 400×850" del Lote Q usa 18-20).
  `marginLeft`/`marginAlpha` quedan muertos en `_S` → borrarlos.
- `libreta_estado_vacio.dart` también tiene referencias al margen: revisar.

**Riesgo:** pantallas cuyo layout compensaba a mano los 54 px (títulos centrados,
tarjetas full-bleed). **Mitigación:** recorrer las ~34 pantallas en el emulador
antes de commitear; el diff es plano y se revierte fácil.

### 1.2 Borde de tarjeta hero en modo oscuro
- Añadir a `LibretaColors`:
  `static const Color bordeHeroOscuro = Color(0x52F7E7C6); // cream tagline 32%`
- Exponer en `LibretaTokens` un `bordeHero` (`null`/transparente en claro,
  `bordeHeroOscuro` en oscuro) para no repetir el condicional.
- Aplicar `Border.all(color: t.bordeHero, width: 1.5)` en las tarjetas
  `LibretaColors.tarjetaOscura`:
  - `cobrar_screen.dart:170`
  - `fiados_screen.dart:82`
  - `proveedores_screen.dart:72`
  - revisar también el hero de `resumen_dia_screen.dart` y `arqueo_caja_screen.dart`.
- **No** aplicarlo a los avatares circulares (`shape: BoxShape.circle`), que usan
  el mismo color pero no son tarjetas.

**Criterio:** contraste de área ≥3:1 sobre `#1C1B18` (el diseño mide 3,26:1).

### 1.3 "Binance" → "Paralelo" en texto visible
- `core/providers/tasa_activa_provider.dart:23`: `'tasa Binance USDT'` → `'tasa paralela'`.
- Pastilla de Cobrar: `'Binance'` → `'Paralelo'`.
- `ajustes_screen.dart:647-648`: `'Binance USDT'` / `'Promedio del mercado P2P'`
  → `'Paralelo'` / `'mercado P2P'`.
- Dashboard `_InlineTasa`: etiqueta `'Binance'` → `'Paralelo'`.
- **No renombrar** el enum `TipoTasa.binance`, `BinanceP2pService`, ni las claves
  persistidas: es solo copy de cara al usuario.

### 1.4 Banner de "sin conexión" en encabezados
- Nuevo widget `LibretaAvisoOfflineCompacto` (pastilla ámbar
  `rgba(242,169,60,.14)`, borde `.35`, texto `#B07D1E` 11 px w700, icono wifi-off):
  "Sin conexión — se guarda y sube solo".
- Montarlo bajo el título en: Cobrar, Productos, Fiados, Reportes y Estado
  (en Estado el copy cambia: "necesitas internet para publicar en Estado").
- Se alimenta de `conectividad_provider.dart` (ya existe).

### 1.5 Confirmar fuente única de formato
- `grep -rn "toStringAsFixed\|NumberFormat" lib/` y sustituir cualquier formateo
  inline de dinero por `MoneyFormatter`. **No cambiar el formato** (D2).

**Salida de la fase:** commit `Pulido F1: sangrado 24px, borde hero oscuro, tasa paralela, aviso offline`.

---

## FASE 2 · Modelo de datos y reglas (~4-5 h) — una sola pasada de migración

Todo lo que viene después depende de estos campos. Hacerlo de una vez evita tres
migraciones distintas de Firestore.

### 2.1 `Producto` (`features/productos/domain/producto.dart`)
Campos nuevos, **todos opcionales y con default**, para que los documentos
existentes sigan leyéndose sin migración de datos:

| Campo | Tipo | Default | Origen |
|---|---|---|---|
| `tipo` | `TipoProducto` (`simple`\|`variantes`\|`serial`) | `simple` | Lote C |
| `bloquearAlAgotarse` | `bool` | `false` | Lote C ("Cuando el stock llegue a 0") |
| `precioAnterior` | `double?` | `null` | Lote C (oferta) |
| `enOferta` | `bool` | `false` | Lote C |
| `garantiaMeses` | `int?` | `null` | Lote C (rubro Electrónica) |

- `precioEfectivo` como getter: `enOferta && precioAnterior != null ? precio : precio`
  (el `precio` **siempre** es el vigente; `precioAnterior` es solo el tachado).
- `descuentoPct` getter derivado, para pintar "−16 %".

### 2.2 `Membresia` — permisos por empleado
- Añadir `Map<String, bool> permisos` con 6 claves:
  `cobrar`, `verReportes`, `editarInventario`, `registrarGastos`, `cerrarCaja`,
  `gestionarEmpleados`.
- Presets: `RolMembresia.dueno` → todos `true` (y no editables);
  `RolMembresia.empleado` → `cobrar: true`, resto `false`.
- **Compatibilidad:** si el documento no trae `permisos`, derivarlos del rol.
  Nunca leer `permisos` sin fallback — hay membresías en producción sin el campo.
- Exponer en `core/session/sesion_provider.dart` un `puedeProvider(permiso)`.

### 2.3 `MetodoPagoConfig` — banco del pago móvil
- Añadir `codigoBanco` (String, ej. `'0102'`), `telefonoAsociado`, `cedulaRif`.
- Constante nueva `core/constants/bancos_venezuela.dart` con los 26 bancos
  (código + nombre) del Lote E · P7. Lista estática, no viene de red.

### 2.4 Reglas de Firestore (`firestore.rules`)
- Los campos nuevos de `productos` caen bajo las reglas existentes de
  `negocios/{negocioId}/productos/**` — verificar que no haya validación de
  esquema estricta que los rechace.
- `membresias/{id}.permisos`: solo el **dueño** del negocio puede escribirlo.
  Un empleado no puede elevarse a sí mismo. Añadir test en `test_rules/`.
- Las lecturas ya validan membresía; no relajar nada.

### 2.5 Tests
- `test/domain/producto_test.dart`: `fromMap` con documento viejo (sin campos
  nuevos) devuelve defaults; `descuentoPct` calcula bien.
- `test/domain/membresia_test.dart`: permisos derivados del rol cuando falta el map.
- `test_rules/`: empleado no puede escribir `permisos`.

**Salida:** commit `Pulido F2: modelo de producto, permisos de membresía y banco de pago móvil`.

---

## FASE 3 · Cobrar híbrido (~8-10 h) — la pieza central

**El objetivo:** una sola pantalla con dos modos de captura que producen la misma
`Venta`; el modo carrito descuenta inventario, el de monto libre no.

`VentaRepository.registrarVenta` **ya distingue** ambos casos: los `ItemVenta`
con `productoId` vacío no tocan inventario (`_porProducto`). No hay que rediseñar
el repositorio, solo alimentarlo con ítems reales.

### 3.1 Estado del carrito
- `features/ventas/domain/carrito.dart`: `ItemCarrito { productoId, nombre,
  precioUnitario, cantidad, varianteId?, pesoKg? }`.
- `features/ventas/data/carrito_provider.dart`: `StateNotifier<List<ItemCarrito>>`
  con `agregar / quitar / incrementar / decrementar / vaciar`.
- Tocar un producto ya presente **incrementa la cantidad**, no duplica la fila.

### 3.2 UI de Cobrar
Estructura (Lote B · P0), de arriba a abajo:
1. Título "Cobrar" + pastillas de tasa **BCV / Paralelo**.
2. Aviso offline (F1.4).
3. Segmented **Venta | Cotización** (la cotización llega en 3.6; en esta subfase
   se deja el control deshabilitado o se omite).
4. Pastillas de método de pago, **leídas de `MetodoPagoConfig`** (solo las
   activas) + pastilla **Fiado** siempre al final, en ámbar `#F2A93C`.
5. Tarjeta total navy: "TOTAL A COBRAR", monto grande, Bs + nombre de tasa,
   pie con "N productos en el carrito" (o "Carrito vacío — toca un producto").
6. **Selector de modo: `Productos` | `Monto libre`.**
   - *Productos*: buscador + grid de 2 columnas (nombre + precio verde) con
     scroll, alimentado por `productosProvider`. Lista de ítems agregados encima
     (máx. ~68 px de alto, scrollable, tap = quitar).
   - *Monto libre*: el teclado numérico actual, intacto.
7. CTA 56 px, radio 15, sombra `0 12px 24px rgba(14,159,110,.35)`.
   Etiqueta dinámica: `Cobrar $X` / `Anotar fiado $X` / `Enviar cotización $X`.

**No romper el modo actual.** El teclado numérico se conserva tal cual; el
carrito es aditivo. Si el negocio no tiene productos cargados, abrir en
"Monto libre" por defecto.

### 3.3 Descuento de inventario
- Al cobrar en modo carrito, construir un `ItemVenta` por cada `ItemCarrito` con
  su `productoId` real.
- Validar stock **antes** de escribir: si algún producto tiene
  `bloquearAlAgotarse == true` y la cantidad pedida supera el stock, bloquear el
  cobro y señalar la fila. Si es `false`, permitir (queda en negativo, es
  intencional en bodegas).
- El descuento debe ir en la **misma transacción** que la venta (revisar que
  `registrarVenta` ya lo haga; si usa batch, migrar a `runTransaction`).
- Productos con `vendidoPorPeso`: al tocarlos, pedir kilos antes de agregar.
- Productos con variantes: hoja inferior para elegir variante; se descuenta de
  la variante, no del total.

### 3.4 Precio de oferta
- Si `enOferta`, el carrito usa `precio` y muestra `precioAnterior` tachado
  en la ficha del grid.

### 3.5 Fiado como método de pago
- Al elegir "Fiado" aparece la **tarjeta de cliente** (avatar con iniciales,
  nombre, teléfono, "se anota a su cuenta", botón "Cambiar").
- Selector de cliente reutilizando `fiado_repository`.
- Al confirmar: registra la `Venta` con `metodoPago: fiado` **y** un movimiento
  `tipo: fiado` en `clientes/{id}/movimientos`, incrementando `saldoUSD`.
  Ambas escrituras en la misma transacción.
- El overlay de confirmación cambia a "¡Fiado anotado!" + "$X a la cuenta de N".

### 3.6 Cotización
- Pestaña "Cotización": no toca inventario ni crea `Venta`.
- Requiere cliente (misma tarjeta que fiado).
- Al enviar: arma el mensaje ("Hola N 👋 aquí tu cotización de {negocio}: …
  válida por 24 h · tasa BCV") y lo pasa a `share_plus` / intent de WhatsApp con
  el número del cliente.
- Sin persistencia por ahora (el diseño no define colección de cotizaciones).
  **Anotar como deuda técnica** si luego se quiere historial.

### 3.7 Historial y Detalle (resto del Lote B)
- `historial_screen.dart`: encabezado "Esta semana · $X" con el total de la semana.
- `venta_detalle_screen.dart`: botones **Reimprimir** (ya hay `impresora_service`)
  y **Compartir**; envolver "Anular venta" en el bloque ámbar punteado con el
  rótulo "SOLO DUEÑO" (visible solo si `puede('anularVentas')`).

### 3.8 Tests
- Carrito: agregar/incrementar/quitar, total.
- Venta con ítems reales descuenta stock; venta de monto libre no lo toca.
- `bloquearAlAgotarse` impide cobrar sin stock.
- Venta fiada incrementa `saldoUSD` del cliente.

**Salida:** commit `Pulido F3: Cobrar híbrido (carrito + monto libre) con descuento de inventario`.

---

## FASE 4 · Productos y gastos — Lote C (~5-6 h)

### 4.1 Nuevo producto
Sobre `nuevo_producto_screen.dart`, en el orden del Lote C · P3:
- **Ganancia en vivo** junto al costo: caja `rgba(14,159,110,.1)` con
  `$2,80 · 35 %`, recalculada al teclear precio o costo. Si falta el costo,
  no inventar: mostrar guion.
- **Tipo de producto**: pastillas Simple / Con talla-color / Con serial-garantía,
  con el texto explicativo del diseño. Gobierna qué secciones se muestran.
- **"Cuando el stock llegue a 0"**: Seguir vendiendo / Bloquear venta.
- **"Ponerlo en oferta"**: switch + Precio anterior (tachado) + Descuento
  (ámbar, `−16 %`, editable en % o en monto).
- **Garantía** (solo rubro Electrónica): Sin garantía / 30 días / 90 días.
- Variantes: extender `Rubro.electronica.config` con `usaVariantes: true`
  (el diseño lista "Ropa · Belleza · Quincallería · Electrónica").
- Vencimiento: el diseño lo amplía a "Belleza · Alimentos"; sin rubro
  "Alimentos" en el enum, activarlo también para `bodega`.
- **Receta / insumos**: sigue siendo placeholder — requiere la colección
  `insumos` completa. **Se pospone a la Fase 8**, dejar el placeholder actual.

### 4.2 Productos
- Botón punteado **"Contar inventario real"** bajo el buscador → pantalla de
  arqueo de stock (contar físico vs. sistema, ajustar). Reutilizar el patrón de
  `arqueo_caja_screen.dart`.

### 4.3 Gastos
- FAB circular 56 px navy `#1E2A38` abajo-derecha (hoy el alta se abre de otra forma).
- Registrar gasto: la ilustración del recibo con cintas adhesivas (rotado −2,5°)
  y el microcopy en Caveat "toca para tomar la foto".

**Salida:** commit `Pulido F4: campos de producto (oferta, garantía, bloqueo), arqueo de inventario y gastos`.

---

## FASE 5 · Ajustes, permisos y legal — Lote E (~6-7 h)

### 5.1 Elegir banco (pantalla nueva)
- Ruta nueva + pantalla con buscador y los 26 bancos de
  `bancos_venezuela.dart` (F2.3). Al elegir, el código se completa solo.
- Campos "Teléfono asociado" y "Cédula / RIF" en `metodos_pago_screen.dart`.
- Ese dato se muestra luego en el catálogo/estado ("Banco 0102 · V-… · 0414 …").

### 5.2 Permisos de empleado (pantalla nueva)
- Detalle del empleado: Rol (Administrador / Cajero) + los 6 toggles + acción
  destructiva "Eliminar de mi equipo".
- Aplicar `puede(...)` en los puntos de uso reales: anular venta, ver Reportes,
  editar precios, registrar gasto, cerrar caja, invitar empleados.
- **La UI no es la seguridad**: las reglas de Firestore de F2.4 son las que mandan.

### 5.3 Legal in-app
- Dos pantallas (Privacidad, Términos) con el texto del Lote E · P10-P13,
  incluido el descargo del SENIAT ("no constituyen facturas fiscales").
- Deben verse bien en claro y oscuro (el diseño trae ambas variantes).
- Sección "Legal" en Ajustes enlazando a las dos. Contrastar con `/legal/` del
  repo y con el correo ya definido (`soporte.cuentaclara@gmail.com`).

### 5.4 Historial de tasa
- Guardar snapshot diario de la tasa activa; mostrar los últimos 3 días en
  Ajustes › Tasa de cambio ("Hoy, lunes 27 · Bs 742,23").

### 5.5 Empleados
- Mostrar el rol por nombre ("Administrador" / "Cajera"), no la etiqueta
  genérica "EMPLEADO".

### 5.6 IVA
- **Se queda** (D4). Solo revisar que la fila siga coherente con el resto de
  Ajustes tras el cambio de sangrado.

**Salida:** commit `Pulido F5: banco de pago móvil, permisos por empleado, legal in-app e historial de tasa`.

---

## FASE 6 · Inicio y retención — Lote P (~5-6 h)

El Dashboard ya calca el Lote Q. Falta que **proponga acciones** según el estado
del día. Cuatro variantes de la misma pantalla:

1. **Día normal** — añadir la **racha** ("Racha de 6 días al día") y el
   **coachmark** de primer uso ("Toca «Cobrar» para anotar tu primera venta"
   + Entendido), y el comparativo "Ayer a esta hora ibas por $180,00".
2. **Día sin ventas** — "La hoja de hoy está en blanco / todavía es temprano",
   contexto histórico y bloque "Mientras esperas" con 2 sugerencias.
   Parte de esto ya vive en `sugerencia_uso.dart`: extenderlo, no duplicarlo.
3. **Con urgencias** — bloque "Antes de cerrar" con la caja sin cuadrar
   ("Llevas 3 días sin cerrar. Se acumulan $712,50"), fiados vencidos,
   productos en cero, deuda a proveedor.
4. **Tasa vencida / sin internet** — "La tasa tiene 2 días… puedes perder plata"
   + acciones **Escribir la tasa** (a mano) y **Usar esa**.

Además: pantalla de **Notificaciones** con racha, pedidos entrantes del Estado y
vencimientos a proveedor (extender `notificaciones_screen.dart`).

**Riesgo:** el Dashboard es "sin scroll" por diseño. Cada bloque nuevo compite
por altura — respetar el reparto `flex` y **no** añadir scroll. Cuando entra el
bloque de urgencias, algo tiene que ceder: definir prioridad explícita.

**Salida:** commit `Pulido F6: estados de Inicio, racha y coachmark`.

---

## FASE 7 · Crecimiento — D, G, H, N, O (~7-8 h)

- **Fiados (G):** recordatorio automático — "María González lleva 18 días
  vencida / Recordatorio listo para enviar" + botón Enviar (mensaje editable
  antes de salir).
- **Proveedores (H):** **Pedido de reabastecimiento por WhatsApp** — la lista se
  arma sola con los productos de stock bajo ("Harina PAN — 6 unidades…").
- **Reportes (N):** **Balance acumulado desde que empezaste** y el comparativo
  "▲ 12 % vs junio". En Exportar: selector **Incluir** (Ventas / Gastos /
  Fiados y abonos) y período **Personalizado**.
- **Multi-negocio (N · P4):** pantalla **Mis negocios** — sucursales propias,
  negocios donde "te invitaron", "+ Agregar otra sucursal", y el chevron del
  header del Dashboard que la abre.
- **Estado (O):** buscador "Buscar en mi mercancía…", chip "Más vendidos",
  toggles **Mostrar Bs / Mi teléfono / Delivery**, variante **oscura** de la
  imagen exportada, y pantalla de **resultados tras publicar**.
- **Planes (D):** beneficios Plus nuevos ("Recordatorios de fiado automáticos",
  "Pedido a proveedor con 1 toque"), límites del plan gratis explícitos
  ("1 empleado", "Sin respaldo en la nube") y el microcopy corregido de cobro
  por Google Play.
- **Login (A):** **Entrar con huella o rostro** (`local_auth`), sobre la sesión
  ya persistida.

**Nota:** en las imágenes exportadas de WhatsApp (Lote O) la raya coral **sí se
conserva** — es el único sitio, junto con los iconos de libreta, donde sobrevive.
No aplicarles el cambio de sangrado de F1.

**Salida:** un commit por bloque.

---

## FASE 8 · Diferido — requiere decisión de negocio o backend

No empezar sin confirmación explícita:

- **Respaldo y datos**: exportar el negocio en `.zip`, restaurar desde respaldo,
  respaldo cifrado en la nube (es beneficio Plus según el Lote D).
- **Historial de auditoría**: quién hizo qué. Necesita colección nueva y decidir
  retención.
- **Receta / insumos** (Lote C): colección `insumos` + descuento al vender.
- **Pedidos automáticos por WhatsApp** (beneficio #1 del Plus): es un bot con
  webhook y parser, no una pantalla. O se construye el servicio o se ajusta el
  pitch del Plus antes de publicar en Play Store.
- **Login por OTP de WhatsApp**: Firebase Auth no lo soporta; requiere proveedor
  externo. Si no hay presupuesto, el copy debe decir SMS.

---

## Resumen de esfuerzo

| Fase | Contenido | Estimación |
|---|---|---|
| 0 | Preparación | 0,5 h |
| 1 | Tokens globales | 3-4 h |
| 2 | Modelo y reglas | 4-5 h |
| 3 | **Cobrar híbrido** | 8-10 h |
| 4 | Productos y gastos | 5-6 h |
| 5 | Ajustes, permisos, legal | 6-7 h |
| 6 | Inicio y retención | 5-6 h |
| 7 | Crecimiento | 7-8 h |
| | **Total 0-7** | **~40-47 h** |
| 8 | Diferido | sin estimar |

Si hay que priorizar por impacto en el usuario: **1 → 3 → 6**. La fase 1 es la
que más cambia la sensación de la app por hora invertida; la 3 es la que cambia
el producto; la 6 es la que lo hace volver.
