# -*- coding: utf-8 -*-
"""Ronda 3 — variantes de modo oscuro y corrección del pubspec."""
import os, re, cairosvg

ROOT = "/home/claude/out/cuentas-claras-assets"
SVG = os.path.join(ROOT, "svg")
PNG = os.path.join(ROOT, "png")

# Superficies oscuras derivadas del azul noche.
SUP_OSCURA   = "#14262F"   # fondo de la hoja
SUP_ELEVADA  = "#1B3A4B"   # objetos sobre la hoja
RAYA_OSCURA  = "#2E4A5A"
TRAZO_CLARO  = "#E3EBE9"
GRIS_CLARO   = "#7E9198"

# El orden importa: se usa un marcador intermedio para no pisar colores ya sustituidos.
MAPA = [
    ("#1B3A4B", "@@TRAZO@@"),    # azul noche -> trazo claro
    ("#FDFCF8", "@@SUP@@"),      # papel      -> superficie oscura
    ("#F7F9F7", "@@ELEV@@"),     # blanco hueso -> superficie elevada
    ("#DCE5E2", RAYA_OSCURA),    # renglones
    ("#8A9A96", GRIS_CLARO),     # gris piedra
]
FINAL = [("@@TRAZO@@", TRAZO_CLARO), ("@@SUP@@", SUP_OSCURA), ("@@ELEV@@", SUP_ELEVADA)]


def a_oscuro(texto):
    for a, b in MAPA:
        texto = texto.replace(a, b).replace(a.lower(), b)
    for a, b in FINAL:
        texto = texto.replace(a, b)
    return texto


nuevos = []
origen = os.path.join(SVG, "ilustraciones")
destino = os.path.join(SVG, "ilustraciones-dark")
os.makedirs(destino, exist_ok=True)

for f in sorted(os.listdir(origen)):
    if not f.endswith(".svg"):
        continue
    src = os.path.join(origen, f)
    out = os.path.join(destino, f)
    contenido = a_oscuro(open(src, encoding="utf-8").read())
    open(out, "w", encoding="utf-8").write(contenido)
    m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', contenido)
    nuevos.append((f"ilustraciones-dark/{f}", float(m.group(1)), float(m.group(2))))

n = 0
for rel, vw, vh in nuevos:
    for mult, dens in ((1, "1x"), (2, "2x"), (3, "3x")):
        dst = os.path.join(PNG, dens, rel.replace(".svg", ".png"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        cairosvg.svg2png(url=os.path.join(SVG, rel), write_to=dst,
                         output_width=round(vw * mult), output_height=round(vh * mult))
        n += 1

print(f"Ilustraciones dark: {len(nuevos)} SVG, {n} PNG")
