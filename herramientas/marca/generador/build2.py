# -*- coding: utf-8 -*-
import os, re
import cairosvg
import extras as E
import brand as B
from brand import svg
from tokens import C

OUT = "/home/claude/out/cuentas-claras-assets"
SVG = os.path.join(OUT, "svg")
PNG = os.path.join(OUT, "png")
nuevos = []


def w(rel, content):
    p = os.path.join(SVG, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w", encoding="utf-8").write(content)
    m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', content)
    nuevos.append((rel, float(m.group(1)), float(m.group(2))))
    return p


def render(src, dst, ow=None, oh=None, bg=None):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    cairosvg.svg2png(url=src, write_to=dst, output_width=ow, output_height=oh, background_color=bg)


# ── Onboarding
for name, fn in E.ONBOARDING.items():
    w(f"ilustraciones/{name}.svg", fn())

# ── Estados vacíos adicionales
for name, fn in E.EXTRA_ILUS.items():
    w(f"ilustraciones/{name}.svg", fn())

# ── Insignias de plan
w("marca/plan-basico.svg", E.plan_badge("basico"))
w("marca/plan-plus.svg", E.plan_badge("plus"))

# ── Marca monocroma (notificación / themed icon)
w("marca/marca-silueta.svg", E.marca_silueta(24, "#FFFFFF"))
w("marca/marca-silueta-azul.svg", E.marca_silueta(24, C["azul_noche"]))

S, sc = 432, 9.0
off = (S - 24 * sc) / 2
mono_inner = E.marca_silueta(24, "#FFFFFF", pad=0)
mono_inner = mono_inner[mono_inner.index(">") + 1: mono_inner.rindex("</svg>")].strip()
w("marca/app-icon-monochrome.svg",
  svg(S, S, f'<g transform="translate({off:.1f} {off:.1f}) scale({sc})">{mono_inner}</g>'))

# ── Feature graphic
w("marca/play-feature-graphic.svg", E.feature_graphic())

print(f"SVG nuevos: {len(nuevos)}")

# ── PNG 1x/2x/3x para lo que va dentro de la app
SOLO_ESPECIAL = {"marca/play-feature-graphic.svg", "marca/app-icon-monochrome.svg"}
n = 0
for rel, vw, vh in nuevos:
    if rel in SOLO_ESPECIAL:
        continue
    src = os.path.join(SVG, rel)
    for mult, folder in ((1, "1x"), (2, "2x"), (3, "3x")):
        render(src, os.path.join(PNG, folder, rel.replace(".svg", ".png")),
               round(vw * mult), round(vh * mult))
        n += 1

# ── Ícono de notificación Android (blanco, transparente)
for dens, px in (("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)):
    render(os.path.join(SVG, "marca/marca-silueta.svg"),
           os.path.join(PNG, "notificacion", f"ic_notification-{dens}-{px}.png"), px, px)
    n += 1

# ── Themed icon de Android 13
render(os.path.join(SVG, "marca/app-icon-monochrome.svg"),
       os.path.join(PNG, "app-icon", "adaptive-monochrome-432.png"), 432, 432)
n += 1

# ── Feature graphic (sin alfa, como pide Google Play)
render(os.path.join(SVG, "marca/play-feature-graphic.svg"),
       os.path.join(PNG, "tienda", "play-feature-graphic-1024x500.png"), 1024, 500, bg="#5A3A28")
n += 1

# ── Favicon / web
for px in (16, 32, 48, 64, 192, 512):
    render(os.path.join(SVG, "marca/app-icon.svg"),
           os.path.join(PNG, "web", f"favicon-{px}.png"), px, px)
    n += 1
render(os.path.join(SVG, "marca/app-icon-cuadrado.svg"),
       os.path.join(PNG, "web", "apple-touch-icon-180.png"), 180, 180, bg="#1B3A4B")
n += 1
render(os.path.join(SVG, "marca/app-icon-cuadrado.svg"),
       os.path.join(PNG, "web", "og-image-1200x630.png"), 1200, 1200)
n += 1

print(f"PNG nuevos: {n}")
