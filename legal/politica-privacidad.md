# Política de privacidad de Cuenta Clara

Última actualización: 20 de julio de 2026.

Cuenta Clara es una aplicación de gestión para pequeños negocios en Venezuela (inventario, ventas, gastos y catálogo), desarrollada por **Mitzukyhs Dev** ("nosotros"). Esta política explica qué datos recopila la app, para qué se usan, con quién se comparten y cómo se protegen.

## 1. Qué datos recopilamos

**Cuenta.** Al registrarte con correo o con tu cuenta de Google, guardamos tu correo electrónico y, si inicias sesión con Google, tu nombre y foto de perfil públicos. La autenticación la maneja Firebase Authentication (Google); nosotros nunca vemos ni guardamos tu contraseña.

**Datos del negocio.** Nombre del negocio, rubro, moneda y la configuración que elijas al crearlo.

**Inventario.** Los productos que registras: nombre, categoría, precio, cantidad y, si lo decides, una foto del producto.

**Ventas.** Cada venta que registras: los productos vendidos, el total cobrado, el método de pago que elegiste (efectivo, pago móvil, transferencia, Zelle, etc. — **nunca** procesamos ni guardamos datos de tarjetas) y quién la registró.

**Gastos.** Los gastos que registras: categoría, monto, descripción y, si lo decides, una foto del recibo.

**Métodos de cobro de tu negocio.** Si activas Pago Móvil, transferencia u otro método, los datos que escribes ahí (por ejemplo tu número de Pago Móvil) los guardamos para mostrárselos a tus propios clientes al cobrar — no se comparten con nadie más que contigo y con quien tú decidas mostrárselos.

**Fotos y la IA.** Cuando decides usar las funciones de inteligencia artificial (sugerir nombre de un producto, leer una libreta de inventario o leer un recibo), la foto que tomas se envía a nuestro servidor y de ahí a la API de Gemini de Google para su análisis. La IA solo **sugiere** — nada se guarda en tu inventario o tus gastos hasta que tú lo confirmes. El uso de esta función está sujeto además a las condiciones de Google para su API de Gemini.

**Notificaciones.** Si aceptas recibir notificaciones, guardamos un identificador técnico de tu dispositivo (token de Firebase Cloud Messaging) para poder enviarte avisos de tasa del dólar, ventas de tu equipo o stock bajo.

**Impresora de tickets.** Si conectas una impresora Bluetooth, la app se conecta a ella directamente desde tu teléfono; no enviamos esos datos a ningún servidor nuestro.

**Lo que NO recopilamos:** no accedemos a tu ubicación, no leemos tus contactos ni tus mensajes, y no vendemos tus datos a nadie.

## 2. Para qué usamos tus datos

Para operar la app (mostrar tu inventario, calcular tus ventas y ganancias, convertir precios a bolívares con la tasa del BCV), para las funciones que actives tú mismo (IA, notificaciones, impresión de tickets), para dar soporte cuando lo pidas, y para cumplir con los límites de tu plan (gratis o Premium).

## 3. Con quién compartimos datos

No vendemos tus datos. Los compartimos únicamente con los proveedores que hacen posible la app, cada uno solo con lo que necesita para su función:

- **Google Firebase** (autenticación, base de datos, notificaciones) — EE. UU./infraestructura global de Google.
- **Google Gemini API** — solo las fotos que tú decides analizar con IA.
- **Cloudinary** — almacenamiento de las fotos de productos y recibos.
- **Cloudflare** — el servidor intermedio (Worker) que protege las claves de los servicios anteriores para que nunca viajen dentro de la app.
- **ve.dolarapi.com** — fuente pública de la tasa del dólar BCV; no le enviamos ningún dato tuyo, solo la consultamos.
- **Google Play / App Store** — si contratas el plan Premium, el pago lo procesa la tienda de aplicaciones; nosotros nunca vemos los datos de tu tarjeta.

## 4. Seguridad de los datos

- Todas las comunicaciones de la app viajan cifradas (HTTPS/TLS).
- Cada negocio en Cuenta Clara está aislado a nivel de servidor: las reglas de nuestra base de datos exigen que exista una membresía real antes de dejar leer o escribir cualquier dato de un negocio — esto se aplica en el servidor, no solo en la pantalla, así que ni siquiera manipulando la app se puede saltar.
- Las claves de los servicios externos (IA, almacenamiento de fotos) nunca viajan dentro de la aplicación instalada en tu teléfono: viven únicamente en nuestro servidor, protegidas y fuera del alcance de terceros.
- Dentro de tu negocio, los empleados que invites solo ven lo que su rol permite: no ven reportes financieros ni pueden anular ventas ni eliminar productos — eso es exclusivo del dueño.
- Una venta nunca se borra al anularla: queda marcada como anulada, para que siempre haya un registro completo de lo que pasó.

## 5. Cuánto tiempo guardamos tus datos

Mientras tu cuenta exista. Si eliminas tu negocio o tu cuenta, o nos escribes pidiéndolo, borramos tus datos salvo que la ley nos obligue a conservar algún registro (por ejemplo, por motivos fiscales).

## 6. Tus derechos

Puedes pedirnos en cualquier momento: acceder a tus datos, corregirlos, exportarlos o eliminarlos. Escríbenos a **[correo de contacto pendiente]** y te respondemos.

## 7. Menores de edad

Cuenta Clara está pensada para dueños y empleados de pequeños negocios, no para niños. No recopilamos a sabiendas datos de menores de edad.

## 8. Cambios a esta política

Si cambiamos algo importante, lo avisaremos dentro de la app antes de que entre en vigencia. La fecha de "última actualización" arriba siempre refleja la versión vigente.

## 9. Contacto

Mitzukyhs Dev — Venezuela.
Correo: **[correo de contacto pendiente]**
