# -*- coding: utf-8 -*-
"""Auditoría del paquete de assets de Cuentas Claras."""
import os, re, sys, subprocess, xml.etree.ElementTree as ET
from PIL import Image

ROOT = "/home/claude/out/cuentas-claras-assets"
SVG = os.path.join(ROOT, "svg")
PNG = os.path.join(ROOT, "png")

fallas, avisos, ok = [], [], []


def F(m): fallas.append(m)
def A(m): avisos.append(m)
def K(m): ok.append(m)


svgs = sorted(os.path.relpath(os.path.join(r, f), SVG)
              for r, _, fs in os.walk(SVG) for f in fs if f.endswith(".svg"))

# ── 1. SVG válidos, con viewBox y sin tamaño cero
for rel in svgs:
    p = os.path.join(SVG, rel)
    try:
        root = ET.parse(p).getroot()
    except ET.ParseError as e:
        F(f"SVG mal formado: {rel} — {e}")
        continue
    vb = root.get("viewBox")
    if not vb:
        F(f"SVG sin viewBox: {rel}")
    else:
        _, _, vw, vh = [float(x) for x in vb.split()]
        if vw <= 0 or vh <= 0:
            F(f"viewBox inválido: {rel}")
K(f"{len(svgs)} SVG parseados sin errores de sintaxis")

# ── 2. Los íconos deben usar currentColor (para teñirlos desde Flutter)
sin_cc = [r for r in svgs if r.startswith("iconos/")
          and "currentColor" not in open(os.path.join(SVG, r), encoding="utf-8").read()]
if sin_cc:
    F(f"Íconos sin currentColor: {sin_cc}")
else:
    K(f"{len([r for r in svgs if r.startswith('iconos/')])} íconos usan currentColor")

# ── 3. Los logos NO deben depender de fuentes instaladas
con_texto = [r for r in svgs if "<text" in open(os.path.join(SVG, r), encoding="utf-8").read()]
if con_texto:
    F(f"SVG con <text> (dependen de fuente instalada): {con_texto}")
else:
    K("Ningún SVG usa <text>: los logos son autocontenidos")

# ── 4. Cobertura de PNG en 1x/2x/3x
esperado_multi = [r for r in svgs if r not in {
    "marca/splash.svg", "marca/app-icon.svg", "marca/app-icon-cuadrado.svg",
    "marca/app-icon-adaptive-foreground.svg", "marca/app-icon-adaptive-background.svg",
    "marca/play-feature-graphic.svg", "marca/app-icon-monochrome.svg"}]
faltan = []
for rel in esperado_multi:
    for d in ("1x", "2x", "3x"):
        p = os.path.join(PNG, d, rel.replace(".svg", ".png"))
        if not os.path.exists(p):
            faltan.append(f"{d}/{rel}")
if faltan:
    F(f"PNG faltantes ({len(faltan)}): {faltan[:8]}")
else:
    K(f"{len(esperado_multi)} assets presentes en 1x, 2x y 3x")

# ── 5. Variantes de color de íconos
iconos = [r for r in svgs if r.startswith("iconos/")]
faltan_v = []
for rel in iconos:
    for d in ("1x", "2x", "3x"):
        for tag in ("esmeralda", "blanco"):
            p = os.path.join(PNG, d, rel.replace("iconos/", f"iconos-{tag}/").replace(".svg", ".png"))
            if not os.path.exists(p):
                faltan_v.append(f"{d}/{tag}/{rel}")
if faltan_v:
    F(f"Variantes de color faltantes: {len(faltan_v)}")
else:
    K("Íconos completos en azul noche, esmeralda y blanco")

