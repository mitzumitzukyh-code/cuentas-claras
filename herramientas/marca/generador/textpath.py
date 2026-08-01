# -*- coding: utf-8 -*-
"""Convierte texto a path SVG (logos autocontenidos, sin dependencia de fuente)."""
import os
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.misc.transform import Transform

FONTS = {
    "inter":     os.path.expanduser("~/.fonts/Inter-Regular.ttf"),
    "inter-sb":  os.path.expanduser("~/.fonts/Inter-SemiBold.ttf"),
    "inter-b":   os.path.expanduser("~/.fonts/Inter-Bold.ttf"),
    "caveat":    os.path.expanduser("~/.fonts/Caveat-Regular.ttf"),
    "caveat-b":  os.path.expanduser("~/.fonts/Caveat-Bold.ttf"),
}
_cache = {}


def _font(key):
    if key not in _cache:
        _cache[key] = TTFont(FONTS[key])
    return _cache[key]


def text_path(text, font_key, size, x=0, y=0, tracking=0.0):
    """Devuelve (path_d, ancho_total). y = baseline."""
    f = _font(font_key)
    upm = f["head"].unitsPerEm
    scale = size / upm
    cmap = f.getBestCmap()
    gs = f.getGlyphSet()
    hmtx = f["hmtx"]
    try:
        kern = f["kern"].kernTables[0].kernTable
    except Exception:
        kern = {}

    d = []
    cursor = 0.0
    prev = None
    for ch in text:
        gname = cmap.get(ord(ch))
        if gname is None:
            cursor += size * 0.35
            prev = None
            continue
        if prev is not None:
            cursor += kern.get((prev, gname), 0) * scale
        pen = SVGPathPen(gs, ntos=lambda v: f"{v:.2f}")
        tp = TransformPen(pen, Transform(scale, 0, 0, -scale, x + cursor, y))
        gs[gname].draw(tp)
        seg = pen.getCommands()
        if seg:
            d.append(seg)
        cursor += hmtx[gname][0] * scale + tracking
        prev = gname
    return " ".join(d), cursor - tracking


def text_group(text, font_key, size, x, y, fill, anchor="start", tracking=0.0):
    """Devuelve un <path> ya posicionado. anchor: start | middle | end."""
    d, w = text_path(text, font_key, size, 0, 0, tracking)
    if anchor == "middle":
        x -= w / 2
    elif anchor == "end":
        x -= w
    return f'<path transform="translate({x:.2f} {y:.2f})" d="{d}" fill="{fill}"/>', w
