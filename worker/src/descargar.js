/**
 * Landing pública de "descargar la app" (/descargar).
 *
 * Es el link que va en la marca de agua del catálogo/estado compartido y en
 * el mensaje de WhatsApp — el canal de adquisición más barato que tiene la
 * app: cada catálogo que un dueño comparte le puede traer un dueño nuevo.
 *
 * Antes de que la app esté publicada en Play Store, este link explica qué es
 * Cuenta Clara en vez de ofrecer un APK suelto para descargar — igual que se
 * evitó dejar Cloudinary abierto sin autenticación, no tiene sentido abrir
 * otra vía de distribución fuera de Play (sin el escaneo de Play Protect, sin
 * actualizaciones automáticas, difícil de controlar si el link circula).
 * El día que se publique, esta misma URL pasa a apuntar a la ficha de Play
 * Store con un solo cambio aquí — nada de lo ya compartido deja de servir.
 */

const URL_PLAY_STORE = null; // TODO: pegar la URL de la ficha al publicar.

export function paginaDescargar() {
  const cta = URL_PLAY_STORE
    ? `<a class="boton" href="${URL_PLAY_STORE}">Descargar en Google Play</a>`
    : `<div class="boton boton--pronto">Muy pronto en Google Play</div>
       <p class="pronto">Todavía no está publicada — si alguien te compartió su catálogo hecho con Cuenta Clara, pídele la app directamente a esa persona mientras tanto.</p>`;

  return `<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cuenta Clara — gestión para tu negocio</title>
<meta name="description" content="Inventario, ventas, gastos y catálogo para pequeños negocios en Venezuela.">
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    background: linear-gradient(180deg, #0F9D82 0%, #0B7A66 100%);
    color: #F7F9F7;
    font-family: -apple-system, "Segoe UI", Roboto, Inter, Arial, sans-serif;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 32px 20px;
  }
  .tarjeta {
    max-width: 420px;
    width: 100%;
    text-align: center;
  }
  .icono {
    width: 84px;
    height: 84px;
    border-radius: 24px;
    background: #F7F9F7;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 40px;
    margin: 0 auto 20px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.2);
  }
  h1 { font-size: 26px; margin: 0 0 8px; font-weight: 800; }
  .subtitulo { font-size: 15px; color: #E3F3EF; margin: 0 0 28px; line-height: 1.5; }
  .rasgos {
    text-align: left;
    background: rgba(255,255,255,0.1);
    border-radius: 18px;
    padding: 18px 20px;
    margin-bottom: 28px;
    list-style: none;
  }
  .rasgos li { font-size: 14px; margin-bottom: 10px; display: flex; gap: 10px; }
  .rasgos li:last-child { margin-bottom: 0; }
  .boton {
    display: block;
    background: #1B3A4B;
    color: #FFFFFF;
    text-decoration: none;
    font-weight: 700;
    font-size: 15px;
    padding: 16px;
    border-radius: 16px;
    box-shadow: 0 8px 20px rgba(0,0,0,0.15);
  }
  .boton--pronto { background: rgba(27,58,75,0.55); cursor: default; }
  .pronto { font-size: 12.5px; color: #E3F3EF; margin-top: 12px; line-height: 1.5; }
  footer { margin-top: 28px; font-size: 12px; color: #CFEAE3; }
  footer a { color: #F7F9F7; }
</style>
</head>
<body>
  <div class="tarjeta">
    <div class="icono">📒</div>
    <h1>Cuenta Clara</h1>
    <p class="subtitulo">Inventario, ventas, gastos y catálogo para tu negocio — con la tasa del dólar siempre a la mano.</p>
    <ul class="rasgos">
      <li>💰 Cobra con o sin señal, en dólares y bolívares</li>
      <li>📦 Controla tu inventario y recibe alertas de stock bajo</li>
      <li>🤖 La IA te ayuda a cargar productos desde una foto</li>
      <li>📲 Comparte tu catálogo por WhatsApp en segundos</li>
    </ul>
    ${cta}
    <footer>
      Hecho por Mitzukyhs Dev — Venezuela ·
      <a href="/legal/privacidad">Privacidad</a> ·
      <a href="/legal/terminos">Términos</a>
    </footer>
  </div>
</body>
</html>`;
}
