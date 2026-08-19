# Plan — Cuenta Clara para una costurera

> Adaptar la app al trabajo de una costurera que hace **arreglos y ajustes**
> (ruedos, cierres, ajustar tallas) y **confección a la medida** (corta y cose
> la prenda completa).
>
> Estado: propuesta, sin código escrito. Nada de esto exige migrar datos: todo
> es aditivo y los negocios que ya existen siguen funcionando igual.

---

## 0. El desajuste de fondo

La app asume, en todo su núcleo, que **lo que se cobra es una cosa que sale del
inventario**. Una costurera no vende cosas: vende trabajo, con una fecha de
entrega y un anticipo de por medio. Ese es el único desajuste real — todo lo
demás ya le sirve.

### Lo que ya le sirve tal cual

| Necesidad | Dónde está hoy |
|---|---|
| Clientes con deuda y abonos | `features/fiados/` |
| Anticipo (le pagan antes de entregar) | `ClienteFiado.aFavor` ya distingue "te debo" de "no me debes" ([cliente_fiado.dart:50](lib/features/fiados/domain/cliente_fiado.dart:50)) |
| Presupuesto / cotización | `Routes.cobrarCotizacion` — el carrito de Cobrar en modo cotización |
| Gastos (tela, hilo, pasaje) | `features/gastos/` |
| Telas e hilos por metro | `features/productos` + `Routes.insumos`, hoy encendido solo en Comida rápida |
| Reportes, cierre de caja, catálogo | Ya construidos |
| Venta a crédito | `VentaRepository.registrarVenta(..., fiadoA:)` |

### Lo que falta

1. **No hay rubro de costura.** Cae en `Rubro.otro`, que le habla de
   "productos" y "Mercancía".
2. **Un servicio no es inventario.** "Ruedo de pantalón · $3" hoy hay que
   crearlo como producto: la lista le dirá "quedan 0", le saltará la alerta de
   stock bajo, y cada cobro dejará el stock en −1, −2, −3.
3. **Encargos: no existe nada.** Cliente + prenda + medidas + fecha prometida +
   anticipo + estado. Es el corazón de su día y es un módulo nuevo.
4. **Medidas del cliente.** Hoy no hay dónde guardarlas.

---

## Fase 0 — Rubro `costura`

**Archivos:** `rubro.dart`, `business_presets.dart`. Nada más — es exactamente
lo que promete `CLAUDE.md` §8.b: un valor en el enum y una entrada en el mapa.

```
Rubro.costura
  id        'costura'          // viaja al Worker sin cambios
  etiqueta  'Costura / Confección'
  color     nuevo (no reusar el coral de Ropa: la cuadrícula se recorre por color)
  icono     AppAssets.catServicios   // ya existe en el paquete y nadie lo usa
  categoriasSugeridas  ['Arreglos', 'Confección', 'Uniformes', 'Telas y materiales']
```

```
_costura = BusinessProfile(
  defaultUnit:      'unidad',
  allowedUnits:     ['unidad', 'metro', 'hora'],   // 'metro' es nuevo
  vocab:            trabajo / trabajos / 'Trabajos' / 'Agregar trabajo',
  shortcuts:        [_cobrar, _encargos, _cotizar],
  usaUnidadMedida:  true,     // enciende Insumos: telas por metro, botones por unidad
  usaVariantes:     false,    // un ruedo no tiene tallas
  usaReceta:        false,    // ver decisión abierta nº3
  fotoObligatoria:  false,    // útil (el modelo que trajo la clienta), no obligatoria
)
```

**Vocabulario: por qué "Trabajos" y no "Mercancía".** Su lista de precios son
servicios ("ruedo", "cierre", "vestido de dama"). Las telas y los hilos **no**
van ahí: van a Insumos, que es otra pantalla y ya existe. Separarlos evita que
una lista mezcle lo que cobra con lo que gasta.

**Esfuerzo:** media hora. Sin esta fase, ella entra por "Otro" y todo lo demás
igual funciona; es cosmético pero es lo que hace que la app se sienta suya.

---

## Fase 1 — `TipoProducto.servicio`

El enum `TipoProducto` ya existe (`simple | variantes | serial`) y `fromId` cae
a `simple` ante cualquier valor desconocido, así que **agregar un valor es
retrocompatible por construcción**.

