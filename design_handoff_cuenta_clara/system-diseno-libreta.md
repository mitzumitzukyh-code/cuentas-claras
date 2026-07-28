# Sistema de diseño — Libreta (Cuenta Clara)

## Formato de montos (doble moneda)

Nunca formatear montos a mano inline. Usar estas reglas siempre:

**formatUSD(n)** — punto decimal, sin separador de miles: `$47.20`, `$1234.50`
```js
const formatUSD = n => `$${n.toFixed(2)}`;
```

**formatBs(n)** — coma decimal, punto de miles: `Bs 177.568,80`
```js
const formatBs = n => `Bs ${n.toLocaleString('es-VE', {minimumFractionDigits:2, maximumFractionDigits:2})}`;
```

Ambos con `font-variant-numeric: tabular-nums`. El formato distinto (punto vs. coma) es intencional — evita errores de lectura al cobrar en contexto doble-moneda; no unificar.

## Color de alerta

- **Ámbar `#B07D1E`/`#B07515` texto, `#F2A93C` fondo/borde** — todo lo **reversible**: stock bajo, fiado vencido, notificaciones de vencimiento, hallazgos de auditoría, tasa BCV desactualizada.
- **Rojo `#C74A3A`** — solo lo **irreversible**: eliminar cuenta (Lote E). No usar en ningún otro contexto de alerta.

## Sangrado (margen interno)

22px estándar en todas las pantallas internas (header y contenido). No usar 54px — ese valor era para la raya coral, ya retirada de las pantallas de producto (se conserva solo en ilustraciones/iconos de libreta y en las imágenes exportadas de WhatsApp).

## Modo oscuro

Fondo `#1C1B18`, superficie/tarjeta `#262420` (incl. tarjeta hero), texto `#F2ECE0`, texto muted `#A79E90`. No usar `#1E2A38` en oscuro salvo como color de tarjeta hero en variantes que lo requieran explícitamente (ver Borde A abajo) — para texto, `#1E2A38` es el texto fuerte de modo claro; el mismo hex cumple ambas funciones en el handoff, decidir cuál aplica por contexto.

**Borde A (tarjeta hero sobre papel oscuro):** `#262420`/`#1E2A38` sobre fondo `#1C1B18` cae a ~1.1–1.2:1 de contraste de área — la tarjeta casi desaparece. Solución adoptada: borde `1.5px solid rgba(247,231,198,.32)` (cream de tagline al 32%) → ~3.26:1, cruza el umbral WCAG de 3:1 para límites de componente. Aplicar en toda tarjeta hero de modo oscuro.

## Precedencia código vs. diseño

- **El código manda** en navegación y comportamiento: rutas, flujos, lógica de estado, qué pantalla sigue a cuál.
- **El diseño manda** en color, tipografía, espaciado y tratamiento de superficie: paleta, escala tipográfica, sangrado, radios, elevación/bordes.
Ante conflicto, resolver según a cuál de las dos categorías pertenece el elemento en disputa.

## Migración pendiente: neumorfismo → plano

El sistema libreta es plano (superficies lisas, sin relieve); el código de producción actual usa neumorfismo (sombras internas/externas simulando relieve). Recomendación de diseño: eliminar el neumorfismo — compite visualmente con la textura de papel del sistema libreta. Alcance estimado: ~30 pantallas de la app en producción. No iniciar sin confirmar con negocio/ingeniería (esfuerzo de refactor, no solo estilo).

## Registro de pantallas nuevas (no existían en el código original)

- Estados vacíos: Fiados, Proveedores, Reportes, Catálogo, Búsqueda (Lote I), + Sin conexión
- Privacidad y Términos de servicio (Lote E, con y sin modo oscuro)
- Selector de banco (pago móvil / transferencia)
- Roles y permisos (empleados: qué puede ver/hacer cada rol)
- Respaldo y auditoría (registro de cambios, quién hizo qué)
- Cambiar de negocio (selector multi-negocio en header)
- Coachmark (tips guiados de primer uso sobre la UI real)
