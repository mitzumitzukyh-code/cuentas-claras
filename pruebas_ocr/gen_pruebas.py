#!/usr/bin/env python3
"""Genera imágenes de prueba para el lector de inventario de Cuentas Claras.
Cada imagen simula una foto de teléfono (perspectiva, luz, ruido) y trae
su ground truth exacto en JSON.
"""
import json, math, random, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

random.seed(7)
OUT = "/home/claude/out"
os.makedirs(OUT, exist_ok=True)

F = "/usr/share/fonts/truetype/dejavu/"
def font(name, size):
    return ImageFont.truetype(F + name, size)

SANS   = lambda s: font("DejaVuSans.ttf", s)
SANSB  = lambda s: font("DejaVuSans-Bold.ttf", s)
SERIFB = lambda s: font("DejaVuSerif-Bold.ttf", s)
MONO   = lambda s: font("DejaVuSansMono.ttf", s)

W, H = 1700, 2200  # lienzo tipo hoja carta


def nuevo():
    return Image.new("RGB", (W, H), (252, 251, 248))


def texto(d, xy, s, f, fill=(20, 20, 20), anchor="la"):
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def tabla(d, x, y, cols, filas, ancho_col, f_head, f_cell,
          desalinear_col=None, alto=52, borde=True):
    """cols: lista de encabezados. filas: lista de listas.
    desalinear_col: índice de columna que se dibuja corrida hacia arriba
    (simula el defecto de impresión de la lista real)."""
    xs, acc = [], x
    for w in ancho_col:
        xs.append(acc); acc += w
    total = acc - x

    # encabezado
    if borde:
        d.rectangle([x, y, x + total, y + alto], fill=(228, 228, 228), outline=(0, 0, 0), width=2)
    for i, c in enumerate(cols):
        texto(d, (xs[i] + 10, y + alto // 2), c, f_head, anchor="lm")

    yy = y + alto
    for fila in filas:
        if borde:
            d.rectangle([x, yy, x + total, yy + alto], outline=(90, 90, 90), width=1)
        for i, celda in enumerate(fila):
            if celda is None or celda == "":
                continue
            dy = -alto if (desalinear_col is not None and i == desalinear_col) else 0
            al = "rm" if i >= len(cols) - 2 and _num(celda) else "lm"
            px = xs[i] + (ancho_col[i] - 12) if al == "rm" else xs[i] + 10
            texto(d, (px, yy + alto // 2 + dy), str(celda), f_cell, anchor=al)
        yy += alto
    if borde:
        for xi in xs[1:]:
            d.line([xi, y, xi, yy], fill=(90, 90, 90), width=1)
        d.rectangle([x, y, x + total, yy], outline=(0, 0, 0), width=2)
    return yy


def _num(s):
    return any(ch.isdigit() for ch in str(s))


def foto(img, curl=0.018, brillo=1.0, blur=0.7, rot=1.2):
    """Simula foto de celular: perspectiva leve, viñeta, luz lateral, ruido."""
    img = img.rotate(random.uniform(-rot, rot), expand=True,
                     fillcolor=(240, 238, 233), resample=Image.BICUBIC)
    w, h = img.size
    # perspectiva
    dx = w * curl
    coef = _coef([(0, 0), (w, 0), (w, h), (0, h)],
                 [(dx, dx * 0.6), (w - dx * 0.4, 0), (w, h - dx * 0.5), (dx * 0.3, h)])
    img = img.transform((w, h), Image.PERSPECTIVE, coef,
                        Image.BICUBIC, fillcolor=(236, 233, 228))
    # luz lateral + viñeta
    grad = Image.new("L", (w, h))
    gd = ImageDraw.Draw(grad)
    for i in range(w):
        v = int(255 - 45 * (i / w) ** 1.5)
        gd.line([(i, 0), (i, h)], fill=v)
    img = Image.composite(img, Image.new("RGB", (w, h), (0, 0, 0)), grad)
    px = img.load()
    for _ in range(int(w * h * 0.004)):
        x, y = random.randrange(w), random.randrange(h)
        n = random.randint(-16, 16)
        r, g, b = px[x, y]
        px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    img = img.filter(ImageFilter.GaussianBlur(blur))
    return img


def _coef(pa, pb):
    m = []
    for p1, p2 in zip(pa, pb):
        m.append([p1[0], p1[1], 1, 0, 0, 0, -p2[0] * p1[0], -p2[0] * p1[1]])
        m.append([0, 0, 0, p1[0], p1[1], 1, -p2[1] * p1[0], -p2[1] * p1[1]])
    import numpy as np
    A = np.matrix(m, dtype=float)
    B = np.array(pb).reshape(8)
    return np.array(np.dot(np.linalg.inv(A.T * A) * A.T, B)).reshape(8)


def guardar(img, nombre, gt):
    img = foto(img)
    img.thumbnail((1400, 1900))
    img.save(f"{OUT}/{nombre}.jpg", quality=88)
    with open(f"{OUT}/{nombre}.json", "w", encoding="utf-8") as fh:
        json.dump(gt, fh, ensure_ascii=False, indent=2)
    print("->", nombre)


# ─────────────────────────────────────────────────────────────
# 01 · BODEGA — lista limpia (baseline). Todo debe leerse bien.
# ─────────────────────────────────────────────────────────────
def caso01():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 110), "BODEGA LA ESQUINA", SERIFB(56), anchor="ma")
    texto(d, (W // 2, 180), "Inventario · 15/07/2026", SANS(30), anchor="ma")
    filas = [
        ["Harina PAN 1kg",          "unidad", "48", "1,20"],
        ["Aceite Vatel 1L",         "unidad", "22", "3,50"],
        ["Arroz Primor 1kg",        "unidad", "35", "1,80"],
        ["Azúcar Montalbán 1kg",    "unidad", "40", "1,45"],
        ["Pasta Capri 500g",        "unidad", "60", "0,95"],
        ["Leche en polvo 400g",     "unidad", "18", "4,20"],
        ["Café Fama de América",    "unidad", "25", "2,60"],
        ["Margarina Mavesa 500g",   "unidad", "30", "2,10"],
        ["Atún Margarita lata",     "unidad", "44", "1,75"],
        ["Papel higiénico x4",      "paquete", "27", "2,30"],
        ["Jabón azul Las Llaves",   "unidad", "52", "0,80"],
        ["Refresco 2L",             "unidad", "16", "2,00"],
    ]
    tabla(d, 110, 250, ["DESCRIPCIÓN", "UNIDAD", "CANT.", "PRECIO ($)"],
          filas, [640, 260, 220, 330], SANSB(30), SANS(29))
    gt = {"caso": "01_bodega_limpia", "moneda": "USD", "rubro": "bodega",
          "dificultad": "baja",
          "que_prueba": "Lectura base. Si esto falla, el prompt está roto.",
          "productos": [{"nombre": f[0], "unidad": f[1], "stock": int(f[2]),
                         "precio": float(f[3].replace(",", "."))} for f in filas]}
    guardar(img, "01_bodega_limpia", gt)


# ─────────────────────────────────────────────────────────────
# 02 · COLUMNA DESALINEADA — reproduce el defecto de tu lista real
# ─────────────────────────────────────────────────────────────
def caso02():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 110), "ELECTRÓNICA GLOBAL", SERIFB(52), anchor="ma")
    texto(d, (W // 2, 175), "LISTA DE INVENTARIO — Barinas (Centro)", SANS(28), anchor="ma")
    filas = [
        ["1010", "Smartphone Galaxy X10 128GB", "Telefonía",     "45", "4.500,80"],
        ["1025", "Laptop ApexBook 15\" i7",     "Laptops",       "22", "12.800,00"],
        ["2005", "Monitor Curvo ViewMaster 27\"", "Monitores",   "15", "6.200,00"],
        ["2040", "Auriculares Synch Inalámbricos", "Audio",      "112", "950,00"],
        ["3012", "Tablet TabLink A8 64GB",      "Tablets",       "30", "3.400,00"],
        ["3055", "Cámara DSLR OptiZoom Z5",     "Fotografía",    "8",  "18.900,00"],
        ["4001", "Teclado Mecánico RGB Pro",    "Periféricos",   "28", "1.960,00"],
        ["4015", "Mouse Gaming ViperX",         "Periféricos",   "55", "780,00"],
        ["5002", "Disco Duro Externo 2TB",      "Almacenamiento", "90", "1.600,00"],
        ["5020", "Impresora InkJet LaserPlex",  "Impresoras",    "18", "4.900,00"],
    ]
    tabla(d, 90, 250, ["ID", "DESCRIPCIÓN", "CATEGORÍA", "STOCK", "PRECIO (Bs)"],
          filas, [150, 620, 330, 200, 320], SANSB(28), SANS(27), desalinear_col=4)
    texto(d, (110, 900), "Total Artículos:  423", SANSB(30))
    gt = {"caso": "02_columna_desalineada", "moneda": "VES", "rubro": "electronica",
          "dificultad": "alta",
          "que_prueba": ("La columna PRECIO está impresa corrida una fila hacia arriba. "
                         "El modelo NO debe adivinar: debe marcar precio con confianza baja "
                         "o null + requiereRevision. Nunca 0. El total 423 permite validar "
                         "la suma de stocks."),
          "validacion_cruzada": {"total_articulos_declarado": 423,
                                 "suma_stock_real": sum(int(f[3]) for f in filas)},
          "productos": [{"codigo": f[0], "nombre": f[1], "categoria": f[2],
                         "stock": int(f[3]),
                         "precio_correcto": float(f[4].replace(".", "").replace(",", ".")),
                         "precio_como_aparece_impreso": "corrido una fila arriba"}
                        for f in filas]}
    guardar(img, "02_columna_desalineada", gt)


# ─────────────────────────────────────────────────────────────
# 03 · DATOS FALTANTES — el que causó tus productos en $0
# ─────────────────────────────────────────────────────────────
def caso03():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 110), "QUINCALLERÍA EL SOL", SERIFB(54), anchor="ma")
    texto(d, (W // 2, 180), "Faltan datos a propósito", SANS(28), anchor="ma")
    filas = [
        ["Cuaderno rayado 100h",  "80", "1,50"],
        ["Lápiz grafito HB",      "",   "0,30"],
        ["Borrador blanco",       "45", ""],
        ["Regla 30cm",            "60", "0,75"],
        ["Tijera escolar",        "",   ""],
        ["Pega en barra",         "38", "1,10"],
        ["Marcador permanente",   "52", "—"],
        ["Cartulina blanca",      "?",  "0,60"],
    ]
    tabla(d, 200, 260, ["ARTÍCULO", "CANT.", "PRECIO ($)"],
          filas, [700, 250, 320], SANSB(32), SANS(30))
    gt = {"caso": "03_datos_faltantes", "moneda": "USD", "rubro": "quincalleria",
          "dificultad": "media",
          "que_prueba": ("REGLA DURA: campo ilegible o vacío => null + requiereRevision:true. "
                         "NUNCA 0. Un producto con precio 0 se puede cobrar y regalas mercancía. "
                         "Este caso es el que produjo tus 15 productos en $0,00."),
          "productos": [
              {"nombre": "Cuaderno rayado 100h", "stock": 80, "precio": 1.50},
              {"nombre": "Lápiz grafito HB", "stock": None, "precio": 0.30, "requiereRevision": True},
              {"nombre": "Borrador blanco", "stock": 45, "precio": None, "requiereRevision": True},
              {"nombre": "Regla 30cm", "stock": 60, "precio": 0.75},
              {"nombre": "Tijera escolar", "stock": None, "precio": None, "requiereRevision": True},
              {"nombre": "Pega en barra", "stock": 38, "precio": 1.10},
              {"nombre": "Marcador permanente", "stock": 52, "precio": None, "requiereRevision": True},
              {"nombre": "Cartulina blanca", "stock": None, "precio": 0.60, "requiereRevision": True},
          ],
          "fallo_critico_si": "algún producto sale con precio 0 o stock 0 en vez de null"}
    guardar(img, "03_datos_faltantes", gt)


# ─────────────────────────────────────────────────────────────
# 04 · FILAS DUPLICADAS — prueba de consolidación
# ─────────────────────────────────────────────────────────────
def caso04():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 110), "REPUESTOS MOTOR CENTRO", SERIFB(50), anchor="ma")
    texto(d, (W // 2, 178), "Entrada de mercancía · varios lotes", SANS(28), anchor="ma")
    filas = [
        ["FR-2201", "Filtro de aceite universal", "12", "5,00"],
        ["FR-2201", "Filtro de aceite universal", "8",  "5,00"],
        ["BJ-4410", "Bujía NGK BPR6ES",           "40", "2,25"],
        ["FR-2201", "Filtro de aceite universal", "15", "5,00"],
        ["CR-9002", "Correa de tiempo 8mm",       "6",  "18,00"],
        ["BJ-4410", "Bujía NGK BPR6ES",           "25", "2,25"],
        ["AM-3311", "Amortiguador delantero",     "4",  "45,00"],
        ["FR-2201", "Filtro de aceite universal", "10", "5,00"],
    ]
    tabla(d, 160, 250, ["CÓDIGO OEM", "DESCRIPCIÓN", "CANT.", "PRECIO ($)"],
          filas, [300, 620, 200, 300], SANSB(30), SANS(29))
    gt = {"caso": "04_filas_duplicadas", "moneda": "USD", "rubro": "repuestos",
          "dificultad": "media",
          "que_prueba": ("Consolidar por código OEM antes de crear documentos. "
                         "8 filas => 4 productos. Debe preguntar al usuario antes de unir. "
                         "Este es el bug de las 7 'Impresora InkJet LaserPlex'."),
          "productos_esperados": [
              {"codigoOem": "FR-2201", "nombre": "Filtro de aceite universal",
               "stock": 45, "precio": 5.00, "filas_origen": 4},
              {"codigoOem": "BJ-4410", "nombre": "Bujía NGK BPR6ES",
               "stock": 65, "precio": 2.25, "filas_origen": 2},
              {"codigoOem": "CR-9002", "nombre": "Correa de tiempo 8mm",
               "stock": 6, "precio": 18.00, "filas_origen": 1},
              {"codigoOem": "AM-3311", "nombre": "Amortiguador delantero",
               "stock": 4, "precio": 45.00, "filas_origen": 1},
          ],
          "fallo_si": "se crean 8 documentos separados"}
    guardar(img, "04_filas_duplicadas", gt)


# ─────────────────────────────────────────────────────────────
# 05 · PANADERÍA — vencimiento + peso
# ─────────────────────────────────────────────────────────────
def caso05():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 110), "PANADERÍA LA ESPIGA", SERIFB(54), anchor="ma")
    texto(d, (W // 2, 180), "Producción del día · 03/08/2026", SANS(28), anchor="ma")
    filas = [
        ["Pan canilla",        "kg",     "12,5", "1,80", "04/08/2026"],
        ["Pan campesino",      "unidad", "40",   "1,20", "05/08/2026"],
        ["Golfeado",           "unidad", "35",   "1,00", "04/08/2026"],
        ["Cachito de jamón",   "unidad", "60",   "1,50", "03/08/2026"],
        ["Torta de chocolate", "kg",     "8,0",  "9,00", "06/08/2026"],
        ["Quesillo porción",   "unidad", "24",   "2,00", "05/08/2026"],
        ["Pan de sándwich",    "unidad", "18",   "2,40", "08/08/2026"],
        ["Harina de trigo",    "kg",     "50",   "0,90", "12/2026"],
    ]
    tabla(d, 100, 250, ["PRODUCTO", "UNIDAD", "CANT.", "PRECIO ($)", "VENCE"],
          filas, [480, 240, 220, 300, 380], SANSB(29), SANS(28))
    gt = {"caso": "05_panaderia_vencimiento", "moneda": "USD", "rubro": "panaderia",
          "dificultad": "media",
          "que_prueba": ("Unidades mixtas kg/unidad en la misma lista (decimales con coma) "
                         "y campo extra 'vencimiento'. Ojo: la última fila trae solo mes/año."),
          "productos": [{"nombre": f[0], "unidad": f[1],
                         "stock": float(f[2].replace(",", ".")),
                         "precio": float(f[3].replace(",", ".")),
                         "vencimiento": f[4]} for f in filas]}
    guardar(img, "05_panaderia_vencimiento", gt)


# ─────────────────────────────────────────────────────────────
# 06 · ROPA — talla y color como variantes
# ─────────────────────────────────────────────────────────────
def caso06():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 110), "BOUTIQUE MARÍA FERNANDA", SERIFB(48), anchor="ma")
    texto(d, (W // 2, 178), "Inventario por talla", SANS(28), anchor="ma")
    filas = [
        ["Franela básica algodón", "S",  "Blanco", "12", "8,00"],
        ["Franela básica algodón", "M",  "Blanco", "18", "8,00"],
        ["Franela básica algodón", "L",  "Negro",  "10", "8,00"],
        ["Jean clásico dama",      "M",  "Azul",   "7",  "22,00"],
        ["Jean clásico dama",      "L",  "Azul",   "5",  "22,00"],
        ["Vestido casual",         "S",  "Beige",  "4",  "35,00"],
        ["Vestido casual",         "M",  "Coral",  "6",  "35,00"],
        ["Chaqueta jean",          "XL", "Azul",   "3",  "40,00"],
    ]
    tabla(d, 120, 250, ["PRENDA", "TALLA", "COLOR", "CANT.", "PRECIO ($)"],
          filas, [560, 200, 280, 200, 320], SANSB(29), SANS(28))
    gt = {"caso": "06_ropa_variantes", "moneda": "USD", "rubro": "ropa",
          "dificultad": "media",
          "que_prueba": ("Mismo nombre + distinta talla/color = variantes de UN producto, "
                         "no productos separados. Contrasta con el caso 04 (ahí sí se suman). "
                         "Aquí NO se suman los stocks: cada variante mantiene el suyo."),
          "productos_esperados": [
              {"nombre": "Franela básica algodón", "precio": 8.00, "variantes": [
                  {"talla": "S", "color": "Blanco", "stock": 12},
                  {"talla": "M", "color": "Blanco", "stock": 18},
                  {"talla": "L", "color": "Negro", "stock": 10}]},
              {"nombre": "Jean clásico dama", "precio": 22.00, "variantes": [
                  {"talla": "M", "color": "Azul", "stock": 7},
                  {"talla": "L", "color": "Azul", "stock": 5}]},
              {"nombre": "Vestido casual", "precio": 35.00, "variantes": [
                  {"talla": "S", "color": "Beige", "stock": 4},
                  {"talla": "M", "color": "Coral", "stock": 6}]},
              {"nombre": "Chaqueta jean", "precio": 40.00, "variantes": [
                  {"talla": "XL", "color": "Azul", "stock": 3}]},
          ]}
    guardar(img, "06_ropa_variantes", gt)


# ─────────────────────────────────────────────────────────────
# 07 · MANUSCRITO — cuaderno, el caso más común de verdad
# ─────────────────────────────────────────────────────────────
def caso07():
    img = Image.new("RGB", (1400, 1900), (253, 250, 236)); d = ImageDraw.Draw(img)
    for y in range(240, 1880, 66):
        d.line([(90, y), (1330, y)], fill=(178, 200, 216), width=2)
    d.line([(180, 60), (180, 1880)], fill=(224, 158, 158), width=3)
    hand = font("DejaVuSerif.ttf", 40)
    texto(d, (220, 130), "Mercancia que queda - lunes", font("DejaVuSerif-BoldItalic.ttf", 44),
          fill=(38, 52, 96))
    items = [
        ("Harina pan", "24", "1,20"), ("Aceite", "9", "3,50"),
        ("Arroz", "30", "1,80"), ("Azucar", "17", "1,45"),
        ("Cafe", "12", "2,60"), ("Leche", "6", "4,20"),
        ("Pasta", "41", "0,95"), ("Atun", "22", "1,75"),
        ("Jabon", "35", "0,80"), ("Papel bano", "14", "2,30"),
        ("Mayonesa", "8", "2,90"), ("Salsa tomate", "19", "1,60"),
    ]
    y = 300
    gtp = []
    for n, c, p in items:
        jitter = random.randint(-6, 6)
        texto(d, (220, y + jitter), n, hand, fill=(28, 40, 92))
        texto(d, (760, y + jitter), c, hand, fill=(28, 40, 92))
        texto(d, (980, y + jitter), p, hand, fill=(28, 40, 92))
        gtp.append({"nombre": n, "stock": int(c), "precio": float(p.replace(",", "."))})
        y += 66
    gt = {"caso": "07_manuscrito_cuaderno", "moneda": "USD", "rubro": "bodega",
          "dificultad": "alta",
          "que_prueba": ("El formato REAL del bodeguero venezolano: cuaderno rayado, "
                         "sin encabezados, sin acentos, columnas implícitas por posición. "
                         "El modelo debe inferir que col2=cantidad y col3=precio "
                         "(pista: los valores con coma decimal son precios)."),
          "productos": gtp}
    guardar(img, "07_manuscrito_cuaderno", gt)


# ─────────────────────────────────────────────────────────────
# 08 · FACTURA CON IVA — no es inventario, debe rechazarla o tratarla como gasto
# ─────────────────────────────────────────────────────────────
def caso08():
    img = nuevo(); d = ImageDraw.Draw(img)
    texto(d, (W // 2, 100), "FACTURA", SERIFB(64), anchor="ma")
    texto(d, (W // 2, 175), "DISTRIBUIDORA CENTRAL, C.A.", SANSB(34), anchor="ma")
    texto(d, (W // 2, 220), "RIF: J-30456789-1  ·  Barinas, Venezuela", SANS(26), anchor="ma")
    d.line([(100, 265), (W - 100, 265)], fill=(0, 0, 0), width=2)
    texto(d, (110, 300), "FACTURA N°: 001872", SANSB(28))
    texto(d, (110, 345), "FECHA: 28/07/2026", SANSB(28))
    texto(d, (110, 390), "CLIENTE: Bodega La Esquina", SANS(28))
    filas = [
        ["24", "Harina PAN 1kg",       "0,95",  "22,80"],
        ["12", "Aceite Vatel 1L",      "2,80",  "33,60"],
        ["30", "Pasta Capri 500g",     "0,70",  "21,00"],
        ["10", "Atún Margarita lata",  "1,30",  "13,00"],
    ]
    yy = tabla(d, 110, 440, ["CANT.", "DESCRIPCIÓN", "P. UNIT. ($)", "TOTAL ($)"],
               filas, [180, 700, 300, 300], SANSB(28), SANS(28))
    yy += 20
    for lbl, val in [("SUBTOTAL:", "90,40"), ("IVA (16%):", "14,46"), ("TOTAL:", "104,86")]:
        texto(d, (1180, yy), lbl, SANSB(30), anchor="ra")
        texto(d, (1580, yy), "$ " + val, SANSB(30), anchor="ra")
        yy += 48
    texto(d, (110, yy + 60), "FORMA DE PAGO: Transferencia · Pago Móvil", SANS(26))
    gt = {"caso": "08_factura_compra", "moneda": "USD", "rubro": "bodega",
          "dificultad": "alta",
          "que_prueba": ("Esto NO es una lista de inventario, es una factura de COMPRA. "
                         "Comportamiento correcto: detectar el tipo de documento y ofrecer "
                         "'registrar como gasto' ($104,86) o 'sumar al inventario a precio de "
                         "COSTO'. Fallo grave: cargar los precios de costo como precios de VENTA."),
          "tipo_documento": "factura_compra",
          "gasto_total": 104.86, "subtotal": 90.40, "iva": 14.46,
          "lineas": [{"cantidad": int(f[0]), "nombre": f[1],
                      "precio_costo": float(f[2].replace(",", ".")),
                      "total": float(f[3].replace(",", "."))} for f in filas],
          "fallo_critico_si": "usa precio_costo como precio de venta sin avisar"}
    guardar(img, "08_factura_compra", gt)


for f in (caso01, caso02, caso03, caso04, caso05, caso06, caso07, caso08):
    f()

# índice maestro
idx = []
for n in sorted(os.listdir(OUT)):
    if n.endswith(".json"):
        with open(f"{OUT}/{n}", encoding="utf-8") as fh:
            j = json.load(fh)
        idx.append({"imagen": n.replace(".json", ".jpg"), "caso": j["caso"],
                    "rubro": j["rubro"], "dificultad": j["dificultad"],
                    "que_prueba": j["que_prueba"]})
with open(f"{OUT}/_indice.json", "w", encoding="utf-8") as fh:
    json.dump(idx, fh, ensure_ascii=False, indent=2)
print("listo")
