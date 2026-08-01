# -*- coding: utf-8 -*-
"""Tokens de marca — Cuentas Claras"""

C = {
    "esmeralda":    "#0F9D82",
    "esmeralda_osc":"#0B7A66",
    "azul_noche":   "#1B3A4B",
    "blanco_hueso": "#F7F9F7",
    "ambar":        "#F2A93B",
    "gris_piedra":  "#8A9A96",
    "coral":        "#E8705A",   # linea de margen de la libreta
    "grad_a":       "#8C2F22",
    "grad_b":       "#5A3A28",
    "grad_c":       "#0E9F6E",
    "papel":        "#FDFCF8",
    "raya":         "#DCE5E2",
    "sobre_acento": "#FFFFFF",   # blanco sobre esmeralda/ámbar: no se invierte en dark
}

ICON_BOX = 24
SW = 1.7  # stroke-width base


def stroke_icon(paths, extra="", box=24, sw=SW):
    """Envuelve path data en un SVG de icono monocromo (currentColor)."""
    body = "\n    ".join(paths)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {box} {box}" width="{box}" height="{box}" fill="none"
     stroke="currentColor" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">
    {body}{extra}
</svg>
'''


# ---------------------------------------------------------------- NAVEGACION
NAV = {
    # casa con renglones de libreta adentro
    "inicio": [
        '<path d="M3.4 10.6 12 3.8l8.6 6.8"/>',
        '<path d="M5.8 9.5v9.7a1.6 1.6 0 0 0 1.6 1.6h9.2a1.6 1.6 0 0 0 1.6-1.6V9.5"/>',
        '<path d="M9.4 14.2h5.2M9.4 17h5.2"/>',
    ],
    # bolsa de compras
    "ventas": [
        '<path d="M5.6 8.4h12.8l-1.05 11.1a1.7 1.7 0 0 1-1.7 1.5H8.35a1.7 1.7 0 0 1-1.7-1.5z"/>',
        '<path d="M9 8.4V6.5a3 3 0 0 1 6 0v1.9"/>',
    ],
    # caja isometrica
    "productos": [
        '<path d="M12 3.4 20.4 8v8L12 20.6 3.6 16V8z"/>',
        '<path d="M3.6 8 12 12.6 20.4 8"/>',
        '<path d="M12 12.6v8"/>',
    ],
    # dos personas
    "clientes": [
        '<circle cx="9.6" cy="8.3" r="3.3"/>',
        '<path d="M3.7 19.6a5.9 5.9 0 0 1 11.8 0"/>',
        '<path d="M16.4 5.9a3.3 3.3 0 0 1 0 6.3"/>',
        '<path d="M17.6 14.3a5.6 5.6 0 0 1 2.9 5.3"/>',
    ],
    # barras
    "reportes": [
        '<path d="M3.8 20.2h16.4"/>',
        '<path d="M7.4 20.2v-4.8M12 20.2v-9.4M16.6 20.2v-6.6" stroke-width="2.1"/>',
    ],
    # mas / menu
    "mas": [
        '<circle cx="5.2" cy="12" r="1.5" fill="currentColor" stroke="none"/>',
        '<circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/>',
        '<circle cx="18.8" cy="12" r="1.5" fill="currentColor" stroke="none"/>',
    ],
}

# ---------------------------------------------------------------- ACCIONES
ACCIONES = {
    "agregar": [
        '<circle cx="12" cy="12" r="8.6"/>',
        '<path d="M12 8.2v7.6M8.2 12h7.6"/>',
    ],
    "editar": [
        '<path d="M16.3 4.5a1.9 1.9 0 0 1 2.7 0l1.1 1.1a1.9 1.9 0 0 1 0 2.7L9.3 18.9l-4.5 1.2 1.2-4.5z"/>',
        '<path d="M14.8 6.1l3.4 3.4"/>',
    ],
    "eliminar": [
        '<path d="M4.6 6.8h14.8"/>',
        '<path d="M9.3 6.8V5.4a1.4 1.4 0 0 1 1.4-1.4h2.6a1.4 1.4 0 0 1 1.4 1.4v1.4"/>',
        '<path d="M6.7 6.8l.85 12.1a1.7 1.7 0 0 0 1.7 1.6h5.5a1.7 1.7 0 0 0 1.7-1.6l.85-12.1"/>',
        '<path d="M10.4 10.6v5.8M13.6 10.6v5.8"/>',
    ],
    "buscar": [
        '<circle cx="10.6" cy="10.6" r="6.5"/>',
        '<path d="M15.3 15.3 20 20"/>',
    ],
    "filtrar": [
        '<path d="M4.2 5.6h15.6l-5.9 7v6.1l-3.8 2v-8.1z"/>',
    ],
    "compartir": [
        '<circle cx="17.8" cy="5.8" r="2.6"/>',
        '<circle cx="6.2" cy="12" r="2.6"/>',
        '<circle cx="17.8" cy="18.2" r="2.6"/>',
        '<path d="M8.5 10.7 15.5 7.1M8.5 13.3l7 3.6"/>',
    ],
    "mensaje": [
        '<path d="M20.3 11.7a8 8 0 0 1-11.6 7.1L4 20.3l1.5-4.6A8 8 0 1 1 20.3 11.7z"/>',
        '<path d="M8.8 11.9h.02M12.1 11.9h.02M15.4 11.9h.02" stroke-width="2.2"/>',
    ],
    "camara": [
        '<path d="M3.7 8.4h3.2l1.6-2.5h5.8l1.6 2.5h3.2a1.7 1.7 0 0 1 1.7 1.7v8a1.7 1.7 0 0 1-1.7 1.7H3.7A1.7 1.7 0 0 1 2 18.1v-8a1.7 1.7 0 0 1 1.7-1.7z"/>',
        '<circle cx="12" cy="13.9" r="3.4"/>',
    ],
    "calendario": [
        '<rect x="3.4" y="5.3" width="17.2" height="15.3" rx="2.1"/>',
        '<path d="M3.4 10.2h17.2"/>',
        '<path d="M8.3 3.4v3.8M15.7 3.4v3.8"/>',
        '<path d="M8 14h.02M12 14h.02M16 14h.02M8 17.4h.02M12 17.4h.02" stroke-width="2"/>',
    ],
    "exportar": [
        '<path d="M12 3.6v10.8"/>',
        '<path d="M8.1 10.7 12 14.6l3.9-3.9"/>',
        '<path d="M4.4 16.2v2.6a2 2 0 0 0 2 2h11.2a2 2 0 0 0 2-2v-2.6"/>',
    ],
    "cerrar": [
        '<path d="M6.4 6.4 17.6 17.6M17.6 6.4 6.4 17.6"/>',
    ],
    "confirmar": [
        '<path d="M4.8 12.5 9.7 17.4 19.2 6.9"/>',
    ],
    "alerta": [
        '<path d="M13.4 4.6a1.6 1.6 0 0 0-2.8 0L2.8 18.7a1.6 1.6 0 0 0 1.4 2.4h15.6a1.6 1.6 0 0 0 1.4-2.4z"/>',
        '<path d="M12 9.6v4.8"/>',
        '<path d="M12 17.7h.02" stroke-width="2.3"/>',
    ],
    "ajustes": [
        '<path d="M4 7.6h3.6M12.4 7.6h7.6M4 16.4h7.6M16.4 16.4H20"/>',
        '<circle cx="10" cy="7.6" r="2.4"/>',
        '<circle cx="14" cy="16.4" r="2.4"/>',
    ],
    "efectivo": [
        '<rect x="2.6" y="6.3" width="18.8" height="11.4" rx="1.9"/>',
        '<circle cx="12" cy="12" r="2.8"/>',
        '<path d="M6 12h.02M18 12h.02" stroke-width="2.2"/>',
    ],
    "pago-movil": [
        '<rect x="6.6" y="2.6" width="10.8" height="18.8" rx="2.3"/>',
        '<path d="M10.4 18.6h3.2"/>',
        '<path d="M12 7v6.4"/>',
        '<path d="M9.8 11.2 12 13.4l2.2-2.2"/>',
    ],
    "pendiente": [
        '<circle cx="12" cy="12" r="8.5"/>',
        '<path d="M12 7.2V12l3.3 2"/>',
    ],
    "escanear": [
        '<path d="M3.4 8.6V5.6a2.2 2.2 0 0 1 2.2-2.2h3M15.4 3.4h3a2.2 2.2 0 0 1 2.2 2.2v3M20.6 15.4v3a2.2 2.2 0 0 1-2.2 2.2h-3M8.6 20.6h-3a2.2 2.2 0 0 1-2.2-2.2v-3"/>',
        '<path d="M3.4 12h17.2" stroke-width="1.9"/>',
    ],
    "inventario": [
        '<rect x="3.4" y="3.6" width="7.2" height="7.2" rx="1.5"/>',
        '<rect x="13.4" y="3.6" width="7.2" height="7.2" rx="1.5"/>',
        '<rect x="3.4" y="13.2" width="7.2" height="7.2" rx="1.5"/>',
        '<path d="M17 13.2v7.2M13.4 16.8h7.2"/>',
    ],
}

# ---------------------------------------------------------------- CATEGORIAS
CATEGORIAS = {
    "bodega": [
        '<path d="M4.4 9.6v9.6a1.5 1.5 0 0 0 1.5 1.5h12.2a1.5 1.5 0 0 0 1.5-1.5V9.6"/>',
        '<path d="M2.6 9.6 4.5 4.4h15l1.9 5.2z"/>',
        '<path d="M9.6 20.7v-6.1h4.8v6.1"/>',
    ],
    "ropa": [
        '<path d="M8.9 3.6 4.4 6.2l1.9 4.2 2-.85V19.4a1.6 1.6 0 0 0 1.6 1.6h4.2a1.6 1.6 0 0 0 1.6-1.6V9.55l2 .85 1.9-4.2-4.5-2.6"/>',
        '<path d="M8.9 3.6a3.2 3.2 0 0 0 6.2 0"/>',
    ],
    "panaderia": [
        '<path d="M4.3 13.6c0-3.7 3.45-6.4 7.7-6.4s7.7 2.7 7.7 6.4v3.4a1.7 1.7 0 0 1-1.7 1.7H6a1.7 1.7 0 0 1-1.7-1.7z"/>',
        '<path d="M9 10.7 7.7 13.4M12.4 10.3l-1.3 2.7M15.8 10.7l-1.3 2.7"/>',
    ],
    "farmacia": [
        '<path d="M9.8 3.8h4.4a.9.9 0 0 1 .9.9v4.2h4.2a.9.9 0 0 1 .9.9v4.4a.9.9 0 0 1-.9.9h-4.2v4.2a.9.9 0 0 1-.9.9H9.8a.9.9 0 0 1-.9-.9v-4.2H4.7a.9.9 0 0 1-.9-.9V9.8a.9.9 0 0 1 .9-.9h4.2V4.7a.9.9 0 0 1 .9-.9z"/>',
    ],
    "ferreteria": [
        '<path d="M14.6 6.2a1 1 0 0 0 0 1.4l1.8 1.8a1 1 0 0 0 1.4 0l4.1-4.1a6.2 6.2 0 0 1-8.2 8.2l-7.1 7.1a2.2 2.2 0 0 1-3.1-3.1l7.1-7.1a6.2 6.2 0 0 1 8.2-8.2z"/>',
    ],
    "belleza": [
        '<rect x="8.5" y="12.6" width="7" height="8" rx="1.6"/>',
        '<path d="M8.5 15.4h7"/>',
        '<path d="M9.7 12.6V7.5l4.1-3.3a.85.85 0 0 1 1.5.66v7.74z"/>',
    ],
    "comida": [
        '<path d="M7.4 3.4v4.2M10 3.4v4.2M12.6 3.4v4.2"/>',
        '<path d="M7.4 7.4a2.6 2.6 0 0 0 5.2 0"/>',
        '<path d="M10 10v10.6"/>',
        '<path d="M17.4 20.6v-8.4h-1.1c-1.5-2.6-1.2-6.9 1.1-8.8z"/>',
    ],
    "tecnologia": [
        '<rect x="6.4" y="6.4" width="11.2" height="11.2" rx="2"/>',
        '<rect x="9.9" y="9.9" width="4.2" height="4.2" rx="1"/>',
        '<path d="M9.4 3.4v3M14.6 3.4v3M9.4 17.6v3M14.6 17.6v3M3.4 9.4h3M3.4 14.6h3M17.6 9.4h3M17.6 14.6h3"/>',
    ],
    "licoreria": [
        '<path d="M10.1 3.4h3.8v3.1l2.3 3.1a3.2 3.2 0 0 1 .64 1.92V18.9a1.7 1.7 0 0 1-1.7 1.7H8.86a1.7 1.7 0 0 1-1.7-1.7v-7.38a3.2 3.2 0 0 1 .64-1.92l2.3-3.1z"/>',
        '<path d="M7.16 14.2h9.68"/>',
    ],
    "servicios": [
        '<rect x="3" y="7.4" width="18" height="12.6" rx="2.1"/>',
        '<path d="M8.6 7.4V5.8a1.9 1.9 0 0 1 1.9-1.9h3a1.9 1.9 0 0 1 1.9 1.9v1.6"/>',
        '<path d="M3 12.4h18"/>',
    ],
    "otros": [
        '<circle cx="12" cy="12" r="8.5"/>',
        '<path d="M8.4 12h.02M12 12h.02M15.6 12h.02" stroke-width="2.3"/>',
    ],
}
