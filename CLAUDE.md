# Cuenta Clara — Project brief para Claude Code

> Documento de contexto completo. Pégalo al inicio de la sesión de Claude Code (o guárdalo como `CLAUDE.md` en la raíz del repo) para que tenga todo el contexto del proyecto desde el primer prompt.

## 1. Resumen del producto

**Nombre:** Cuenta Clara
**Qué es:** App móvil de gestión para pequeños negocios (pymes) en Venezuela — inventario, ventas, gastos, reportes y catálogo compartible.
**Plataformas:** Android e iOS (un solo código).
**Modelo de negocio:** Freemium. Plan gratis + Premium $5/mes vía Google Play / App Store.
**Desarrollador legal:** Mitzukyhs Dev — Venezuela.

## 2. Stack técnico

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase (Authentication, Firestore, Cloud Functions, Cloud Messaging, Storage)
- **Paquetes clave:**
  - `firebase_auth`, `cloud_firestore`, `firebase_messaging`
  - `mobile_scanner` (escaneo de código de barras)
  - `image_picker` (fotos de producto)
  - `share_plus` (compartir catálogo/estado)
  - `flutter_local_notifications` (recordatorios locales)
  - `sms_autofill` (autocompletar código SMS)
  - `open_mail_app` (abrir bandeja de correo directo)
  - `excel` (importar productos desde Excel)
  - `in_app_purchase` (suscripción Premium)
  - `go_router` (navegación)
- **APIs externas:**
  - `https://ve.dolarapi.com/v1/dolares/oficial` — tasa BCV, gratis, sin key. Respuesta: `{fuente, nombre, compra, venta, promedio, fechaActualizacion}`

## 3. Identidad de marca

| Token | Hex | Uso |
|---|---|---|
| Verde esmeralda (primario) | `#0F9D82` | Acciones principales, positivo |
| Azul noche | `#1B3A4B` | Textos importantes, encabezados |
| Blanco hueso (fondo) | `#F7F9F7` | Fondo general |
| Ámbar (alerta) | `#F2A93B` | Alertas de stock, avisos |
| Gris piedra | `#8A9A96` | Texto secundario |

**Ícono de marca:** cuaderno de cuentas verde con líneas de texto + insignia circular azul noche con check blanco superpuesto en la esquina inferior derecha. Assets en `/assets/icon/`.

**Tipografía:** Inter o Poppins, números tabulares.

## 4. Modelo de datos (Firestore)

```
negocios/{negocioId}
  - nombre, rubro (bodega|ropa|belleza|quincalleria|comida_rapida|otro)
  - moneda, monedaSecundaria
  - configuracion: { usaVariantes, usaFechaVencimiento, usaUnidadMedida, etiquetasVariante[] }

negocios/{negocioId}/productos/{productoId}
  - nombre, categoria, precio, cantidad, fotoUrl
  - variantes[]: { talla/tono, color, cantidad }  // solo si aplica al rubro
  - alertaEn (umbral de stock bajo)
  - fechaVencimiento  // solo belleza
  - receta[]: { insumoId, cantidadUsada }  // solo comida_rapida

negocios/{negocioId}/insumos/{insumoId}  // solo comida_rapida
  - nombre, cantidad, unidad

negocios/{negocioId}/ventas/{ventaId}
  - items[]: { productoId, nombre, cantidad, precioUnitario }
  - totalUSD, totalBs, tasaBcvUsada
  - vendidoPor (userId), fecha, anulada (bool)

negocios/{negocioId}/gastos/{gastoId}
  - categoria (mercancia|transporte|servicios|otro)
  - subcategoria (opcional)
  - descripcion, monto, fecha, fotoReciboUrl

negocios/{negocioId}/clientes/{clienteId}  // Fiados (Lote G)
  - nombre, telefono (opcional)
  - saldoUSD (denormalizado, se ajusta con FieldValue.increment al fiar/abonar)
  - actualizadoEn

negocios/{negocioId}/clientes/{clienteId}/movimientos/{movimientoId}
  - tipo (fiado|abono), montoUSD, concepto, fecha, registradoPor (userId)
  - negocioId (denormalizado, para la consulta collectionGroup del Resumen del día)
  - nunca se edita ni se borra (libro mayor)

negocios/{negocioId}/proveedores/{proveedorId}  // Cuentas por pagar (Lote H)
  - nombre, saldoUSD (denormalizado), proximoVencimiento (opcional), actualizadoEn

negocios/{negocioId}/proveedores/{proveedorId}/movimientos/{movimientoId}
  - tipo (compra|pago), montoUSD, concepto, fecha, vencimiento (solo compra), registradoPor
  - nunca se edita ni se borra (libro mayor)

negocios/{negocioId}/cierres/{cierreId}  // Cierre de caja (Lote H), id = fecha "yyyy-MM-dd"
  - ventasUSD, gastosUSD, fiadoOtorgadoUSD, abonosUSD, netoUSD
  - metodosEsperados (map método→monto), efectivoEsperado, efectivoContado, descuadreUSD
  - cerradoPor (userId), cerradaEn
  - nunca se edita ni se borra

membresias/{usuarioId}_{negocioId}
  - usuarioId, negocioId, rol (dueno|empleado)

invitaciones/{codigo}
  - negocioId, rol, expiraEn, usado
```