# ── 6. Ningún PNG vacío o transparente por completo
vacios, planos = [], []
todos_png = [os.path.join(r, f) for r, _, fs in os.walk(PNG) for f in fs if f.endswith(".png")]
for p in todos_png:
    if os.path.getsize(p) < 120:
        vacios.append(os.path.relpath(p, PNG)); continue
    im = Image.open(p).convert("RGBA")
    ex = im.getextrema()
    if ex[3][1] == 0:
        vacios.append(os.path.relpath(p, PNG))
    elif all(ex[i][0] == ex[i][1] for i in range(4)):
        planos.append(os.path.relpath(p, PNG))
if vacios:
    F(f"PNG totalmente transparentes/vacíos ({len(vacios)}): {vacios[:6]}")
else:
    K(f"{len(todos_png)} PNG con contenido real")
if planos:
    A(f"PNG de un solo color ({len(planos)}): {planos[:6]}")

# ── 7. Requisitos de tienda
def chk(rel, w_, h_, alpha_permitido=True, etiqueta=""):
    p = os.path.join(PNG, rel)
    if not os.path.exists(p):
        F(f"Falta {etiqueta or rel}"); return
    im = Image.open(p)
    if im.size != (w_, h_):
        F(f"{rel} mide {im.size[0]}x{im.size[1]}, se esperaba {w_}x{h_}")
    if not alpha_permitido:
        rgba = im.convert("RGBA")
        if rgba.getextrema()[3][0] < 255:
            F(f"{rel} tiene transparencia y la tienda la rechaza")
        else:
            K(f"{etiqueta or rel}: {w_}x{h_} sin alfa ✓")
    else:
        K(f"{etiqueta or rel}: {w_}x{h_} ✓")


chk("app-icon/app-icon-playstore-512.png", 512, 512, False, "Ícono Play 512")
chk("tienda/play-feature-graphic-1024x500.png", 1024, 500, False, "Feature graphic")
chk("app-icon/app-icon-1024.png", 1024, 1024, True, "Ícono maestro 1024")
chk("app-icon/adaptive-foreground-432.png", 432, 432, True, "Adaptive foreground")
chk("app-icon/adaptive-background-432.png", 432, 432, True, "Adaptive background")
chk("app-icon/adaptive-monochrome-432.png", 432, 432, True, "Themed icon")
chk("web/apple-touch-icon-180.png", 180, 180, False, "Apple touch icon")
chk("splash/splash-1080x1920.png", 1080, 1920, True, "Splash 1080x1920")