**Qué significa `servicio`:**

- No se pide cantidad ni umbral de alerta al crearlo.
- **No descuenta stock al vender.**
- No aparece en alertas de stock bajo, ni en el arqueo de inventario.
- La ficha muestra el precio donde los demás muestran "quedan X".
- Sí entra al carrito de Cobrar, a Cotizar y al catálogo.

**Puntos a tocar** (verificar cada uno al implementar, la lista sale de un
grep y puede quedarse corta):

- `producto.dart` — el valor del enum; `stockBajo`, `cantidadLabel` y
  `cantidadCon` respetándolo.
- `venta_repository.dart` — los cuatro `FieldValue.increment` de stock
  ([:261](lib/features/ventas/data/venta_repository.dart:261),
  [:294](lib/features/ventas/data/venta_repository.dart:294),
  [:338](lib/features/ventas/data/venta_repository.dart:338),
  [:467](lib/features/ventas/data/venta_repository.dart:467)). Los cuatro,
  no solo el obvio: ahí están el camino sin conexión y la restitución al
  anular. Saltarse uno deja el stock desviado justo en el caso raro.
- `cobrar_screen.dart` — `agotada` ([:294](lib/features/ventas/presentation/cobrar_screen.dart:294)) y la validación de [:773](lib/features/ventas/presentation/cobrar_screen.dart:773).
- `nuevo_producto_screen.dart` — esconder cantidad, alerta y "bloquear al agotarse".
- Dashboard / `urgencias.dart` / arqueo de inventario / lista de mercancía.

**Esto no es solo para costura.** Una bodega que cobra recargas telefónicas y
una quincallería que hace copias de llave tienen el mismo problema hoy.

**Esfuerzo:** media sesión. Con la Fase 0 y esta, ella ya puede cobrar sin que
la app se vea rota.

---

## Fase 2 — Medidas del cliente

`ClienteFiado` gana dos campos, ambos con valor por defecto (sin migración):

```
medidas: Map<String, dynamic>   // { 'busto': 92, 'cintura': 74, ... }
notas:   String?                // "prefiere la manga larga", "es zurda"
```

Una sección "Medidas" en el detalle del cliente, con los campos habituales
(busto, cintura, cadera, largo, hombro, manga, tiro) **más campos libres**: cada
costurera toma las suyas y una lista cerrada sería una jaula — el mismo criterio
de `ExtraField.allowsCustom`.

Las reglas de Firestore ya lo cubren (`clientes` admite `update` de cualquier
miembro). Cero cambios ahí.

**Esfuerzo:** corto. 1 modelo + 1 sección de UI.

---

## Fase 3 — Encargos

El módulo. Lo que de verdad le cambia el día.

### Datos

```
negocios/{negocioId}/encargos/{encargoId}
  clienteId, clienteNombre        // denormalizado, como negocioId en movimientos
  descripcion                     // "vestido de graduación, tela azul"
  prendas[]: { nombre, cantidad, precioUSD }
  totalUSD, abonadoUSD            // abonadoUSD denormalizado (FieldValue.increment)
  recibidoEn, prometidoEn         // prometidoEn = fecha de entrega
  estado: recibido | enProceso | listo | entregado | cancelado
  medidasUsadas                   // foto de las medidas al recibir el encargo
  fotoUrl                         // el modelo que trajo la clienta
  notas
  creadoPor, actualizadoEn
  ventaId                         // se llena al entregar

negocios/{negocioId}/encargos/{encargoId}/abonos/{abonoId}
  montoUSD, fecha, metodo, registradoPor
  nunca se edita ni se borra (libro mayor)
```

**`medidasUsadas` es una foto, no un puntero.** Las medidas de una clienta
cambian; el vestido que se cortó en marzo se cortó con las de marzo. Es la misma
razón por la que `gasto.tasaUsada` se congela (`CLAUDE.md` §8.c.2).

### La decisión importante: el anticipo vive en el encargo, no en Fiados