**Reglas de seguridad de Firestore (crítico):** cada lectura/escritura a `negocios/{negocioId}/**` debe verificar que exista un documento en `membresias` para ese `usuarioId` + `negocioId`. Ningún usuario puede leer datos de un negocio donde no tenga membresía — esto se aplica a nivel de servidor, no solo de UI.

## 5. Pantallas (18 en total) — orden de construcción sugerido

**Fase 1 — Núcleo funcional**
1. Registro/Login (teléfono con SMS autofill + fallback, correo con botón "abrir correo")
2. Verificación de código
3. Onboarding — selección de rubro (adapta configuración del negocio)
4. Inicio/Dashboard (tasa BCV, ventas del día, ganancia, alerta de stock bajo, accesos rápidos)
5. Productos (lista con "quedan X", categorías por rubro)
6. Nuevo producto (foto obligatoria para ropa/belleza/quincallería, escáner de código de barras, variantes según rubro, receta para comida rápida)
7. Cobrar cliente (calculadora tipo carrito, resta inventario/insumos automático, muestra total en USD y Bs)

**Fase 2 — Gestión y reportes**
8. Historial de ventas + Detalle de venta (con opción "anular venta", solo dueño)
9. Registrar gasto (categorías: Mercancía, Transporte con subcategorías, Servicios con subcategorías, Otro libre)
10. Reportes (gráfico de barras por día, comparativo semana/mes/año, top productos, exportar Excel/PDF en Premium)
11. Ajustes (perfil de negocio, moneda, notificaciones, ayuda, cerrar sesión)

**Fase 3 — Multi-negocio y colaboración (Premium)**
12. Invitar empleado (código de invitación, expira 24h, roles dueño/empleado)
13. Cambiar entre negocios (selector, distingue "dueño" vs "empleado" de otros negocios)
14. Pago/Suscripción ($5/mes vía in_app_purchase)

**Fase 4 — Catálogo y marketing**
15. Catálogo (grid de productos con filtros de categoría y rango de precio automático)
16. Detalle de producto del catálogo (compartir individual, publicar en estado)
17. Compartir catálogo por WhatsApp (selección de productos, marca de agua en plan gratis)
18. Publicar en estado (formato vertical 9:16, plantillas de color, marca de agua "Hecho con Cuenta Clara" en gratis)

**Fase 5 — Utilidades adicionales**
19. Importar productos desde Excel (mapeo de columnas, vista previa antes de confirmar)

## 6. Reglas de negocio importantes

- **Precios:** se capturan en USD; el monto en Bs se calcula en tiempo real con la tasa BCV cacheada localmente (actualizar 1 vez al día). Redondeo configurable de Bs (al bolívar más cercano o múltiplos de 5).
- **Roles:** dueño ve/edita todo; empleado registra ventas y ve inventario, no ve reportes financieros ni puede anular ventas ni eliminar productos.
- **Anulación de venta:** nunca se borra, se marca `anulada: true` y se restituye el inventario.
- **Plan gratis:** 1 negocio, 50 productos, historial 30 días, 1 usuario, 1 moneda, catálogo/estado CON marca de agua.
- **Plan Premium ($5/mes):** negocios y usuarios ilimitados, reportes avanzados, exportar Excel/PDF, multi-moneda, facturación PDF, control de deudas, notificaciones inteligentes, fotos por variante, SIN marca de agua.
- **Notificaciones:** locales (`flutter_local_notifications`) para recordatorios fijos (resumen diario); push (Cloud Functions + FCM) para eventos en tiempo real entre dispositivos (venta de empleado, stock bajo).
- **Pagos:** nunca se procesan ni almacenan datos de tarjeta directamente — todo vía Google Play / App Store.

## 7. Explícitamente FUERA de alcance por ahora (no implementar todavía)

