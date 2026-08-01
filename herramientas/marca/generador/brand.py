# -*- coding: utf-8 -*-
"""Marca, texturas e ilustraciones — Cuentas Claras"""
from tokens import C
from textpath import text_group

TAGLINE = "Tu negocio al día"


# ══════════════════════════════════════════════════════════ ISOTIPO
def isotipo(card=None, borde=None, punto=None, raya=None, coral=None, linea=None, apex=None):
    """Marca en grilla de 64. Devuelve el contenido interno (sin <svg>)."""
    card  = card  or C["blanco_hueso"]
    borde = borde or C["azul_noche"]
    punto = punto or C["azul_noche"]
    raya  = raya  or C["gris_piedra"]
    coral = coral or C["coral"]
    linea = linea or C["esmeralda"]
    apex  = apex  or C["ambar"]
    dots = "".join(
        f'<circle cx="{x}" cy="17" r="2.3" fill="{punto}"/>'
        for x in (19.0, 27.7, 36.4, 45.1)
    )
    return f'''<rect x="10" y="17" width="44" height="39" rx="6.5" fill="{card}" stroke="{borde}" stroke-width="2.6"/>
  {dots}
  <path d="M18.7 24.5V50" stroke="{coral}" stroke-width="1.9" stroke-linecap="round"/>
  <path d="M23.8 28.6h23.4" stroke="{raya}" stroke-width="1.7" stroke-linecap="round"/>
  <path d="M23.8 46.2 30.6 38.6 36.2 42.6 46.4 32.4" fill="none" stroke="{linea}"
        stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="46.4" cy="32.4" r="3" fill="{apex}"/>'''


def svg(vb_w, vb_h, body, w=None, h=None):
    w = w or vb_w
    h = h or vb_h
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {vb_w} {vb_h}" '
            f'width="{w}" height="{h}" fill="none">\n  {body}\n</svg>\n')


def isotipo_svg(**kw):
    return svg(64, 64, isotipo(**kw))


def isotipo_reverse_svg():
    return svg(64, 64, isotipo(card=C["blanco_hueso"], borde=C["blanco_hueso"],
                               punto=C["blanco_hueso"], raya="#B8C6C2",
                               coral=C["coral"], linea=C["esmeralda"], apex=C["ambar"]))


def isotipo_mono_svg(color="#1B3A4B"):
    dots = "".join(f'<circle cx="{x}" cy="17" r="2.3" fill="{color}"/>'
                   for x in (19.0, 27.7, 36.4, 45.1))
    body = f'''<rect x="10" y="17" width="44" height="39" rx="6.5" fill="none" stroke="{color}" stroke-width="2.6"/>
  {dots}
  <path d="M18.7 24.5V50" stroke="{color}" stroke-width="1.9" stroke-linecap="round" opacity=".45"/>
  <path d="M23.8 28.6h23.4" stroke="{color}" stroke-width="1.7" stroke-linecap="round" opacity=".35"/>
  <path d="M23.8 46.2 30.6 38.6 36.2 42.6 46.4 32.4" fill="none" stroke="{color}"
        stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="46.4" cy="32.4" r="3" fill="{color}"/>'''
    return svg(64, 64, body)


# ══════════════════════════════════════════════════════════ LOGOTIPOS
def wordmark_paths(size, x, y, c1, c2, tracking=-0.2):
    p1, w1 = text_group("Cuentas ", "inter-sb", size, x, y, c1, tracking=tracking)
    p2, w2 = text_group("Claras", "inter-sb", size, x + w1, y, c2, tracking=tracking)
    return p1 + "\n  " + p2, w1 + w2


def logo_horizontal(c1=None, c2=None, iso=None, tag=None, tagcolor=None):
    c1 = c1 or C["azul_noche"]
    c2 = c2 or C["esmeralda"]
    iso_body = iso if iso is not None else isotipo()
    size = 30
    if tag:
        base, h, dy = 40, 74, 6
        wm, w = wordmark_paths(size, 82, base, c1, c2)
        tp, _ = text_group(tag, "caveat-b", 26, 84, base + 22, tagcolor or C["gris_piedra"])
        extra = "\n  " + tp
    else:
        base, h, dy = 47, 64, 0
        wm, w = wordmark_paths(size, 82, base, c1, c2)
        extra = ""
    total = int(82 + w + 6)
    body = f'<g transform="translate(0 {dy})">{iso_body}</g>\n  {wm}{extra}'
    return svg(total, h, body)


