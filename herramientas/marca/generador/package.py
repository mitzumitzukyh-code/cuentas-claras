# -*- coding: utf-8 -*-
import os, base64
from tokens import C, NAV, ACCIONES, CATEGORIAS
from brand import TAGLINE

OUT = "/home/claude/out/cuentas-claras-assets"
SVG = os.path.join(OUT, "svg")


def rel_svgs():
    out = []
    for root, _, files in os.walk(SVG):
        for f in sorted(files):
            if f.endswith(".svg"):
                out.append(os.path.relpath(os.path.join(root, f), SVG))
    return sorted(out)


ALL = rel_svgs()

# ─────────────────────────────────────────── README
readme = f"""# Assets — Cuentas Claras

Paquete de identidad visual generado a partir del sistema de diseño **libreta de contabilidad**.
Todo es vectorial y original: no hay imágenes generadas por IA ni recursos de terceros.

---

## Tokens de color

| Token | Hex | Uso |
|---|---|---|
| Esmeralda | `{C['esmeralda']}` | Color primario, acciones, línea de tendencia |
| Azul noche | `{C['azul_noche']}` | Texto, trazo de íconos, fondo del app icon |
| Blanco hueso | `{C['blanco_hueso']}` | Fondo de superficies |
| Ámbar | `{C['ambar']}` | Alertas y avisos (nunca rojo) |
| Gris piedra | `{C['gris_piedra']}` | Texto secundario, estados inactivos |
| Coral | `{C['coral']}` | Línea de margen de la libreta |
| Papel | `{C['papel']}` | Fondo de la hoja |
| Raya | `{C['raya']}` | Renglones de la libreta |
| Degradado | `{C['grad_a']} → {C['grad_b']} → {C['grad_c']}` | Solo Splash y Planes |

> **Ojo con el coral.** Ese hex lo derivé yo para la línea de margen porque no estaba
> fijado en el sistema. Si ya tienes un valor definido, cámbialo en `tokens.py` y
> vuelve a correr el generador.

> **Ojo con el ámbar en el isotipo.** El punto de la cima de la línea de tendencia usa
> ámbar, que en la app significa alerta. En el logo es un acento de marca, no un estado.
> Si prefieres no mezclar semánticas, cámbialo a `{C['esmeralda_osc']}`.

---

## Estructura

```
cuentas-claras-assets/
├── svg/
│   ├── marca/           logotipos, isotipo, app icon, splash
│   ├── iconos/
│   │   ├── nav/         {len(NAV)} íconos de navegación
│   │   ├── acciones/    {len(ACCIONES)} íconos de acción
│   │   └── categorias/  {len(CATEGORIAS)} íconos de rubro de negocio
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
D:\\Cuentas-claras-App\\assets\\
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
class CCIcon extends StatelessWidget {{
  const CCIcon(this.asset, {{super.key, this.size = 24, this.color}});
  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {{
    final c = color ?? IconTheme.of(context).color ?? CCColors.azulNoche;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }}
}}
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
  adaptive_icon_background: "{C['azul_noche']}"
  adaptive_icon_foreground: "assets/png/app-icon/adaptive-foreground-432.png"
  remove_alpha_ios: true
```

### 7. Splash

Con `flutter_native_splash`:

```yaml
flutter_native_splash:
  color: "{C['grad_b']}"
  image: assets/png/splash/splash-logo-2x.png
  android_12:
    image: assets/png/splash/splash-logo-2x.png
    color: "{C['grad_b']}"
```

El degradado completo (`splash-1080x1920.png`) sirve para la pantalla de bienvenida
dentro de la app, no para el splash nativo — Android 12+ no admite degradados ahí.

---

## Tipografías

- **Inter** — texto de interfaz y logotipo. SemiBold para el wordmark.
- **Caveat** — solo tagline y momentos celebratorios. Nunca en cifras.

En los SVG de marca el texto ya está convertido a trazos, así que los logos se ven
igual en cualquier equipo sin instalar nada.

Tagline actual: *"{TAGLINE}"*

---

## Regenerar

Los assets salen de un generador en Python. Si cambias un token o un ícono:

```bash
pip install cairosvg fonttools brotli
python3 build.py     # svg + png
python3 package.py   # readme, catálogo, dart
```
"""

open(os.path.join(OUT, "README.md"), "w", encoding="utf-8").write(readme)

# ─────────────────────────────────────────── pubspec
dirs = sorted({os.path.dirname(p).replace("\\", "/") for p in ALL})
lines = ["# Pega esto bajo la clave `flutter:` de tu pubspec.yaml", "  assets:"]
for d in dirs:
    lines.append(f"    - assets/svg/{d}/")
for dens in ("1x", "2x", "3x"):
    for d in dirs:
        lines.append(f"    - assets/png/{dens}/{d}/")
    for tag in ("esmeralda", "blanco"):
        for g in ("nav", "acciones", "categorias"):
            lines.append(f"    - assets/png/{dens}/iconos-{tag}/{g}/")