- Funciones con IA (registrar venta por voz, sugerir nombre de producto desde foto, OCR de recibos, asistente conversacional, importar desde foto de libreta manuscrita)
- Verificación automática de Pago Móvil (Pabilo/VerificaPago) — pausado, no regulado oficialmente
- Integración directa con Instagram Stories (usar share genérico por ahora)

## 8. Assets disponibles

- Ícono de app (cuaderno + check) — versión con fondo y transparente
- Documentos legales base: política de privacidad y términos de uso (en `/legal`, con placeholders de correo pendientes)

## 8.b Perfiles de negocio (`lib/core/business/`)

Capa de **configuración**, no de módulos: un solo core adaptado por un objeto.
No se duplican pantallas por vertical, y ningún widget hace `switch` por rubro.

- `business_profile.dart` — `BusinessProfile`, `Vocabulary`, `ExtraField`,
  `HomeShortcut`.
- `business_presets.dart` — `Map<Rubro, BusinessProfile>` con **una entrada por
  rubro** y `perfilDe(Rubro)`. Único archivo con mapas/`switch` por rubro.
  Agregar un rubro = 1 valor en el enum + 1 entrada aquí.
- `business_profile_provider.dart` — `businessProfileProvider` (nunca async,
  nunca lanza) y azúcar `ref.perfilNegocio` / `ref.vocab`.
- El grid del Inicio dibuja `profile.atajosVisibles`, no `shortcuts`: los
  atajos con `enabled: false` son los que aún no tienen pantalla.

**De dónde sale el perfil.** Del `rubro`, 1:1, y de nada más. El onboarding hace
una sola pregunta —la de rubro, la que ya existía— y en Ajustes → Negocio →
"Tipo de negocio" se puede cambiar el rubro (solo el dueño), lo que cambia el
perfil entero. No hay campo `perfilNegocio` ni override aparte: con un preset
por rubro, un segundo eje solo sería otra cosa que mantener sincronizada.

**Reparto entre `RubroConfig` y `BusinessProfile`.** El rubro describe el
negocio hacia afuera: `id` (viaja al Worker de IA sin cambios), `etiqueta` y
`categoriasSugeridas`. Todo lo que decide **cómo se captura** un producto vive
en el perfil: `usaVariantes` + `etiquetasVariante`, `usaFechaVencimiento`,
`usaUnidadMedida`, `usaReceta`, `usaSerial`, `vendePorPeso`, `fotoObligatoria`,
unidades, vocabulario, atajos y `extraFields`.

**`extraFields` es la única fuente de qué campos extra pinta el formulario.**
`ExtraFieldsSection`
(`lib/features/productos/presentation/widgets/extra_fields_section.dart`) itera
`profile.extraFields` y no sabe qué rubro está activo. Agregar un campo a un
rubro es agregar un `ExtraField` a su preset, sin tocar la pantalla. La bandera
`usaFechaVencimiento` ya se eliminó por esto: el vencimiento es hoy un
`ExtraField` de tipo fecha. Las banderas que quedan (`usaVariantes`,
`usaReceta`, `usaSerial`, `vendePorPeso`, `fotoObligatoria`,
`usaUnidadMedida`) **no** son expresables como `ExtraField`: encienden bloques
enteros —un editor de variantes con stock por variante, una receta de insumos,
un serial con garantía—, no un campo suelto. Ante una discrepancia manda
`extraFields`.

**Los valores viven en `producto.extras`** (`Map<String, dynamic>`, clave =
`ExtraField.key`). `producto.unidad` guarda la unidad elegida entre
`profile.allowedUnits`.

**Regla del puente: todo `ExtraField` cuya clave tenga columna propia en
`Producto` necesita un puente explícito en el formulario, y no se guarda en
`extras`.** Sin eso el mismo dato queda escrito en dos sitios que pueden
discrepar, y lo que ya lee la columna —alertas, catálogo, reportes— deja de
ver lo que el usuario escribió. El puente son dos líneas en
`nuevo_producto_screen.dart`: al abrir, la columna se sube al mapa
(`_extras['clave'] = producto.columna`) para que la sección la pinte como un
campo más; al guardar, sale del mapa hacia la columna y se elimina de `extras`
(`extras: {..._extras}..remove('clave')`). Hoy el único caso es `vencimiento`
→ `producto.fechaVencimiento`. Antes de declarar un `ExtraField` nuevo, revisa
si `Producto` ya tiene esa columna: si la tiene, o pones el puente o no
declares el campo.

**Qué más consume el perfil hoy:** la barra inferior y la pantalla de
inventario usan `vocab` (título, buscador, estado vacío, CTA), y el Inicio
dibuja `GridAtajos`, que consume `atajosVisibles` menos `cobrar` (ya es el
botón héroe).