def logo_vertical(c1=None, c2=None, iso=None, tag=None, tagcolor=None):
    c1 = c1 or C["azul_noche"]
    c2 = c2 or C["esmeralda"]
    iso_body = iso if iso is not None else isotipo()
    W = 260
    size = 34
    _, w = wordmark_paths(size, 0, 0, c1, c2)
    wm, _ = wordmark_paths(size, (W - w) / 2, 124, c1, c2)
    extra, h = "", 146
    if tag:
        tp, _ = text_group(tag, "caveat-b", 28, W / 2, 156, tagcolor or C["gris_piedra"],
                           anchor="middle")
        extra = "\n  " + tp
        h = 172
    ix = (W - 84) / 2
    body = (f'<g transform="translate({ix} 8) scale(1.3125)">{iso_body}</g>\n  {wm}{extra}')
    return svg(W, h, body)


def wordmark_solo(c1=None, c2=None):
    c1 = c1 or C["azul_noche"]
    c2 = c2 or C["esmeralda"]
    size = 40
    _, w = wordmark_paths(size, 0, 0, c1, c2)
    wm, _ = wordmark_paths(size, 4, 40, c1, c2)
    return svg(int(w + 8), 52, wm)


# ══════════════════════════════════════════════════════════ APP ICON
def app_icon(full_bleed=True, adaptive=False):
    S = 1024
    if adaptive:
        scale, off = 10.2, (S - 64 * 10.2) / 2
        body = (f'<g transform="translate({off:.1f} {off - 4 * scale:.1f}) scale({scale})">'
                f'{isotipo()}</g>')
        return svg(S, S, body)
    scale = 13.4
    off = (S - 64 * scale) / 2
    radius = 224 if full_bleed else 0
    bg = (f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
          f'<stop offset="0" stop-color="#24506A"/><stop offset="1" stop-color="{C["azul_noche"]}"/>'
          f'</linearGradient></defs>'
          f'<rect width="{S}" height="{S}" rx="{radius}" fill="url(#bg)"/>')
    body = (bg + f'<g transform="translate({off:.1f} {off - 4 * scale:.1f}) scale({scale})">'
            f'{isotipo()}</g>')
    return svg(S, S, body)


def app_icon_bg():
    return svg(1024, 1024,
               f'<defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1">'
               f'<stop offset="0" stop-color="#24506A"/><stop offset="1" stop-color="{C["azul_noche"]}"/>'
               f'</linearGradient></defs><rect width="1024" height="1024" fill="url(#b)"/>')


# ══════════════════════════════════════════════════════════ SPLASH
def splash(W=1080, H=1920):
    grad = (f'<defs><linearGradient id="g" x1="0" y1="0" x2="0.25" y2="1">'
            f'<stop offset="0" stop-color="{C["grad_a"]}"/>'
            f'<stop offset="0.52" stop-color="{C["grad_b"]}"/>'
            f'<stop offset="1" stop-color="{C["grad_c"]}"/></linearGradient>'
            f'<pattern id="rayas" width="{W}" height="46" patternUnits="userSpaceOnUse">'
            f'<path d="M0 45.5H{W}" stroke="{C["blanco_hueso"]}" stroke-width="1" opacity="0.07"/>'
            f'</pattern></defs>')
    bg = (f'<rect width="{W}" height="{H}" fill="url(#g)"/>'
          f'<rect width="{W}" height="{H}" fill="url(#rayas)"/>')
    scale = 5.6
    iw = 64 * scale
    ix, iy = (W - iw) / 2, H * 0.315
    iso = (f'<g transform="translate({ix:.1f} {iy:.1f}) scale({scale})">'
           f'{isotipo()}</g>')
    wm_size = 78
    _, w = wordmark_paths(wm_size, 0, 0, "#fff", "#fff")
    wm1, w1 = text_group("Cuentas ", "inter-sb", wm_size, (W - w) / 2, iy + iw + 130,
                         C["blanco_hueso"], tracking=-0.2)
    wm2, _ = text_group("Claras", "inter-sb", wm_size, (W - w) / 2 + w1, iy + iw + 130,
                        "#8FE3D0", tracking=-0.2)
    tag, _ = text_group(TAGLINE, "caveat-b", 58, W / 2, iy + iw + 210,
                        C["blanco_hueso"], anchor="middle")
    tag = tag.replace('fill="', 'opacity="0.78" fill="')
    marca, _ = text_group("mitzukyhs", "inter", 30, W / 2, H - 96,
                          C["blanco_hueso"], anchor="middle")
    marca = marca.replace('fill="', 'opacity="0.45" fill="')
    return svg(W, H, grad + bg + iso + "\n  " + wm1 + "\n  " + wm2 + "\n  " + tag + "\n  " + marca)