lines += [
    "    - assets/png/app-icon/",
    "    - assets/png/splash/",
    "",
    "# A propósito NO se declaran estas carpetas: no se cargan en runtime y",
    "# meterlas aquí solo infla el tamaño del APK.",
    "#   png/notificacion  -> va a android/app/src/main/res/drawable-*/",
    "#   png/tienda        -> se sube a la consola de Google Play",
    "#   png/web           -> va a la carpeta web/ del proyecto Flutter",
]
open(os.path.join(OUT, "pubspec-assets.yaml"), "w", encoding="utf-8").write("\n".join(lines) + "\n")


# ─────────────────────────────────────────── app_assets.dart
def camel(*parts):
    s = ""
    for i, p in enumerate(parts):
        for j, chunk in enumerate(p.replace("_", "-").split("-")):
            if i == 0 and j == 0:
                s += chunk
            else:
                s += chunk.capitalize()
    return s


PREFIX = {"nav": "nav", "acciones": "acc", "categorias": "cat"}
dart = ["// GENERADO AUTOMÁTICAMENTE — no editar a mano.",
        "// Rutas de assets y tokens de color de Cuentas Claras.", "",
        "import 'package:flutter/material.dart';", "",
        "abstract final class AppAssets {", "  static const _svg = 'assets/svg';", ""]

dart.append("  // ── Marca")
for p in ALL:
    if p.startswith("marca/"):
        name = camel(os.path.basename(p)[:-4])
        dart.append(f"  static const {name} = '$_svg/{p}';")

for grupo, pref in PREFIX.items():
    dart.append("")
    dart.append(f"  // ── Íconos · {grupo}")
    for p in ALL:
        if p.startswith(f"iconos/{grupo}/"):
            name = camel(pref, os.path.basename(p)[:-4])
            dart.append(f"  static const {name} = '$_svg/{p}';")

for grupo, pref in (("texturas", "tex"), ("ilustraciones", "ilus"), ("ilustraciones-dark", "ilus-dark")):
    dart.append("")
    dart.append(f"  // ── {grupo.capitalize()}")
    for p in ALL:
        if p.startswith(grupo + "/"):
            name = camel(pref, os.path.basename(p)[:-4])
            dart.append(f"  static const {name} = '$_svg/{p}';")

dart += ["}", "", "/// Tokens de color de la marca.", "abstract final class CCColors {"]
for k, v in [("esmeralda", C["esmeralda"]), ("esmeraldaOscuro", C["esmeralda_osc"]),
             ("azulNoche", C["azul_noche"]), ("blancoHueso", C["blanco_hueso"]),
             ("ambar", C["ambar"]), ("grisPiedra", C["gris_piedra"]),
             ("coral", C["coral"]), ("papel", C["papel"]), ("raya", C["raya"])]:
    dart.append(f"  static const {k} = Color(0xFF{v[1:].upper()});")
dart += [
    "",
    "  /// Solo para Splash y Planes.",
    "  static const degradadoMarca = LinearGradient(",
    "    begin: Alignment.topCenter,",
    "    end: Alignment.bottomCenter,",
    f"    colors: [Color(0xFF{C['grad_a'][1:].upper()}), Color(0xFF{C['grad_b'][1:].upper()}), Color(0xFF{C['grad_c'][1:].upper()})],",
    "    stops: [0.0, 0.52, 1.0],",
    "  );",
    "}",
]
open(os.path.join(OUT, "app_assets.dart"), "w", encoding="utf-8").write("\n".join(dart) + "\n")

# ─────────────────────────────────────────── catálogo HTML
def inline(p):
    return base64.b64encode(open(os.path.join(SVG, p), "rb").read()).decode()


def tiles(paths, size=48, dark=False):
    out = []
    for p in paths:
        bg = "tile dark" if dark else "tile"
        out.append(f'<figure class="{bg}"><img src="data:image/svg+xml;base64,{inline(p)}" '
                   f'style="width:{size}px" alt=""><figcaption>{os.path.basename(p)[:-4]}</figcaption></figure>')
    return "\n".join(out)


sec = lambda t, s, b: f'<section><h2>{t}</h2><p class="sub">{s}</p><div class="grid">{b}</div></section>'

marca_grid = "\n".join(
    f'<figure class="tile {"dark" if "reverse" in p or "splash" in p else ""} wide">'
    f'<img src="data:image/svg+xml;base64,{inline(p)}" alt="">'
    f'<figcaption>{os.path.basename(p)[:-4]}</figcaption></figure>'
    for p in ALL if p.startswith("marca/") and "adaptive" not in p
    and "monochrome" not in p and "feature" not in p and not p.startswith("marca/plan-"))

