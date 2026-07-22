/**
 * Página pública de política de privacidad y términos de uso.
 *
 * Vive en el Worker (no en un hosting aparte) porque ya tiene una URL
 * pública estable y desplegada — Play Store exige que la política de
 * privacidad sea accesible en una URL pública antes de publicar la app.
 *
 * El contenido "fuente" también vive en /legal/*.md en el repo, para
 * revisarlo y versionarlo cómodo; esta es la versión que de verdad se sirve.
 */

const CONTACTO = '[correo de contacto pendiente — falta que Mitzuky lo defina]';

function pagina(titulo, cuerpo) {
  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${titulo} — Cuenta Clara</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: #F7F9F7;
    color: #1B3A4B;
    font-family: -apple-system, "Segoe UI", Roboto, Inter, Arial, sans-serif;
    line-height: 1.6;
  }
  .envoltura { max-width: 720px; margin: 0 auto; padding: 32px 20px 64px; }
  header { margin-bottom: 24px; }
  .marca { font-weight: 800; font-size: 15px; color: #0F9D82; letter-spacing: .02em; }
  h1 { font-size: 26px; margin: 6px 0 4px; }
  .fecha { color: #8A9A96; font-size: 13px; }
  nav { margin: 18px 0 32px; }
  nav a {
    color: #0F9D82; text-decoration: none; font-weight: 600; font-size: 13.5px;
  }
  nav a:not(:last-child)::after { content: "·"; margin: 0 8px; color: #8A9A96; }
  h2 { font-size: 17px; color: #1B3A4B; margin-top: 32px; }
  p, li { font-size: 14.5px; color: #1B3A4B; }
  a { color: #0F9D82; }
  ul { padding-left: 20px; }
  strong { color: #1B3A4B; }
  footer { margin-top: 48px; font-size: 12.5px; color: #8A9A96; }
</style>
</head>
<body>
  <div class="envoltura">
    <header>
      <div class="marca">CUENTA CLARA</div>
      <h1>${titulo}</h1>
      <div class="fecha">Última actualización: 20 de julio de 2026</div>
    </header>
    <nav>
      <a href="/legal/privacidad">Política de privacidad</a>
      <a href="/legal/terminos">Términos de uso</a>
      <a href="/legal/eliminar-cuenta">Eliminar mi cuenta</a>
    </nav>
    ${cuerpo}
    <footer>Mitzukyhs Dev — Venezuela · Contacto: ${CONTACTO}</footer>
  </div>
</body>
</html>`;
}

export function paginaPrivacidad() {
  return pagina(
    'Política de privacidad',
    `
    <p>Cuenta Clara es una aplicación de gestión para pequeños negocios en Venezuela (inventario, ventas, gastos y catálogo), desarrollada por <strong>Mitzukyhs Dev</strong> ("nosotros"). Esta política explica qué datos recopila la app, para qué se usan, con quién se comparten y cómo se protegen.</p>

    <h2>1. Qué datos recopilamos</h2>
    <p><strong>Cuenta.</strong> Al registrarte con correo o con tu cuenta de Google, guardamos tu correo electrónico y, si inicias sesión con Google, tu nombre y foto de perfil públicos. La autenticación la maneja Firebase Authentication (Google); nosotros nunca vemos ni guardamos tu contraseña.</p>
    <p><strong>Datos del negocio.</strong> Nombre del negocio, rubro, moneda y la configuración que elijas al crearlo.</p>
    <p><strong>Inventario.</strong> Los productos que registras: nombre, categoría, precio, cantidad y, si lo decides, una foto del producto.</p>
    <p><strong>Ventas.</strong> Cada venta que registras: los productos vendidos, el total cobrado, el método de pago que elegiste (efectivo, pago móvil, transferencia, Zelle, etc. — <strong>nunca</strong> procesamos ni guardamos datos de tarjetas) y quién la registró.</p>
    <p><strong>Gastos.</strong> Los gastos que registras: categoría, monto, descripción y, si lo decides, una foto del recibo.</p>
    <p><strong>Métodos de cobro de tu negocio.</strong> Si activas Pago Móvil, transferencia u otro método, los datos que escribes ahí (por ejemplo tu número de Pago Móvil) los guardamos para mostrárselos a tus propios clientes al cobrar — no se comparten con nadie más que contigo y con quien tú decidas mostrárselos.</p>
    <p><strong>Fotos y la IA.</strong> Cuando decides usar las funciones de inteligencia artificial (sugerir nombre de un producto, leer una libreta de inventario o leer un recibo), la foto que tomas se envía a nuestro servidor y de ahí a la API de Gemini de Google para su análisis. La IA solo <strong>sugiere</strong> — nada se guarda en tu inventario o tus gastos hasta que tú lo confirmes. El uso de esta función está sujeto además a las condiciones de Google para su API de Gemini.</p>
    <p><strong>Notificaciones.</strong> Si aceptas recibir notificaciones, guardamos un identificador técnico de tu dispositivo (token de Firebase Cloud Messaging) para poder enviarte avisos de tasa del dólar, ventas de tu equipo o stock bajo.</p>
    <p><strong>Impresora de tickets.</strong> Si conectas una impresora Bluetooth, la app se conecta a ella directamente desde tu teléfono; no enviamos esos datos a ningún servidor nuestro.</p>
    <p><strong>Lo que NO recopilamos:</strong> no accedemos a tu ubicación, no leemos tus contactos ni tus mensajes, y no vendemos tus datos a nadie.</p>

    <h2>2. Para qué usamos tus datos</h2>
    <p>Para operar la app (mostrar tu inventario, calcular tus ventas y ganancias, convertir precios a bolívares con la tasa del BCV), para las funciones que actives tú mismo (IA, notificaciones, impresión de tickets), para dar soporte cuando lo pidas, y para cumplir con los límites de tu plan (gratis o Premium).</p>

    <h2>3. Con quién compartimos datos</h2>
    <p>No vendemos tus datos. Los compartimos únicamente con los proveedores que hacen posible la app, cada uno solo con lo que necesita para su función:</p>
    <ul>
      <li><strong>Google Firebase</strong> (autenticación, base de datos, notificaciones).</li>
      <li><strong>Google Gemini API</strong> — solo las fotos que tú decides analizar con IA.</li>
      <li><strong>Cloudinary</strong> — almacenamiento de las fotos de productos y recibos.</li>
      <li><strong>Cloudflare</strong> — el servidor intermedio (Worker) que protege las claves de los servicios anteriores para que nunca viajen dentro de la app.</li>
      <li><strong>ve.dolarapi.com</strong> — fuente pública de la tasa del dólar BCV; no le enviamos ningún dato tuyo, solo la consultamos.</li>
      <li><strong>Google Play / App Store</strong> — si contratas el plan Premium, el pago lo procesa la tienda de aplicaciones; nosotros nunca vemos los datos de tu tarjeta.</li>
    </ul>

    <h2>4. Seguridad de los datos</h2>
    <ul>
      <li>Todas las comunicaciones de la app viajan cifradas (HTTPS/TLS).</li>
      <li>Cada negocio en Cuenta Clara está aislado a nivel de servidor: las reglas de nuestra base de datos exigen que exista una membresía real antes de dejar leer o escribir cualquier dato de un negocio — esto se aplica en el servidor, no solo en la pantalla.</li>
      <li>Las claves de los servicios externos (IA, almacenamiento de fotos) nunca viajan dentro de la aplicación instalada en tu teléfono: viven únicamente en nuestro servidor.</li>
      <li>Dentro de tu negocio, los empleados que invites solo ven lo que su rol permite: no ven reportes financieros ni pueden anular ventas ni eliminar productos.</li>
      <li>Una venta nunca se borra al anularla: queda marcada como anulada, para que siempre haya un registro completo de lo que pasó.</li>
    </ul>

    <h2>5. Cuánto tiempo guardamos tus datos</h2>
    <p>Mientras tu cuenta exista. Si eliminas tu negocio o tu cuenta, borramos tus datos — con una excepción: tus <strong>registros de venta ya realizados</strong> no se borran, porque la ley exige a los negocios conservar su historial de ventas por motivos fiscales y nuestras propias reglas de base de datos lo impiden a propósito (nadie, ni siquiera nosotros, puede alterar el historial después de una venta). Esos registros no contienen tu nombre ni tu correo — solo quedan asociados a un identificador técnico sin valor personal una vez que tu cuenta se elimina.</p>

    <h2>6. Eliminar tu cuenta</h2>
    <p>Puedes eliminar tu cuenta y tus datos en cualquier momento desde la app (Perfil → Cuenta → Eliminar cuenta) o, sin tener la app instalada, en <a href="/legal/eliminar-cuenta">esta página</a>. Ahí se explica en detalle qué se borra y qué se conserva (ver sección 5).</p>

    <h2>7. Tus derechos</h2>
    <p>Puedes pedirnos en cualquier momento: acceder a tus datos, corregirlos, exportarlos o eliminarlos. Escríbenos a <strong>${CONTACTO}</strong> y te respondemos.</p>

    <h2>8. Menores de edad</h2>
    <p>Cuenta Clara está pensada para dueños y empleados de pequeños negocios, no para niños. No recopilamos a sabiendas datos de menores de edad.</p>

    <h2>9. Cambios a esta política</h2>
    <p>Si cambiamos algo importante, lo avisaremos dentro de la app antes de que entre en vigencia. La fecha de "última actualización" arriba siempre refleja la versión vigente.</p>

    <h2>10. Contacto</h2>
    <p>Mitzukyhs Dev — Venezuela.<br>Correo: <strong>${CONTACTO}</strong></p>
    `,
  );
}

export function paginaTerminos() {
  return pagina(
    'Términos de uso',
    `
    <p>Al usar Cuenta Clara aceptas estos términos. Si no estás de acuerdo, no uses la app.</p>

    <h2>1. Qué es Cuenta Clara</h2>
    <p>Una app de gestión para pequeños negocios (inventario, ventas, gastos, catálogo), desarrollada por <strong>Mitzukyhs Dev</strong>, con un plan gratuito y un plan Premium de pago por suscripción.</p>

    <h2>2. Tu cuenta</h2>
    <p>Eres responsable de mantener segura tu cuenta y las credenciales con las que inicias sesión. Si creas un negocio, eres su dueño y decides quién más entra como empleado mediante invitación; el dueño es responsable de la exactitud de los datos que registra el negocio (precios, inventario, ventas).</p>

    <h2>3. Planes y pagos</h2>
    <p>El plan gratuito incluye 1 negocio, hasta 50 productos, 30 días de historial, 1 usuario y catálogo con marca de agua. El plan Premium quita esos límites y agrega funciones adicionales (reportes avanzados, exportar, multi-moneda, sin marca de agua, entre otras). Las suscripciones se cobran y gestionan a través de Google Play o App Store — nosotros no procesamos ni almacenamos datos de tu tarjeta. Puedes cancelar cuando quieras desde la tienda de aplicaciones; el acceso Premium se mantiene hasta el final del período ya pagado.</p>

    <h2>4. Uso permitido</h2>
    <p>Cuenta Clara es para gestionar tu propio negocio o el negocio de tu empleador. No está permitido usar la app para actividades ilegales, para acosar o suplantar a terceros, ni intentar vulnerar su seguridad (por ejemplo, tratando de acceder a datos de un negocio del que no eres miembro).</p>

    <h2>5. Tus datos</h2>
    <p>Los datos de tu negocio (inventario, ventas, gastos) son tuyos. Los tratamos según nuestra <a href="/legal/privacidad">política de privacidad</a>. Puedes pedir exportarlos o eliminarlos en cualquier momento.</p>

    <h2>6. Funciones con inteligencia artificial</h2>
    <p>Las sugerencias hechas con IA (nombre de producto, lectura de libreta, lectura de recibo) son solo eso: sugerencias. Nunca se guardan automáticamente — siempre las revisas y confirmas tú antes de que queden en tu inventario o tus gastos. No garantizamos que la IA acierte siempre; eres tú quien decide si una sugerencia es correcta antes de guardarla.</p>

    <h2>7. Disponibilidad del servicio</h2>
    <p>Hacemos un esfuerzo razonable para mantener la app disponible, pero no garantizamos un funcionamiento ininterrumpido: dependemos de servicios de terceros (Google Firebase, Google Gemini, Cloudinary, Cloudflare, la API pública de la tasa BCV) que están fuera de nuestro control. La app permite seguir cobrando sin conexión y sincroniza sola al recuperar señal.</p>

    <h2>8. Límites de responsabilidad</h2>
    <p>Cuenta Clara se ofrece "tal cual". En la medida permitida por la ley, no somos responsables por pérdidas de negocio, de ganancias o de datos derivadas del mal uso de la app, de fallas de los servicios de terceros de los que depende, o de decisiones de negocio que tomes con base en la información que la app te muestra (incluida cualquier sugerencia hecha por IA).</p>

    <h2>9. Cambios</h2>
    <p>Podemos actualizar estos términos; si el cambio es importante, lo avisaremos dentro de la app antes de que entre en vigencia.</p>

    <h2>10. Ley aplicable</h2>
    <p>Estos términos se rigen por las leyes de la República Bolivariana de Venezuela.</p>

    <h2>11. Contacto</h2>
    <p>Mitzukyhs Dev — Venezuela.<br>Correo: <strong>${CONTACTO}</strong></p>
    `,
  );
}

export function paginaEliminarCuenta() {
  return pagina(
    'Eliminar mi cuenta',
    `
    <p>Puedes pedir que se elimine tu cuenta de Cuenta Clara y los datos asociados a ella de dos formas:</p>

    <h2>Desde la app (más rápido)</h2>
    <p>Abre Cuenta Clara → <strong>Perfil</strong> → <strong>Cuenta</strong> → <strong>Eliminar cuenta</strong>. Confirmas ahí mismo y el borrado es inmediato.</p>

    <h2>Sin la app instalada</h2>
    <p>Escríbenos a <strong>${CONTACTO}</strong> desde el correo con el que te registraste, con el asunto "Eliminar mi cuenta". Confirmamos tu identidad y eliminamos tu cuenta y tus datos en un plazo máximo de 30 días.</p>

    <h2>Qué se elimina</h2>
    <ul>
      <li>Tu cuenta de acceso (correo/Google) a Cuenta Clara.</li>
      <li>Si eres dueño de un negocio sin más miembros: el negocio completo — productos, gastos y su configuración.</li>
      <li>Si eres empleado, o dueño con empleados activos (a quienes debes quitar primero desde Empleados): tu membresía a ese negocio.</li>
    </ul>

    <h2>Qué NO se elimina, y por qué</h2>
    <p>Los <strong>registros de venta</strong> ya realizados no se borran: la ley exige a los negocios conservar su historial de ventas por motivos fiscales, y nuestras propias reglas de base de datos lo impiden a propósito para que nadie pueda alterar el historial después de una venta. Esos registros no contienen tu nombre ni tu correo — solo quedan asociados a un identificador técnico sin valor personal una vez que tu cuenta se elimina.</p>

    <p>Ver también la <a href="/legal/privacidad">política de privacidad</a> completa.</p>
    `,
  );
}