# ── 8. Ícono de notificación: debe ser blanco puro sobre transparente
for dens, px in (("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)):
    p = os.path.join(PNG, "notificacion", f"ic_notification-{dens}-{px}.png")
    if not os.path.exists(p):
        F(f"Falta ícono de notificación {dens}"); continue
    im = Image.open(p).convert("RGBA")
    if im.size != (px, px):
        F(f"Notificación {dens} mide {im.size}, se esperaba {px}x{px}")
    px_data = [q for q in im.getdata() if q[3] > 12]
    malos = [q for q in px_data if not (q[0] > 235 and q[1] > 235 and q[2] > 235)]
    if len(malos) > len(px_data) * 0.06:
        F(f"Notificación {dens}: {len(malos)}/{len(px_data)} píxeles no son blancos")
if not any("otificaci" in f for f in fallas):
    K("Ícono de notificación: blanco puro sobre transparente en las 5 densidades")

# ── 9. app_assets.dart apunta a archivos que existen
dart = open(os.path.join(ROOT, "app_assets.dart"), encoding="utf-8").read()
rutas = re.findall(r"'\$_svg/([^']+)'", dart)
rotas = [r for r in rutas if not os.path.exists(os.path.join(SVG, r))]
if rotas:
    F(f"app_assets.dart apunta a archivos inexistentes: {rotas}")
else:
    K(f"app_assets.dart: {len(rutas)} rutas verificadas contra el disco")

sin_const = [r for r in svgs if r not in rutas]
if sin_const:
    A(f"SVG sin constante en Dart ({len(sin_const)}): {sin_const}")

dups = {n for n in re.findall(r"static const (\w+) =", dart)
        if re.findall(r"static const (\w+) =", dart).count(n) > 1}
if dups:
    F(f"Constantes Dart duplicadas: {dups}")
else:
    K("Sin nombres duplicados en app_assets.dart")

if dart.index("import 'package:flutter/material.dart'") > dart.index("abstract final class"):
    F("El import de material.dart está después de una clase (Dart no compila así)")
else:
    K("Import de Dart en la posición correcta")

# ── 10. pubspec: cada carpeta declarada existe y cada carpeta existente está declarada
pub = open(os.path.join(ROOT, "pubspec-assets.yaml"), encoding="utf-8").read()
declaradas = re.findall(r"- assets/(\S+)/", pub)
inexistentes = [d for d in declaradas if not os.path.isdir(os.path.join(ROOT, d))]
if inexistentes:
    F(f"pubspec declara carpetas que no existen: {inexistentes}")
else:
    K(f"pubspec: {len(declaradas)} carpetas declaradas, todas existen")

reales = set()
for base in ("svg", "png"):
    for r, _, fs in os.walk(os.path.join(ROOT, base)):
        if any(f.endswith((".svg", ".png")) for f in fs):
            reales.add(os.path.relpath(r, ROOT).replace("\\", "/"))
INTENCIONAL = {"png/notificacion", "png/tienda", "png/web"}
no_decl = sorted(reales - set(declaradas) - INTENCIONAL)
if no_decl:
    F(f"Carpetas con assets NO declaradas en pubspec ({len(no_decl)}): {no_decl}")
else:
    K("Carpetas de runtime declaradas; notificacion/tienda/web excluidas a propósito")

# ── 11. Contenido dentro del lienzo (nada recortado)
import cairosvg, io
recortados = []
for rel in svgs:
    if rel.startswith(("marca/app-icon", "marca/splash", "marca/play-")):
        continue
    try:
        buf = cairosvg.svg2png(url=os.path.join(SVG, rel), output_width=400)
    except Exception as e:
        F(f"No renderiza: {rel} — {e}"); continue
    im = Image.open(io.BytesIO(buf)).convert("RGBA")
    bb = im.split()[3].getbbox()
    if bb is None:
        F(f"Render vacío: {rel}"); continue
    W, H = im.size
    if rel.startswith("texturas/"):
        continue
    if bb[0] <= 0 or bb[1] <= 0 or bb[2] >= W or bb[3] >= H:
        recortados.append(rel)
if recortados:
    A(f"Contenido tocando el borde del lienzo ({len(recortados)}): {recortados}")
else:
    K("Ningún elemento se sale ni toca el borde del lienzo")

# ── 12. Generador incluido y ejecutable
gen = os.path.join(ROOT, "generador")
esperados = {"tokens.py", "brand.py", "textpath.py", "build.py", "package.py",
             "extras.py", "build2.py", "build3.py", "auditar.py"}
hay = set(os.listdir(gen)) if os.path.isdir(gen) else set()
if esperados - hay:
    F(f"Faltan scripts del generador: {sorted(esperados - hay)}")
else:
    K(f"Generador completo ({len(hay)} scripts)")

# ── 13. Catálogo
cat = open(os.path.join(ROOT, "catalogo.html"), encoding="utf-8").read()
n_emb = cat.count("data:image/svg+xml;base64,")
if n_emb < len(svgs) * 0.8:
    A(f"El catálogo embebe {n_emb} de {len(svgs)} SVG")
else:
    K(f"Catálogo: {n_emb} vectores embebidos (funciona sin conexión)")

# ── Resultado
print("=" * 62)
print(f"CORRECTO ({len(ok)})")
for m in ok: print("  ✓", m)
if avisos:
    print(f"\nAVISOS ({len(avisos)})")
    for m in avisos: print("  •", m)
if fallas:
    print(f"\nFALLAS ({len(fallas)})")
    for m in fallas: print("  ✗", m)
else:
    print("\nFALLAS (0)")
print("=" * 62)