**`otro` es hoy el cajón de los negocios de servicio.** No hay rubro
`servicios`: una barbería, un taller o un salón entran por "Otro", que por eso
incluye `hora` entre sus unidades y el atajo `cotizar`. Ver `NOTAS.md`.

**`Negocio.fromDoc` ignora `negocio.configuracion` del documento** y arma el
`RubroConfig` entero desde el preset del rubro. Antes mezclaba las dos fuentes
—tres banderas del doc, el resto del preset— y el doc perdía en cuanto el
preset cambiaba, así que la mezcla solo aparentaba que el negocio guardaba una
configuración propia. `configuracion` se sigue **escribiendo** por
compatibilidad con los documentos existentes, pero nadie lo lee: lo único que
el usuario edita es el `rubro`.

## 8.c Dos reglas que se ganaron a pulso

**El `extra` de una ruta es una semilla, nunca la fuente.** `s.extra as X` en
`app_router.dart` entrega un objeto congelado en el instante de navegar. Sirve
para formularios (`AnotarMovimientoScreen`) y para datos inmutables
(`ResumenDiaScreen`, un cierre no se edita). No sirve para nada que cambie
mientras la pantalla está abierta: el detalle de un cliente mostraba "+$12,00",
"−$1,00" y un saldo pendiente de $12,00 porque la lista de movimientos era un
stream y el encabezado era la foto vieja. Los detalles de cliente y proveedor
reciben ahora un `…Inicial` y pintan lo que devuelven
`clienteFiadoPorIdProvider` / `proveedorPorIdProvider`, que se sirven del stream
de la lista —ya abierto— en vez de montar un segundo listener.

**`valueOrNull ?? const []` convierte un error en "no hay nada".** Cargando,
error y vacío son tres estados y tienen que verse distintos: un fallo de
permisos pintaba "Aún no registras gastos este mes · −$0,00" con el gasto ya
guardado. Para UI está `LibretaCargando` / `LibretaErrorCarga`
(`lib/shared/presentation/estado_carga.dart`), que muestra una frase humana y
un botón Reintentar, y manda la excepción a la consola — el `toString()` de una
excepción no se le enseña nunca al usuario. Para lógica derivada está `_leidos`
en `urgencias.dart`: una urgencia se emite sobre datos leídos o no se emite.

## 8.c.2 Gastos: mes, edición y borrado lógico

- **La pantalla se mira por mes**, no "el mes actual": `mesGastosProvider`
  guarda qué mes está abierto y `gastosDelMesElegidoProvider` lo consulta. No
  hay rango libre a propósito — un bodeguero piensa en meses.
- **Editar reusa `RegistrarGastoScreen`** pasándole el `gasto`. No hay una
  segunda pantalla de formulario.
- **Eliminar es lógico** (`eliminado` + `eliminadoEn`), nunca físico: los gastos
  alimentan reportes y hay que poder auditar qué se quitó. El filtro va en Dart
  y no en la consulta para no exigir un índice compuesto por unas decenas de
  documentos al mes.
- **`gasto.tasaUsada` se congela al registrar y no se reescribe al editar.** Si
  el detalle convirtiera con la tasa de hoy, el monto en Bs de un gasto de julio
  cambiaría cada mañana. Los gastos anteriores al campo se muestran solo en USD.
- **Lo que precarga la IA se marca** (`_SelloIA`, "según el recibo") y **la fecha
  del recibo no se aplica sola**: se ofrece en un chip. Un recibo de julio
  registrado en agosto es un gasto de agosto para el flujo de caja, y aplicarla
  en silencio hacía que el gasto desapareciera del mes que el dueño miraba.
- **Guardar fuera del mes visible lo dice** y ofrece ir: "Gasto guardado en
  julio 2026 · [Ver julio 2026]".

## 8.c.3 El error crudo no se le enseña nunca al usuario

`mensajeDeError(e, accion: 'guardar el gasto')`
(`lib/shared/utils/errores.dart`) traduce cualquier excepción a una frase que
un bodeguero entiende y manda el detalle a la consola. Distingue tres casos:
sin conexión, permiso denegado y el resto. Nadie debe volver a escribir
`Text('No se pudo X: $e')` — se vio en dispositivo un
«ClientException with SocketException: Failed host lookup…» en pantalla, y lo
único que eso le enseña a un dueño es que la app se rompió.

`conReintentos(...)` del mismo archivo hace tres intentos con esperas
crecientes (1 s, 2 s, 4 s) y **solo** reintenta lo que puede mejorar esperando:
un permiso denegado o un archivo inválido se propagan al primer intento. Lo
usan la subida de fotos a Cloudinary y las lecturas con IA.

