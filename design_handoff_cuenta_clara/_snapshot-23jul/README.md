# Handoff a Claude Code — Cuenta Clara

App móvil (Android, gama media) para dueños de PYMEs en Venezuela (bodegas, abastos, pastelerías): ventas, inventario, gastos, fiados, cierre de caja y reportes. Identidad: **libreta de contabilidad** digital (espiral, margen coral, renglón, tapa de cuero vinotinto→verde solo en marca).

> **Estos `.dc.html` son referencia visual y de comportamiento, NO código de producción.** Recrear en el entorno destino (Flutter/Material 3 recomendado) con sus componentes y patrones. Datos (montos, nombres) son de ejemplo.

---

## ⚠️ Arquitectura de navegación (leer primero)

Los prototipos navegan **"hojeando" páginas** (page-turn sobre el espiral) porque son demos de un solo teléfono. **La app real NO navega así.** Regla para implementar:

- **Bottom-nav persistente** (definida en Lote K) es la navegación principal: **Inicio · Ventas · Mercancía · Reportes · Más**.
- El **"hojear"** queda SOLO para transiciones *dentro de un módulo* (p. ej. lista → detalle → volver), nunca para saltar entre secciones top-level.
- Respetar `prefers-reduce-motion`: si está activo, el hojear degrada a un fundido simple.

### Mapa de módulos → dónde vive cada pantalla
| Pestaña bottom-nav | Pantallas (lote) |
|---|---|
| **Inicio** | Dashboard con saludo, tasa BCV/Binance, ventas de hoy, accesos rápidos (A5, J1) |
| **Ventas** | Cobrar, Historial, Detalle de venta, Pendientes/sincronización (B) |
| **Mercancía** | Productos, Nuevo producto, Importar inventario (C, K2) |
| **Reportes** | Reportes dinámicos (ver Cuenta Clara.dc.html) |
| **Más** | Fiados (G) · Gastos + Registrar gasto (C) · Cierre de caja + Resumen del día (H1,H2) · Cuentas por pagar + Detalle proveedor (H3,H4) · Empleados, Métodos de pago, Impresora, Ajustes, Perfil, Centro de ayuda, Eliminar cuenta (E) · Planes, Catálogo, Estado WhatsApp (D) |

Onboarding previo al shell: Splash, Login (código WhatsApp), Registro, Recuperar (A) · Selección de rubro, Tutorial, Unirse con código (F) · Migrar desde otra app (K3).

---

## Design tokens

**Color**
| Rol | Claro | Oscuro |
|---|---|---|
| Primario / éxito | `#0E9F6E` | `#16A97A` |
| Texto fuerte | `#1E2A38` | `#F2ECE0` |
| Texto muted / inactivo | `#8A9A96` | `#A79E90` |
| Fondo (papel) | `#FAF8F3` | `#1C1B18` |
| Superficie / tarjeta | `#fff` | `#262420` |
| Alerta / destructivo | ámbar `#F2A93C`, texto `#b07d1e` | igual |
| Margen de libreta | `rgba(193,80,58,.4)` | `rgba(193,80,58,.55)` |
| Renglón | `rgba(30,42,56,.09–.1)` | `rgba(242,236,224,.09)` |
| Degradado de marca | `#8C2F22 → #5A3A28 → #0E9F6E` — SOLO portada/auth/tapa/Plus |
| Post-it (tasa) | fondo `#FCEFB4`, texto `#9a7b1a` |
| Binance (acento) | `#E0A21A` |

**Regla:** rojo/vinotinto SOLO marca. Destructivo (anular, eliminar, descuadre) = ámbar, nunca rojo.

**Tipografía** — Plus Jakarta Sans (400–800) para UI y datos; Caveat 700 solo para taglines/microcopy cálido (≥18px). Montos siempre **tabular** (`font-variant-numeric: tabular-nums`). Formato es-VE: miles con punto, decimal con coma (`Bs 9.156,42`); USD con punto (`$248.50`).

**Layout / accesibilidad** (resuelto en la auditoría — aplicar en toda la app)
- Radios: tarjetas 14–18px, botones 13–15px, pills 100px, post-it 3–4px.
- **Filas de lista: mínimo 54px de alto** (subido desde 48px por comodidad táctil en gama media).
- **Toques ≥ 44px**; botón primario 52–56px, verde, sombra `0 10px 22px rgba(14,159,110,.32)`.
- Padding de pantalla 22px lateral; **54px a la izquierda** cuando hay margen coral (línea en x=38px).
- Contraste objetivo **AA (≥4.5:1)**; el renglón usa `.09–.1` (no `.06`) para ser visible a plena luz.

**Elementos de firma (libreta)**
- Espiral: tira superior de anillos — `radial-gradient(circle at center, transparent 3px, <color> 3px 5.5px, transparent 6px)`, `background-size:26px 18px; repeat-x`.
- Margen coral: línea vertical 2px en `left:38px`.
- Renglón: `border-bottom` en filas o `repeating-linear-gradient` de fondo.
- **Check dibujado a mano**: SVG path con `stroke-dasharray/dashoffset` animado (~500ms) al confirmar venta.

