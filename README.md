# Cuenta Clara

Gestión para pequeños negocios (pymes) en Venezuela — inventario, ventas, gastos, reportes y catálogo compartible. Una sola app para Android e iOS.

## Qué hace

- **Cobrar** — calculadora tipo carrito, descuenta inventario e insumos automáticamente, muestra total en USD y Bs (tasa BCV en tiempo real).
- **Inventario** — productos con foto, escáner de código de barras, variantes (talla/tono), alertas de stock bajo, vencimientos (belleza) y recetas de insumos (comida rápida).
- **Ventas** — historial con detalle, anulación (nunca se borra: se marca y restituye inventario).
- **Gastos** — categorías y subcategorías, foto de recibo, edición y borrado lógico auditables.
- **Fiados y proveedores** — clientes con saldo, libro mayor de movimientos que nunca se edita ni borra.
- **Cierre de caja** — arqueo del día con método de pago, efectivo esperado vs contado y descuadre.
- **Reportes** — gráficos por día, comparativo semana/mes/año, top productos.
- **Catálogo** — compartible por WhatsApp y como estado (formato 9:16) con marca de agua en el plan gratis.
- **Multi-negocio** — cambio entre negocios, invitación de empleados con roles (dueño/empleado).
- **Avisos de tasa BCV** — notificaciones push en franjas fijas del día (8 am, 12 pm, 3 pm) y resumen diario de ventas.

## Stack

| Capa | Tecnología |
|---|---|
| App | Flutter (Dart) |
| Backend | Firebase — Auth, Firestore, Cloud Messaging, Storage |
| Worker | Cloudflare Workers (cron + KV) — avisos de tasa, lectura de fotos con IA, Cloudinary |
| IA | Gemini (leer libreta de fiados, recibo de gasto, etiqueta de producto desde foto) |
| Pagos | In-app purchase (Google Play / App Store) — nunca se procesan tarjetas |

## Modelo de negocio

Freemium: plan gratis (1 negocio, 50 productos, historial 30 días) + Premium $5/mes (negocios ilimitados, reportes avanzados, exportación, multi-moneda, sin marca de agua).

## Estructura

```
lib/
  core/           tema, tokens de marca, utilidades
  features/       cada módulo (productos, ventas, gastos, fiados, ...)
  shared/         widgets y utilidades compartidas
  app/            router y arranque
worker/           Cloudflare Worker (avisos, IA, Cloudinary)
herramientas/     assets de marca y generadores
legal/            política de privacidad y términos de uso
```

## Cómo correr

```bash
flutter pub get
flutter run
```

La app requiere un proyecto Firebase configurado (`firebase_options.dart`, `google-services.json`). El Worker se despliega con:

```bash
cd worker
wrangler deploy
```

Los secretos del Worker (cuenta de servicio de Firebase, claves de Gemini y Cloudinary) se cargan con `wrangler secret put`, nunca en el repositorio.

## Documentación

- `CLAUDE.md` — contexto completo del proyecto: producto, modelo de datos, reglas de negocio y arquitectura.
- `NOTAS.md` — decisiones de diseño.
- `legal/` — documentos legales de la app.

---

Desarrollado por Mitzukyhs Dev — Venezuela.