## 8.c.4 Lectura de inventario desde foto

- **`precio` es nulable y `null` nunca es `0`.** Un producto sin precio no entra
  al carrito (`Producto.sePuedeVender`), no sale en el catálogo ni en el Estado,
  y se pinta "Sin precio" en ámbar. El `?? 0` del importador metía productos en
  \$0,00 que se podían cobrar.
- **Las cifras viajan como texto desde el Worker** y las interpreta
  `normalizarNumeroVE` (`lib/core/utils/numero_ve.dart`): `4.500,80` → 4500.80
  es determinista y no necesita un modelo. Pedírselo a Gemini devolvía a veces
  `4.5` y a veces `450080`.
- **La confianza es por campo**, no por documento: en una fila el nombre puede
  ser nítido y el precio dudoso.
- **`consolidarFilas` une por código o nombre, pero la talla y el color
  separan.** En repuestos dos filas con el mismo código son el mismo artículo;
  en ropa, el mismo nombre con distinta talla son dos variantes con su propio
  stock. La pista es si la lista trae esa columna.
- **Nada se guarda sin pasar por la tabla de revisión**, con lo dudoso en ámbar.
  Una factura de compra se detecta y se avisa: trae precios de costo.

## 8.c.5 Lectura del cuaderno de fiados

- **Cada quien anota a su manera y el lector se adapta, no al revés.** El
  prompt (`PROMPT_FIADOS`, en `worker/src/gemini.js`) describe tres formas y
  las trata como iguales: un renglón por deuda; **por bloques** —el nombre solo
  en su renglón, las prendas debajo, un único monto a la derecha unido por una
  llave `}`—; y en columnas. La versión que solo contemplaba «nombre y monto en
  la misma línea» devolvía "esto no es un cuaderno de fiados" ante el cuaderno
  de una costurera, que es el caso más común fuera de una bodega.
- **La llave `}` no es un tachado y el monto de un bloque no es un subtotal.**
  Los dos malentendidos descartan la deuda entera; están escritos como reglas
  aparte porque cada uno se vio fallar por su cuenta.
- **El número que abre un renglón de artículo es cantidad, no monto**
  («3 pantalones 6$»).
- **Un bloque con dos montos son dos renglones del mismo nombre**; la suma la
  hace `consolidarFiados` en Dart, no el modelo.
- **`esCuaderno` no manda solo:** si el modelo sacó filas con nombre, las filas
  ganan. Al revés, `esCuaderno` en true con cero filas es un resultado válido
  —una página con todo tachado— y la app lo dice distinto de "esta foto no es
  un cuaderno".
- **Lo tachado o marcado «pagó» no se copia.** Revivir una deuda saldada es el
  error más caro de esta pantalla, y por eso la regla incluye por dónde pasa la
  raya: encima es tachado, debajo es subrayado.
- **El concepto se enseña en la tabla de revisión.** Con un bloque, «Rosa E. ·
  $3» no se puede contrastar con nada; «1 suéter, 1 pantalón» sí.
- **El `$` manuscrito venezolano es una S cruzada por una raya que se estira a
  la derecha, y el modelo la leía como tachado.** Endurecer la regla de
  «tachado = pagado» hizo que una lista numerada de 15 deudas —el formato más
  fácil que existe— volviera con cero filas y un «no vimos deudas
  pendientes». Por eso el prompt trae ahora un bloque *QUÉ NO ES UN TACHADO*
  (el signo de dólar, los renglones impresos, la línea roja del margen), ancla
  el tachado al **nombre** y no a la cifra, y lleva un control explícito: si
  sale que la página entera está tachada, releer. Las dos reglas —no revivir
  una deuda pagada, no descartar una pendiente— tiran en sentidos contrarios y
  hay que escribir las dos.
- **El número al margen de una lista numerada (`① Aura 5$`) es el orden**, no
  una cantidad ni parte del nombre.
- **Cómo se prueba esto sin desplegar ni compilar:**
  `scratchpad/probar_fiados.mjs` importa `leerFiados` de `worker/src/gemini.js`
  y le pasa una foto, con la clave en `worker/.dev.vars` (ignorada por git).
  Una corrida son ~25 s contra Gemini de verdad. Los nombres difíciles bailan
  entre corridas y salen con confianza `media`; los montos, no.

## 8.d Infraestructura

Cuentas de infraestructura documentadas en `INFRA.local.md` (no versionado).

## 9. Primer objetivo para Claude Code

Implementar la **Fase 1** completa (pantallas 1-7) con Firebase configurado, tema de marca aplicado, y las reglas de seguridad de Firestore desde el día uno — no como algo a "agregar después".