tienda_grid = "\n".join(
    f'<figure class="tile dark wide"><img src="data:image/svg+xml;base64,{inline(p)}" alt="">'
    f'<figcaption>{os.path.basename(p)[:-4]}</figcaption></figure>'
    for p in ALL if "feature" in p or "monochrome" in p or "silueta" in p or p.startswith("marca/plan-"))

html = f"""<!doctype html><html lang="es"><meta charset="utf-8">
<title>Cuentas Claras · Catálogo de assets</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{{box-sizing:border-box}}
body{{margin:0;background:{C['blanco_hueso']};color:{C['azul_noche']};
 font:15px/1.55 'Inter',system-ui,-apple-system,sans-serif}}
header{{padding:56px 40px 40px;border-bottom:1px solid {C['raya']};
 background:linear-gradient(180deg,#fff,{C['blanco_hueso']})}}
header h1{{margin:0 0 6px;font-size:34px;letter-spacing:-.02em}}
header p{{margin:0;color:{C['gris_piedra']}}}
main{{padding:8px 40px 80px;max-width:1180px;margin:0 auto}}
section{{margin:48px 0}}
h2{{font-size:19px;margin:0 0 2px;letter-spacing:-.01em}}
.sub{{margin:0 0 20px;color:{C['gris_piedra']};font-size:13.5px}}
.grid{{display:flex;flex-wrap:wrap;gap:12px}}
.tile{{margin:0;background:#fff;border:1px solid {C['raya']};border-radius:12px;
 padding:16px 10px 10px;width:118px;display:flex;flex-direction:column;
 align-items:center;justify-content:flex-end;gap:12px;min-height:112px}}
.tile.wide{{width:auto;min-width:180px;padding:22px 24px 12px}}
.tile.dark{{background:{C['azul_noche']};border-color:{C['azul_noche']}}}
.tile.dark figcaption{{color:#9FB2AE}}
.tile img{{display:block;max-width:100%}}
figcaption{{font-size:10.5px;color:{C['gris_piedra']};text-align:center;
 word-break:break-word;line-height:1.3}}
.swatches{{display:flex;flex-wrap:wrap;gap:10px}}
.sw{{width:118px;border:1px solid {C['raya']};border-radius:12px;overflow:hidden;background:#fff}}
.sw div{{height:56px}}
.sw span{{display:block;padding:7px 9px;font-size:10.5px;color:{C['gris_piedra']}}}
.sw b{{display:block;color:{C['azul_noche']};font-size:11.5px}}
</style>
<header>
  <h1>Cuentas Claras</h1>
  <p>Catálogo de assets · {len(ALL)} vectores · sistema libreta de contabilidad</p>
</header>
<main>
{sec("Marca", "Isotipo, logotipos, app icon y splash. Texto convertido a trazos.", marca_grid)}
<section><h2>Color</h2><p class="sub">Tokens del sistema.</p><div class="swatches">
{"".join(f'<div class="sw"><div style="background:{v}"></div><span><b>{k}</b>{v}</span></div>' for k, v in [("Esmeralda", C['esmeralda']), ("Azul noche", C['azul_noche']), ("Blanco hueso", C['blanco_hueso']), ("Ámbar", C['ambar']), ("Gris piedra", C['gris_piedra']), ("Coral", C['coral']), ("Papel", C['papel']), ("Raya", C['raya'])])}
</div></section>
{sec("Publicación y sistema", "Feature graphic de Play, ícono de notificación, themed icon e insignias de plan.", tienda_grid)}
{sec("Íconos · Navegación", "Para la bubble navigation con el pill esmeralda.", tiles([p for p in ALL if p.startswith("iconos/nav/")], 30))}
{sec("Íconos · Acciones", "Trazo de 1.7 en grilla de 24. Se tiñen con ColorFilter.", tiles([p for p in ALL if p.startswith("iconos/acciones/")], 30))}
{sec("Íconos · Categorías", "Rubros de negocio del comercio venezolano.", tiles([p for p in ALL if p.startswith("iconos/categorias/")], 30))}
{sec("Texturas", "Piezas del sistema libreta, pensadas para tilear.", tiles([p for p in ALL if p.startswith("texturas/")], 150))}
{sec("Onboarding", "Cuatro escenas para la bienvenida.", tiles([p for p in ALL if p.startswith("ilustraciones/onb-")], 250))}
{sec("Estados vacíos", "Cada pantalla vacía es una invitación a actuar, no un mensaje de error.", tiles([p for p in ALL if p.startswith("ilustraciones/") and not p.startswith("ilustraciones/onb-")], 190))}
{sec("Modo oscuro", "Las mismas ilustraciones con superficies invertidas. Los elementos sobre esmeralda o ámbar se mantienen claros.", tiles(sorted(p for p in ALL if p.startswith("ilustraciones-dark/")), 190, dark=True))}
</main></html>"""
open(os.path.join(OUT, "catalogo.html"), "w", encoding="utf-8").write(html)

print("README, pubspec-assets.yaml, app_assets.dart y catalogo.html listos")