# ══════════════════════════════════════════════════════════ TEXTURAS
def espiral_horizontal(W=360, n=10):
    step = W / n
    dots = "".join(
        f'<circle cx="{step*(i+0.5):.1f}" cy="16" r="4.6" fill="{C["azul_noche"]}"/>'
        f'<path d="M{step*(i+0.5):.1f} 16V5.5" stroke="{C["azul_noche"]}" stroke-width="2.4" stroke-linecap="round" opacity=".5"/>'
        for i in range(n))
    return svg(W, 28, dots)


def lineas_rayadas(W=360, H=280, gap=28):
    lines = "".join(f'<path d="M0 {y}H{W}" stroke="{C["raya"]}" stroke-width="1.4"/>'
                    for y in range(gap, H + 1, gap))
    return svg(W, H, lines)


def margen_coral(H=360):
    return svg(6, H, f'<path d="M3 0V{H}" stroke="{C["coral"]}" stroke-width="2.6" stroke-linecap="round" opacity=".85"/>')


def patron_puntos(S=48):
    return svg(S, S, f'<circle cx="{S/2}" cy="{S/2}" r="1.7" fill="{C["gris_piedra"]}" opacity=".28"/>')


def hoja_libreta(W=360, H=520):
    lines = "".join(f'<path d="M46 {y}H{W-26}" stroke="{C["raya"]}" stroke-width="1.4"/>'
                    for y in range(78, H - 24, 30))
    dots = "".join(f'<circle cx="{34 + i*36}" cy="20" r="5" fill="{C["azul_noche"]}" opacity=".9"/>'
                   for i in range(9))
    return svg(W, H,
               f'<rect width="{W}" height="{H}" rx="18" fill="{C["papel"]}"/>'
               f'{lines}'
               f'<path d="M38 44V{H-24}" stroke="{C["coral"]}" stroke-width="2.2" opacity=".8"/>'
               f'{dots}')


# ══════════════════════════════════════════════════════════ ILUSTRACIONES
def _card(rot=-3.2, x=38, y=26, w=164, h=150):
    """Tarjeta de hoja de libreta, base de todas las ilustraciones."""
    lines = "".join(f'<path d="M{x+28} {y+ry}H{x+w-18}" stroke="{C["raya"]}" stroke-width="1.6"/>'
                    for ry in (58, 84, 110, 136))
    dots = "".join(f'<circle cx="{x+22+i*24}" cy="{y}" r="4.2" fill="{C["azul_noche"]}" opacity=".85"/>'
                   for i in range(6))
    return (f'<g transform="rotate({rot} {x+w/2} {y+h/2})">'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{C["papel"]}" '
            f'stroke="{C["raya"]}" stroke-width="2"/>{lines}'
            f'<path d="M{x+20} {y+28}V{y+h-16}" stroke="{C["coral"]}" stroke-width="2" opacity=".75"/>'
            f'{dots}</g>')


def _wrap(motif, w=240, h=200):
    return svg(w, h, _card() + motif)


def ilus_sin_ventas():
    m = (f'<g>'
         f'<path d="M84 150 108 126 128 142 164 100" fill="none" stroke="{C["esmeralda"]}" '
         f'stroke-width="5" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="7 11" opacity=".55"/>'
         f'<circle cx="164" cy="100" r="7.5" fill="{C["ambar"]}"/>'
         f'<path d="M84 150h84" stroke="{C["gris_piedra"]}" stroke-width="3" stroke-linecap="round" opacity=".35"/>'
         f'</g>')
    return _wrap(m)