---

## Comportamiento / estado

- **Tasa de cambio = estado GLOBAL.** BCV (36,84) o Binance USDT (39,20) Bs/USD; se elige en Ajustes › Tasa de cambio (Lote E) o en el selector de Cobrar (Lote B). **La elección se comparte en toda la app** (Cobrar, Fiados, Reportes, Catálogo, Estado): todo equivalente en Bs = USD × tasa activa, formateado es-VE. En el prototipo se sincroniza vía `localStorage` clave `cc_rate`; en la app real = preferencia global persistida.
- **Cobrar** → overlay con check dibujado a mano ("¡Cobrado!"), auto-cierra ~1.9s.
- **Login** passwordless: paso 1 (teléfono +58 / Google / correo) → paso 2 (6 casillas OTP + cronómetro de reenvío 45→0).
- **Fiados**: anotar fiado/abono, saldo por cliente, recordatorio por WhatsApp con mensaje prellenado (editable antes de enviar).
- **Cierre de caja**: arqueo efectivo contado vs. esperado por método; descuadre en ámbar; resumen del día enviable por WhatsApp.
- **Catálogo por WhatsApp**: se comparte como **imagen** (no enlace/web) con fotos, precios $ y Bs, formas de pago activas y marca de agua "Hecho con Cuenta Clara".
- **Offline-first**: se sigue vendiendo sin conexión; cola de pendientes que sincroniza al volver internet.
- **Búsqueda/filtros** son funcionales (Lote L): filtran en vivo, con contador y estado "sin resultados".
- **Modo oscuro** cálido (Lote J), toggle en Ajustes; mantiene espiral/renglón/margen visibles.

### Campos editables (resto son estáticos en el proto)
Marcar en la app real con estados focus/error/vacío: teléfono y OTP (Login A), monto/nota/categoría (gasto C, fiado G, abono G), nombre/precio/stock/código de barras (producto C), arqueo de efectivo (H), buscadores (C, D, E-ayuda, L), mensaje del recibo (E) y del recordatorio (G).

### Patrón de retroceso
Unificar a **uno**: flecha-atrás (chevron en cuadro gris, arriba-izquierda) para volver dentro de un módulo. Los puntos/flechas inferiores de los prototipos son navegación de demo — no van en la app.

---

## Estados cubiertos (implementar todos)
Vacíos: sin ventas, sin productos, sin fiados, búsqueda sin resultados (Lote I). Sistema: sesión expirada, sin conexión, configurando (Lote F). Todos con hoja en blanco + Caveat + animación emocional (respetando reduce-motion).

## Íconos y assets
Todos SVG de trazo (estilo lucide/feather), `stroke` según contexto, `stroke-width` 1.9–2.4. **Sin emojis.** Logo = cuaderno (anillos + margen coral) con check verde, viewBox `0 0 64 64`. Bandera VE = 3 franjas SVG. Fotos de producto/recibo = placeholders, sustituir por reales. Fuentes: Google Fonts (Plus Jakarta Sans, Caveat). `android-frame.jsx` y `support.js` son del prototipo — NO portar.

## Archivos de referencia
- `Lote A · Identidad` — Splash, Login OTP, Registro, Recuperar, Dashboard
- `Lote B · Ventas` — Cobrar (+selector tasa), Historial, Detalle, Pendientes
- `Lote C · Gastos y Productos` — Gastos, Registrar gasto, Productos, Nuevo producto
- `Lote D · Planes y Catálogo` — Planes, Catálogo, Estado WhatsApp (imagen + pagos + marca de agua)
- `Lote E · Negocio y Perfil` — Empleados, Métodos, Impresora, Ajustes (+tasa), Perfil, Eliminar, Centro de ayuda (FAQ acordeón)
- `Lote F · Onboarding y Sistema` — Rubro, Tutorial, Unirse, Notificaciones, Sesión/Conexión/Configurando
- `Lote G · Fiados` — Lista, Detalle cliente, Anotar fiado/abono, Recordatorio WhatsApp
- `Lote H · Cierre y Proveedores` — Cierre de caja, Resumen del día, Por pagar, Detalle proveedor
- `Lote I · Estados vacíos` — sin ventas/productos/fiados, búsqueda vacía, sin conexión
- `Lote J · Modo oscuro` — Inicio, Cobrar, Historial, Ajustes (dark)
- `Lote K · Navegación` — App shell con bottom-nav, Importar inventario, Migrar de otra app
- `Lote L · Búsqueda y Datos` — Búsqueda funcional, Filtros, prueba de datos reales
- `Flujo Libreta` — flujo original Ventas/Mercancía/Reportes con page-turn
- `cuenta-clara-sistema-diseno-libreta.md` — documento del sistema de diseño

> Backend pendiente (único punto abierto del checklist): auth WhatsApp OTP, base de datos, API de tasas (BCV / Binance P2P), impresora Bluetooth, SDK WhatsApp (catálogo/pedidos Plus), sincronización offline. Los nombres de archivo con "·" deben pasar a slugs sin símbolos en el repo.
