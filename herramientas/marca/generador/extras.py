# -*- coding: utf-8 -*-
"""Ronda 2 — assets de publicación, onboarding y planes."""
from tokens import C
import brand as B
from brand import svg, isotipo, wordmark_paths, TAGLINE
from textpath import text_group


# ══════════════════════════════════════════════ tarjeta de libreta flexible
def card(x, y, w, h, rot=-2.6, dot_gap=26, first_line=46, line_gap=26, n_lines=None):
    n_dots = max(3, int((w - 40) // dot_gap) + 1)
    dots = "".join(
        f'<circle cx="{x + 20 + i * dot_gap:.1f}" cy="{y}" r="4.4" fill="{C["azul_noche"]}" opacity=".88"/>'
        for i in range(n_dots))
    if n_lines is None:
        n_lines = int((h - first_line - 18) // line_gap) + 1
    lines = "".join(
        f'<path d="M{x + 30} {y + first_line + i * line_gap:.0f}H{x + w - 20}" '
        f'stroke="{C["raya"]}" stroke-width="1.6"/>' for i in range(n_lines))
    return (f'<g transform="rotate({rot} {x + w/2} {y + h/2})">'
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{C["papel"]}" '
            f'stroke="{C["raya"]}" stroke-width="2"/>{lines}'
            f'<path d="M{x + 22} {y + 26}V{y + h - 16}" stroke="{C["coral"]}" '
            f'stroke-width="2.1" opacity=".78"/>{dots}</g>')


def scene(motif, w=320, h=240, back=None):
    return svg(w, h, (back or "") + motif)


# ══════════════════════════════════════════════ ONBOARDING
def _fila(x, y, wbar, color=None, dot=None):
    c = color or C["gris_piedra"]
    d = (f'<circle cx="{x}" cy="{y}" r="5" fill="{dot}"/>' if dot else "")
    return (d + f'<rect x="{x + (12 if dot else -6)}" y="{y - 4}" width="{wbar}" height="8" '
                f'rx="4" fill="{c}" opacity=".32"/>')


def onb_registrar_venta():
    back = card(48, 26, 224, 176, rot=-2.6)
    rows = "".join(_fila(96, 96 + i * 30, w, dot=C["esmeralda"])
                   for i, w in enumerate((92, 116, 74)))
    fab = (f'<circle cx="248" cy="188" r="30" fill="{C["esmeralda"]}"/>'
           f'<path d="M248 174v28M234 188h28" stroke="{C["sobre_acento"]}" '
           f'stroke-width="4.6" stroke-linecap="round"/>')
    chip = (f'<rect x="176" y="46" width="76" height="30" rx="15" fill="{C["esmeralda"]}" opacity=".14"/>'
            f'<path d="M192 61.5 200 69.5 236 53" fill="none" stroke="{C["esmeralda"]}" '
            f'stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>')
    return scene(rows + chip + fab, back=back)


def onb_inventario():
    back = card(40, 22, 200, 168, rot=-3)
    shelf = (f'<path d="M60 150h220M84 206h176" stroke="{C["azul_noche"]}" '
             f'stroke-width="4" stroke-linecap="round"/>')
    boxes = ""
    for bx, bw, bh, fill in ((92, 46, 52, C["blanco_hueso"]), (146, 38, 40, C["blanco_hueso"]),
                             (192, 52, 62, C["blanco_hueso"]), (252, 34, 36, C["blanco_hueso"])):
        boxes += (f'<rect x="{bx}" y="{150 - bh}" width="{bw}" height="{bh}" rx="5" fill="{fill}" '
                  f'stroke="{C["azul_noche"]}" stroke-width="3.2"/>'
                  f'<path d="M{bx + bw/2} {150 - bh}v{bh}" stroke="{C["azul_noche"]}" '
                  f'stroke-width="2.4" opacity=".35"/>')
    boxes += (f'<rect x="118" y="160" width="60" height="42" rx="5" fill="{C["blanco_hueso"]}" '
              f'stroke="{C["azul_noche"]}" stroke-width="3.2"/>'
              f'<rect x="188" y="164" width="48" height="38" rx="5" fill="{C["blanco_hueso"]}" '
              f'stroke="{C["azul_noche"]}" stroke-width="3.2"/>')
    badge = (f'<circle cx="248" cy="98" r="19" fill="{C["ambar"]}"/>'
             f'<path d="M248 89v10M248 106h.02" stroke="{C["azul_noche"]}" '
             f'stroke-width="3.6" stroke-linecap="round"/>')
    return scene(shelf + boxes + badge, back=back)


def onb_fiados():
    back = card(48, 24, 224, 180, rot=-2.4)
    rows = ""
    for i, (wb, col) in enumerate(((100, C["gris_piedra"]), (128, C["gris_piedra"]), (86, C["gris_piedra"]))):
        y = 92 + i * 34
        rows += (f'<circle cx="94" cy="{y}" r="12" fill="none" stroke="{C["azul_noche"]}" stroke-width="2.6"/>'
                 f'<circle cx="94" cy="{y - 3}" r="4" fill="{C["azul_noche"]}"/>'
                 f'<path d="M87.5 {y + 9.5}a7.5 7.5 0 0 1 13 0" fill="none" stroke="{C["azul_noche"]}" stroke-width="2.4"/>'
                 + _fila(118, y, wb, col))
    reloj = (f'<circle cx="252" cy="160" r="26" fill="{C["ambar"]}"/>'
             f'<circle cx="252" cy="160" r="15" fill="none" stroke="{C["azul_noche"]}" stroke-width="3"/>'
             f'<path d="M252 152v8l5.5 3.5" stroke="{C["azul_noche"]}" stroke-width="3" '
             f'stroke-linecap="round" stroke-linejoin="round"/>')
    return scene(rows + reloj, back=back)


def onb_bot_whatsapp():
    back = card(60, 92, 200, 132, rot=-2.4, first_line=40, n_lines=3)
    b1 = (f'<path d="M40 20h108a12 12 0 0 1 12 12v30a12 12 0 0 1-12 12H62l-14 14V74H40a12 12 0 0 1-12-12V32a12 12 0 0 1 12-12z" '
          f'fill="{C["blanco_hueso"]}" stroke="{C["azul_noche"]}" stroke-width="3"/>'
          f'<rect x="46" y="36" width="76" height="7" rx="3.5" fill="{C["gris_piedra"]}" opacity=".45"/>'
          f'<rect x="46" y="52" width="52" height="7" rx="3.5" fill="{C["gris_piedra"]}" opacity=".45"/>')
    b2 = (f'<path d="M292 12H196a12 12 0 0 0-12 12v22a12 12 0 0 0 12 12h74l14 12V58h8a12 12 0 0 0 12-12V24a12 12 0 0 0-12-12z" '
          f'fill="{C["esmeralda"]}"/>'
          f'<rect x="198" y="26" width="66" height="7" rx="3.5" fill="{C["sobre_acento"]}" opacity=".95"/>'
          f'<rect x="198" y="41" width="42" height="7" rx="3.5" fill="{C["sobre_acento"]}" opacity=".72"/>')
    flecha = (f'<path d="M162 100v14" stroke="{C["esmeralda"]}" stroke-width="4" '
              f'stroke-linecap="round" stroke-dasharray="2 9"/>'
              f'<path d="M154 112l8 9 8-9" fill="none" stroke="{C["esmeralda"]}" stroke-width="4" '
              f'stroke-linecap="round" stroke-linejoin="round"/>')
    chispa = (f'<path d="M300 76l3.4 8.6 8.6 3.4-8.6 3.4-3.4 8.6-3.4-8.6-8.6-3.4 8.6-3.4z" fill="{C["ambar"]}"/>'
              f'<path d="M276 100l2 5.2 5.2 2-5.2 2-2 5.2-2-5.2-5.2-2 5.2-2z" fill="{C["ambar"]}" opacity=".7"/>')
    entradas = "".join(_fila(104, 150 + i * 26, w, dot=C["esmeralda"]) for i, w in enumerate((78, 60)))
    return scene(b1 + b2 + flecha + chispa + entradas, w=320, h=250, back=back)


ONBOARDING = {
    "onb-registrar-venta": onb_registrar_venta,
    "onb-inventario":      onb_inventario,
    "onb-fiados":          onb_fiados,
    "onb-bot-whatsapp":    onb_bot_whatsapp,
}


# ══════════════════════════════════════════════ ESTADOS VACIOS EXTRA
def ilus_sin_fiados():
    back = B._card()
    m = (f'<g transform="translate(84 80)">'
         f'<circle cx="40" cy="40" r="30" fill="{C["blanco_hueso"]}" stroke="{C["azul_noche"]}" stroke-width="3.4"/>'
         f'<circle cx="40" cy="40" r="16" fill="none" stroke="{C["azul_noche"]}" stroke-width="3"/>'
         f'<path d="M40 31v9l6 4" stroke="{C["azul_noche"]}" stroke-width="3" '
         f'stroke-linecap="round" stroke-linejoin="round"/>'
         f'<circle cx="72" cy="12" r="13" fill="{C["esmeralda"]}"/>'
         f'<path d="M66 12.4 70.4 16.8 78.4 7.6" fill="none" stroke="{C["sobre_acento"]}" '
         f'stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>'
         f'</g>')
    return svg(240, 200, back + m)


def ilus_sin_reportes():
    back = B._card()
    m = (f'<g transform="translate(80 84)">'
         f'<path d="M6 78h92" stroke="{C["azul_noche"]}" stroke-width="3.4" stroke-linecap="round"/>'
         f'<rect x="18" y="52" width="18" height="26" rx="4" fill="none" stroke="{C["azul_noche"]}" '
         f'stroke-width="3" stroke-dasharray="5 6"/>'
         f'<rect x="44" y="34" width="18" height="44" rx="4" fill="none" stroke="{C["azul_noche"]}" '
         f'stroke-width="3" stroke-dasharray="5 6"/>'
         f'<rect x="70" y="58" width="18" height="20" rx="4" fill="none" stroke="{C["azul_noche"]}" '
         f'stroke-width="3" stroke-dasharray="5 6"/>'
         f'<circle cx="94" cy="18" r="12" fill="{C["ambar"]}"/>'
         f'<path d="M94 12v6M94 23h.02" stroke="{C["azul_noche"]}" stroke-width="2.8" stroke-linecap="round"/>'
         f'</g>')
    return svg(240, 200, back + m)


def ilus_sin_internet_guardado():
    back = B._card()
    m = (f'<g transform="translate(76 82)">'
         f'<rect x="8" y="24" width="72" height="56" rx="8" fill="{C["blanco_hueso"]}" '
         f'stroke="{C["azul_noche"]}" stroke-width="3.4"/>'
         f'<path d="M26 24V12h36v12" fill="none" stroke="{C["azul_noche"]}" stroke-width="3.2"/>'
         f'<rect x="30" y="48" width="28" height="20" rx="3" fill="none" stroke="{C["azul_noche"]}" stroke-width="3"/>'
         f'<circle cx="86" cy="20" r="14" fill="{C["esmeralda"]}"/>'
         f'<path d="M79.4 20.4 84 25 93 14" fill="none" stroke="{C["sobre_acento"]}" '
         f'stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>'
         f'</g>')
    return svg(240, 200, back + m)


EXTRA_ILUS = {
    "sin-fiados":       ilus_sin_fiados,
    "sin-reportes":     ilus_sin_reportes,
    "guardado-offline": ilus_sin_internet_guardado,
}


# ══════════════════════════════════════════════ MARCA MONOCROMA (notificación / themed icon)
def marca_silueta(box=24, color="#FFFFFF", pad=2.4):
    """Isotipo reducido a lo esencial: legible a 24 px, un solo color."""
    k = (box - pad * 2) / 24.0
    inner = (f'<rect x="2.6" y="4.6" width="18.8" height="16.4" rx="3" fill="none" '
             f'stroke="{color}" stroke-width="2"/>'
             f'<circle cx="7.4" cy="4.6" r="1.5" fill="{color}"/>'
             f'<circle cx="12" cy="4.6" r="1.5" fill="{color}"/>'
             f'<circle cx="16.6" cy="4.6" r="1.5" fill="{color}"/>'
             f'<path d="M6.6 16.6 10 13 12.8 15 17.4 10.2" fill="none" stroke="{color}" '
             f'stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    return svg(box, box, f'<g transform="translate({pad} {pad}) scale({k:.4f})">{inner}</g>')


def icono_monocromo_adaptive():
    """Themed icon de Android 13: 432 de lienzo, marca en la zona segura."""
    S, s = 432, 9.0
    off = (S - 24 * s) / 2
    return svg(S, S, f'<g transform="translate({off:.1f} {off:.1f}) scale({s})">'
                     f'{marca_silueta(24, "#FFFFFF", pad=0).split(chr(62), 1)[1].rsplit("<", 1)[0]}</g>')


# ══════════════════════════════════════════════ FEATURE GRAPHIC (Play Store)
def feature_graphic(W=1024, H=500):
    defs = (f'<defs><linearGradient id="fg" x1="0" y1="0" x2="1" y2="0.85">'
            f'<stop offset="0" stop-color="{C["grad_a"]}"/>'
            f'<stop offset="0.5" stop-color="{C["grad_b"]}"/>'
            f'<stop offset="1" stop-color="{C["grad_c"]}"/></linearGradient>'
            f'<pattern id="fr" width="{W}" height="34" patternUnits="userSpaceOnUse">'
            f'<path d="M0 33.5H{W}" stroke="{C["blanco_hueso"]}" stroke-width="1" opacity="0.07"/>'
            f'</pattern></defs>')
    bg = f'<rect width="{W}" height="{H}" fill="url(#fg)"/><rect width="{W}" height="{H}" fill="url(#fr)"/>'
    sc = 4.3
    iso = f'<g transform="translate(78 {H/2 - 32*sc - 16:.0f}) scale({sc})">{isotipo()}</g>'
    x0 = 78 + 64 * sc + 46
    wm1, w1 = text_group("Cuentas ", "inter-sb", 74, x0, 232, C["blanco_hueso"], tracking=-0.2)
    wm2, _ = text_group("Claras", "inter-sb", 74, x0 + w1, 232, "#8FE3D0", tracking=-0.2)
    tag, _ = text_group(TAGLINE, "caveat-b", 52, x0 + 4, 296, C["blanco_hueso"])
    tag = tag.replace('fill="', 'opacity=".8" fill="')
    sub, _ = text_group("Ventas · Inventario · Fiados", "inter", 30, x0 + 6, 352, C["blanco_hueso"])
    sub = sub.replace('fill="', 'opacity=".62" fill="')
    return svg(W, H, defs + bg + iso + wm1 + wm2 + tag + sub)


# ══════════════════════════════════════════════ INSIGNIAS DE PLAN
def plan_badge(kind="basico"):
    if kind == "basico":
        return svg(72, 72,
                   f'<circle cx="36" cy="36" r="33" fill="{C["blanco_hueso"]}" '
                   f'stroke="{C["esmeralda"]}" stroke-width="3"/>'
                   f'<rect x="22" y="22" width="28" height="26" rx="4" fill="none" '
                   f'stroke="{C["esmeralda"]}" stroke-width="2.8"/>'
                   f'<path d="M22 30h28M22 38h28" stroke="{C["esmeralda"]}" stroke-width="2.2" opacity=".55"/>')
    return svg(72, 72,
               f'<defs><linearGradient id="pg" x1="0" y1="0" x2="0.4" y2="1">'
               f'<stop offset="0" stop-color="{C["grad_a"]}"/>'
               f'<stop offset="0.55" stop-color="{C["grad_b"]}"/>'
               f'<stop offset="1" stop-color="{C["grad_c"]}"/></linearGradient></defs>'
               f'<circle cx="36" cy="36" r="33" fill="url(#pg)"/>'
               f'<path d="M36 17l5.6 13.4L55 36l-13.4 5.6L36 55l-5.6-13.4L17 36l13.4-5.6z" '
               f'fill="{C["blanco_hueso"]}"/>'
               f'<circle cx="52" cy="20" r="4.4" fill="{C["ambar"]}"/>')
