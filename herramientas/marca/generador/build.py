# -*- coding: utf-8 -*-
import os, re, shutil
import cairosvg
import tokens as T
import brand as B
from tokens import C

OUT = "/home/claude/out/cuentas-claras-assets"
SVG = os.path.join(OUT, "svg")
PNG = os.path.join(OUT, "png")

written = []          # (ruta_svg_relativa, vb_w, vb_h)


def w(relpath, content, vb=None):
    p = os.path.join(SVG, relpath)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(content)
    if vb is None:
        m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', content)
        vb = (float(m.group(1)), float(m.group(2))) if m else (64, 64)
    written.append((relpath, vb[0], vb[1]))
    return p


shutil.rmtree(OUT, ignore_errors=True)

# ─────────────────────────────────────────────── ICONOS
for grupo, data in (("nav", T.NAV), ("acciones", T.ACCIONES), ("categorias", T.CATEGORIAS)):
    for name, paths in data.items():
        w(f"iconos/{grupo}/{name}.svg", T.stroke_icon(paths))

# ─────────────────────────────────────────────── MARCA
w("marca/isotipo.svg", B.isotipo_svg())
w("marca/isotipo-reverse.svg", B.isotipo_reverse_svg())
w("marca/isotipo-mono-azul.svg", B.isotipo_mono_svg(C["azul_noche"]))
w("marca/isotipo-mono-blanco.svg", B.isotipo_mono_svg(C["blanco_hueso"]))
w("marca/logo-horizontal.svg", B.logo_horizontal())
w("marca/logo-horizontal-tagline.svg", B.logo_horizontal(tag=B.TAGLINE))
w("marca/logo-horizontal-reverse.svg",
  B.logo_horizontal(c1=C["blanco_hueso"], c2="#8FE3D0"))
w("marca/logo-vertical.svg", B.logo_vertical(tag=B.TAGLINE))
w("marca/logo-vertical-reverse.svg",
  B.logo_vertical(c1=C["blanco_hueso"], c2="#8FE3D0", tagcolor="#B8C6C2",
                  tag=B.TAGLINE))
w("marca/wordmark.svg", B.wordmark_solo())
w("marca/wordmark-reverse.svg", B.wordmark_solo(c1=C["blanco_hueso"], c2="#8FE3D0"))
w("marca/app-icon.svg", B.app_icon())
w("marca/app-icon-cuadrado.svg", B.app_icon(full_bleed=False))
w("marca/app-icon-adaptive-foreground.svg", B.app_icon(adaptive=True))
w("marca/app-icon-adaptive-background.svg", B.app_icon_bg())
w("marca/splash.svg", B.splash())

# ─────────────────────────────────────────────── TEXTURAS
w("texturas/espiral-horizontal.svg", B.espiral_horizontal())
w("texturas/lineas-rayadas.svg", B.lineas_rayadas())
w("texturas/margen-coral.svg", B.margen_coral())
w("texturas/patron-puntos.svg", B.patron_puntos())
w("texturas/hoja-libreta.svg", B.hoja_libreta())

# ─────────────────────────────────────────────── ILUSTRACIONES
for name, fn in B.ILUSTRACIONES.items():
    w(f"ilustraciones/{name}.svg", fn())

print(f"SVG escritos: {len(written)}")

# ─────────────────────────────────────────────── EXPORT PNG
SKIP_MULTI = {"marca/splash.svg", "marca/app-icon.svg", "marca/app-icon-cuadrado.svg",
              "marca/app-icon-adaptive-foreground.svg", "marca/app-icon-adaptive-background.svg"}

def render(src, dst, ow=None, oh=None, replace_color=None):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    data = open(src, encoding="utf-8").read()
    if replace_color:
        data = data.replace('stroke="currentColor"', f'stroke="{replace_color}"')
        data = data.replace('fill="currentColor"', f'fill="{replace_color}"')
    cairosvg.svg2png(bytestring=data.encode(), write_to=dst,
                     output_width=ow, output_height=oh, background_color=None)

n = 0
for rel, vw, vh in written:
    src = os.path.join(SVG, rel)
    if rel in SKIP_MULTI:
        continue
    tint = C["azul_noche"] if rel.startswith("iconos/") else None
    for mult, folder in ((1, "1x"), (2, "2x"), (3, "3x")):
        dst = os.path.join(PNG, folder, rel.replace(".svg", ".png"))
        render(src, dst, ow=round(vw * mult), oh=round(vh * mult), replace_color=tint)
        n += 1

# Iconos también en esmeralda y blanco (estados activos / sobre fondo oscuro)
for rel, vw, vh in written:
    if not rel.startswith("iconos/"):
        continue
    src = os.path.join(SVG, rel)
    for tint, tag in ((C["esmeralda"], "esmeralda"), (C["blanco_hueso"], "blanco")):
        for mult, folder in ((1, "1x"), (2, "2x"), (3, "3x")):
            dst = os.path.join(PNG, folder, rel.replace("iconos/", f"iconos-{tag}/").replace(".svg", ".png"))
            render(src, dst, ow=round(vw * mult), oh=round(vh * mult), replace_color=tint)
            n += 1

# App icon: tamaños de tienda
sizes = {"app-icon-1024.png": 1024, "app-icon-512.png": 512, "app-icon-192.png": 192,
         "app-icon-144.png": 144, "app-icon-96.png": 96, "app-icon-72.png": 72,
         "app-icon-48.png": 48}
for fname, s in sizes.items():
    render(os.path.join(SVG, "marca/app-icon.svg"), os.path.join(PNG, "app-icon", fname), s, s)
    n += 1
for fname, s in (("adaptive-foreground-432.png", 432), ("adaptive-background-432.png", 432)):
    key = "foreground" if "fore" in fname else "background"
    render(os.path.join(SVG, f"marca/app-icon-adaptive-{key}.svg"),
           os.path.join(PNG, "app-icon", fname), s, s)
    n += 1
render(os.path.join(SVG, "marca/app-icon-cuadrado.svg"),
       os.path.join(PNG, "app-icon", "app-icon-playstore-512.png"), 512, 512)
n += 1

# Splash
for fname, wd in (("splash-1080x1920.png", 1080), ("splash-1440x2560.png", 1440)):
    render(os.path.join(SVG, "marca/splash.svg"), os.path.join(PNG, "splash", fname),
           wd, round(wd * 1920 / 1080))
    n += 1
# Logo para splash de Flutter (flutter_native_splash)
for fname, wd in (("splash-logo-1x.png", 288), ("splash-logo-2x.png", 576), ("splash-logo-3x.png", 864)):
    render(os.path.join(SVG, "marca/isotipo-reverse.svg"),
           os.path.join(PNG, "splash", fname), wd, wd)
    n += 1

print(f"PNG generados: {n}")
