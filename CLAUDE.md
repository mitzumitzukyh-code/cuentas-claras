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

## 9. Primer objetivo para Claude Code

Implementar la **Fase 1** completa (pantallas 1-7) con Firebase configurado, tema de marca aplicado, y las reglas de seguridad de Firestore desde el día uno — no como algo a "agregar después".