Un anticipo **no** es un saldo a favor genérico: está atado a un trabajo
concreto. Si se mete por Fiados, el saldo de la clienta sale en negativo ("te
debo $20") y el encargo no sabe cuánto lleva pagado.

**Al entregar**, el encargo se convierte en venta:

1. Se registra una `Venta` con las prendas del encargo, por
   `VentaRepository.registrarVenta` — que ya sabe descontar insumos y anotar
   fiado.
2. Lo ya abonado se descuenta del total. Si queda saldo, se pasa a Fiados con
   `fiadoA:`, que ya existe.
3. El encargo pasa a `entregado` y guarda su `ventaId`.

Así **`ventas` sigue siendo la única verdad de "cuánto vendí"** y ni Reportes ni
el Cierre de caja cuentan el mismo dinero dos veces.

**Cuidado con el arqueo.** El abono de hoy sí es plata que entró en la caja hoy,
pero no es una venta. El cierre tiene que contarlo en una línea propia
(`abonosEncargosUSD`) o el arqueo saldrá descuadrado por dinero que sí está en
la gaveta. Es exactamente el tropiezo que ya costó el flag `importado` en los
fiados ([fiado_repository.dart:309](lib/features/fiados/data/fiado_repository.dart:309)).

### Pantallas

1. **Encargos** (`/encargos`) — la que abre por la mañana. Agrupada por urgencia:
   **Atrasados · Para hoy · Esta semana · Más adelante**. No por estado: lo que
   la despierta es la fecha.
2. **Nuevo encargo** (`/encargos/nuevo`) — cliente (reusa
   `buscarOCrearCliente`), prendas, precio, abono inicial, fecha prometida,
   foto, notas.
3. **Detalle** (`/encargos/:encargoId`) — estado en botones grandes (Empezado /
   Listo / Entregado), historial de abonos, "Abonar", "Avisar que está listo"
   por WhatsApp (el patrón ya está en `mensajes_fiado.dart`), y "Entregar y
   cobrar".

**Trampa de rutas:** `/encargos/nuevo` casa con `/encargos/:encargoId` y abriría
el detalle de un encargo llamado "nuevo". Es el tropiezo ya documentado en
[routes.dart:48](lib/app/router/routes.dart:48). Se declara la ruta literal
antes que la paramétrica, o se saca del prefijo.

### Reglas de Firestore

```
match /encargos/{encargoId} {
  allow read:   if esMiembro(negocioId);
  allow create: if esMiembro(negocioId);
  allow update: if esMiembro(negocioId);
  allow delete: if false;              // se cancela, no se borra

  match /abonos/{abonoId} {
    allow read:          if esMiembro(negocioId);
    allow create:        if esMiembro(negocioId);
    allow update, delete: if false;    // libro mayor
  }
}
```

**Sin índice compuesto:** `orderBy('prometidoEn')` en la consulta y el filtro de
estado en Dart, igual que se hace con `eliminado` en clientes y gastos. Son
decenas de documentos, no vale pedir un índice.

### Recordatorio

Notificación local la víspera de una entrega, con
`flutter_local_notifications` que ya está, y deep link a `/encargos/:id` — el
patrón de deep link ya existe.

**Esfuerzo:** lo grande. Modelo + repositorio + 3 pantallas + reglas + cierre de
caja. Una sesión larga o dos.

---

## Fase 4 — Pulido

- "Encargos por entregar" como urgencia en el Inicio (`urgencias.dart`).
- Comprobante del encargo para mandar por WhatsApp al recibirlo.
- Reportes: qué tipo de trabajo deja más.

---

## Decisiones abiertas

1. **¿Encargos es gratis o Premium?** Recomiendo **gratis**: es el corazón de un
   negocio de servicio y cobrarlo lo vuelve inútil en el plan libre. Un tope de
   encargos *activos* (10) en gratis sí es defendible.
2. **¿El abono de encargo entra al cierre de caja como línea propia?**
   Recomiendo **sí** — si no, el arqueo descuadra.
3. **¿Descuento automático de tela al entregar?** Recomiendo **no en v1**: en
   confección a la medida el consumo varía por prenda y una receta fija miente.
   Que ajuste el metraje a mano desde Insumos, que ya lo permite.

## Orden sugerido

**Fase 0 → Fase 1** de una sentada (ya puede cobrar bien) · **Fase 2** de
propina · **Fase 3** aparte, con calma.