def ilus_sin_productos():
    m = (f'<g transform="translate(70 84)">'
         f'<path d="M12 26 48 8l36 18v40L48 84 12 66z" fill="{C["blanco_hueso"]}" '
         f'stroke="{C["azul_noche"]}" stroke-width="3.4" stroke-linejoin="round"/>'
         f'<path d="M12 26 48 44l36-18" fill="none" stroke="{C["azul_noche"]}" stroke-width="3" stroke-linejoin="round"/>'
         f'<path d="M48 44v40" stroke="{C["azul_noche"]}" stroke-width="3"/>'
         f'<rect x="30" y="-26" width="36" height="30" rx="6" fill="none" stroke="{C["esmeralda"]}" '
         f'stroke-width="3.2" stroke-dasharray="6 7"/>'
         f'<path d="M48 -17v12M42 -11h12" stroke="{C["esmeralda"]}" stroke-width="3.2" stroke-linecap="round"/>'
         f'</g>')
    return _wrap(m)


def ilus_sin_clientes():
    m = (f'<g transform="translate(84 78)">'
         f'<circle cx="40" cy="26" r="17" fill="{C["blanco_hueso"]}" stroke="{C["azul_noche"]}" '
         f'stroke-width="3.2" stroke-dasharray="6 7"/>'
         f'<path d="M8 82a32 32 0 0 1 64 0" fill="{C["blanco_hueso"]}" stroke="{C["azul_noche"]}" '
         f'stroke-width="3.2" stroke-dasharray="6 7" stroke-linecap="round"/>'
         f'<circle cx="76" cy="14" r="13" fill="{C["esmeralda"]}"/>'
         f'<path d="M76 8.4v11.2M70.4 14h11.2" stroke="{C["sobre_acento"]}" stroke-width="3" stroke-linecap="round"/>'
         f'</g>')
    return _wrap(m)


def ilus_sin_conexion():
    m = (f'<g transform="translate(70 82)">'
         f'<path d="M28 66h56a22 22 0 0 0 3-43.8A28 28 0 0 0 30 16 20 20 0 0 0 28 66z" '
         f'fill="{C["blanco_hueso"]}" stroke="{C["azul_noche"]}" stroke-width="3.4" stroke-linejoin="round"/>'
         f'<path d="M16 8 86 70" stroke="{C["ambar"]}" stroke-width="5.5" stroke-linecap="round"/>'
         f'<path d="M40 84h36" stroke="{C["gris_piedra"]}" stroke-width="3" stroke-linecap="round" opacity=".4"/>'
         f'</g>')
    return _wrap(m)


def ilus_sin_resultados():
    m = (f'<g transform="translate(78 76)">'
         f'<circle cx="46" cy="40" r="27" fill="{C["blanco_hueso"]}" stroke="{C["azul_noche"]}" stroke-width="3.6"/>'
         f'<path d="M65 59 84 78" stroke="{C["azul_noche"]}" stroke-width="6" stroke-linecap="round"/>'
         f'<path d="M36 40h20" stroke="{C["coral"]}" stroke-width="3.4" stroke-linecap="round"/>'
         f'</g>')
    return _wrap(m)


def ilus_listo():
    m = (f'<g transform="translate(80 76)">'
         f'<circle cx="46" cy="44" r="30" fill="{C["esmeralda"]}"/>'
         f'<path d="M33 44.5 42.5 54 60 34" fill="none" stroke="{C["sobre_acento"]}" '
         f'stroke-width="5.4" stroke-linecap="round" stroke-linejoin="round"/>'
         f'<path d="M14 16 20 22M78 18l-6 6M46 6v8" stroke="{C["ambar"]}" stroke-width="4" stroke-linecap="round"/>'
         f'</g>')
    return _wrap(m)


ILUSTRACIONES = {
    "sin-ventas":     ilus_sin_ventas,
    "sin-productos":  ilus_sin_productos,
    "sin-clientes":   ilus_sin_clientes,
    "sin-conexion":   ilus_sin_conexion,
    "sin-resultados": ilus_sin_resultados,
    "listo":          ilus_listo,
}
