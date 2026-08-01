# Assets — Cuentas Claras

Paquete de identidad visual generado a partir del sistema de diseño **libreta de contabilidad**.
Todo es vectorial y original: no hay imágenes generadas por IA ni recursos de terceros.

---

## Tokens de color

| Token | Hex | Uso |
|---|---|---|
| Esmeralda | `#0F9D82` | Color primario, acciones, línea de tendencia |
| Azul noche | `#1B3A4B` | Texto, trazo de íconos, fondo del app icon |
| Blanco hueso | `#F7F9F7` | Fondo de superficies |
| Ámbar | `#F2A93B` | Alertas y avisos (nunca rojo) |
| Gris piedra | `#8A9A96` | Texto secundario, estados inactivos |
| Coral | `#E8705A` | Línea de margen de la libreta |
| Papel | `#FDFCF8` | Fondo de la hoja |
| Raya | `#DCE5E2` | Renglones de la libreta |
| Degradado | `#8C2F22 → #5A3A28 → #0E9F6E` | Solo Splash y Planes |

> **Ojo con el coral.** Ese hex lo derivé yo para la línea de margen porque no estaba
> fijado en el sistema. Si ya tienes un valor definido, cámbialo en `tokens.py` y
> vuelve a correr el generador.

> **Ojo con el ámbar en el isotipo.** El punto de la cima de la línea de tendencia usa
> ámbar, que en la app significa alerta. En el logo es un acento de marca, no un estado.
> Si prefieres no mezclar semánticas, cámbialo a `#0B7A66`.

---

## Estructura

```
cuentas-claras-assets/
├── svg/
│   ├── marca/           logotipos, isotipo, app icon, splash
│   ├── iconos/
│   │   ├── nav/         6 íconos de navegación
│   │   ├── acciones/    19 íconos de acción
│   │   └── categorias/  11 íconos de rubro de negocio
│   ├── texturas/        espiral, renglones, margen, hoja completa
│   └── ilustraciones/   estados vacíos
├── png/
│   ├── 1x/ 2x/ 3x/      todo lo anterior en azul noche
│   ├── iconos-esmeralda/ iconos-blanco/   (dentro de cada densidad)
│   ├── app-icon/        48 → 1024 px + adaptive icon de Android
│   └── splash/          1080×1920, 1440×2560 y logo suelto
├── catalogo.html        abre esto para ver todo de un vistazo
├── pubspec-assets.yaml
└── app_assets.dart
```

---

## Uso en Flutter

### 1. Copia los assets

```
D:\Cuentas-claras-App\assets\
```

### 2. Declara en `pubspec.yaml`

Pega el contenido de `pubspec-assets.yaml` bajo la clave `flutter:` y agrega:

```yaml
dependencies:
  flutter_svg: ^2.0.10
```

### 3. Íconos

Los SVG de `iconos/` usan `stroke="currentColor"`. `flutter_svg` no interpreta
`currentColor`, así que el color se aplica con un `ColorFilter`:

```dart
SvgPicture.asset(
  AppAssets.navVentas,
  width: 24,
  colorFilter: const ColorFilter.mode(CCColors.esmeralda, BlendMode.srcIn),
)
```

Un wrapper te ahorra repetirlo:

```dart
class CCIcon extends StatelessWidget {
  const CCIcon(this.asset, {super.key, this.size = 24, this.color});
  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? CCColors.azulNoche;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}
```

### 4. Ilustraciones y logotipos

Van a color fijo, sin `colorFilter`:

```dart
SvgPicture.asset(AppAssets.ilusSinVentas, width: 200)
```

### 5. Texturas que se repiten

`lineas-rayadas.svg` y `patron-puntos.svg` están hechos para tilear. En Flutter,
la vía más simple es pintarlos con `CustomPainter` o usar `DecorationImage` con
el PNG y `repeat: ImageRepeat.repeat`:

```dart
Container(
  decoration: const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/png/2x/texturas/patron-puntos.png'),
      repeat: ImageRepeat.repeat,
    ),
  ),
)
```

### 6. App icon

Con `flutter_launcher_icons`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/png/app-icon/app-icon-1024.png"
  adaptive_icon_background: "#1B3A4B"
  adaptive_icon_foreground: "assets/png/app-icon/adaptive-foreground-432.png"
  remove_alpha_ios: true
```

### 7. Splash

Con `flutter_native_splash`:

```yaml
flutter_native_splash:
  color: "#5A3A28"
  image: assets/png/splash/splash-logo-2x.png
  android_12:
    image: assets/png/splash/splash-logo-2x.png
    color: "#5A3A28"
```

El degradado completo (`splash-1080x1920.png`) sirve para la pantalla de bienvenida
dentro de la app, no para el splash nativo — Android 12+ no admite degradados ahí.

---

## Tipografías

- **Inter** — texto de interfaz y logotipo. SemiBold para el wordmark.
- **Caveat** — solo tagline y momentos celebratorios. Nunca en cifras.

En los SVG de marca el texto ya está convertido a trazos, así que los logos se ven
igual en cualquier equipo sin instalar nada.

Tagline actual: *"Tu negocio al día"*

---

## Regenerar

Los assets salen de un generador en Python. Si cambias un token o un ícono:

```bash
pip install cairosvg fonttools brotli
python3 build.py     # svg + png
python3 package.py   # readme, catálogo, dart
```
