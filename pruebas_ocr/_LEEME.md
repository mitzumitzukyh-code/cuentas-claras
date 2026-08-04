# Set de prueba — Lector de inventario (Cuentas Claras)

8 imágenes que simulan fotos de teléfono (perspectiva, luz lateral, ruido, blur),
cada una con su **ground truth exacto** en JSON.

## Cómo usarlo

1. Sube la imagen `NN_*.jpg` desde *Importar inventario → Foto de tu lista*.
2. Guarda lo que devolvió el Worker.
3. Compara contra `NN_*.json` (campo `productos` / `productos_esperados`).
4. Un caso pasa solo si **nombre, stock y precio** coinciden en todos los ítems.

## Los casos

| # | Caso | Dificultad | Qué rompe si falla |
|---|---|---|---|
| 01 | Bodega limpia | Baja | Todo. Es el baseline: si falla, el prompt está mal, no la imagen. |
| 02 | Columna desalineada | Alta | Precios corridos una fila. Reproduce el defecto de tu lista real. |
| 03 | Datos faltantes | Media | **El bug de los $0,00.** Campo ilegible debe ser `null`, nunca `0`. |
| 04 | Filas duplicadas | Media | **El bug de las 7 impresoras.** Consolidar por código, no crear 8 docs. |
| 05 | Panadería + vencimiento | Media | Unidades mixtas kg/unidad, decimales con coma, campo extra. |
| 06 | Ropa con tallas | Media | Variantes de un producto ≠ productos distintos. Contrasta con el 04. |
| 07 | Manuscrito en cuaderno | Alta | El formato real del bodeguero. Sin encabezados, columnas por posición. |
| 08 | Factura de compra | Alta | No es inventario. Precio de COSTO ≠ precio de VENTA. |

## Los tres que más importan

**03** es el que te produjo los 15 productos en `$0,00`. La regla es dura:
si el modelo no puede leer un valor con confianza, devuelve `null` +
`requiereRevision: true`. Un producto en $0 se puede cobrar.

**04 vs 06** es una distinción sutil y el modelo tiene que acertarla:
en el 04 las filas repetidas se **suman** (mismo repuesto, varios lotes).
En el 06 las filas repetidas son **variantes** y cada una mantiene su stock.
La pista es si hay columna de talla/color.

**08** es trampa a propósito. Si la app carga $0,95 como precio de venta de la
Harina PAN, el bodeguero vende a costo y no se entera.

## Validación cruzada

El caso 02 trae `Total Artículos: 423`. Si la suma de stocks leídos no da 423,
la importación completa debe marcarse como dudosa. Ese chequeo barato atrapa
la mayoría de lecturas malas.

## Qué debe devolver el Worker (contrato sugerido)

```json
{
  "tipoDocumento": "inventario | factura_compra | desconocido",
  "moneda": "USD | VES",
  "confianzaGeneral": "alta | media | baja",
  "totalDeclarado": 423,
  "productos": [
    {
      "nombre": "Smartphone Galaxy X10 128GB",
      "codigo": "1010",
      "stock": 45,
      "precio": null,
      "unidad": "unidad",
      "extras": { "categoria": "Telefonía" },
      "confianza": { "nombre": "alta", "stock": "alta", "precio": "baja" },
      "requiereRevision": true
    }
  ],
  "advertencias": ["La columna de precios parece desalineada respecto a las filas."]
}
```

## Regenerar

`python3 gen_pruebas.py` — semilla fija (`random.seed(7)`), así que las
imágenes salen idénticas cada vez. Cambia la semilla para variantes nuevas.
