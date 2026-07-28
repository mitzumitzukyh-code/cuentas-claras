# Cuenta Clara — Sistema de diseño "Libreta"

Este documento extiende el brief de diseño original (paleta verde/azul/ámbar,
navegación tipo burbuja, logo de cuaderno + check) con una dirección de
identidad completa: **la app se siente como la libreta física donde un
dueño de negocio lleva sus cuentas a mano**, llevada a digital sin perder
esa calidez.

Esta es la decisión de fondo que separa a Cuenta Clara de ser "otra app de
gestión genérica" (Treinta, y prácticamente todo lo demás en la categoría)
a tener una identidad que nadie más en el espacio está jugando. Vale la
pena tomarse los meses que haga falta para hacerlo bien.

---

## 0. La tesis

> Cuenta Clara no es un dashboard. Es un cuaderno de cuentas que sabe hacer
> cosas que un cuaderno de papel no puede: sumar solo, avisar a tiempo,
> y recibir pedidos mientras duermes.

Todo lo que sigue se deriva de esa frase. Si una decisión de diseño no
sirve a esa tesis, no entra.

---

## 1. Principio rector: dónde se usa el gesto y dónde no

Este es el punto más importante del documento, y el que más fácil se le
olvida a uno a mitad de proyecto.

**El gesto de libreta (renglones, espiral, margen rojo, tipografía manuscrita)
es decorativo y de ambientación. Nunca reemplaza claridad en un número
o un monto.**

- Los montos de dinero, totales, cantidades de inventario y fechas de
  entrega **siempre** van en la tipografía sans-serif principal, alto
  contraste, nunca en la fuente manuscrita.
- La fuente manuscrita (Caveat) se reserva para: taglines cortos,
  mensajes de estado vacío, micro-celebraciones ("¡vas bien esta
  semana!"), y anotaciones opcionales — nunca para un dato que el dueño
  necesita leer rápido para cobrar o entregar algo.
- El renglón rayado de fondo es sutil (opacidad baja, color de borde, no
  negro) — es textura, no un elemento que compite por atención.
- Regla de oro heredada del brief original: **legibilidad de números y
  velocidad del flujo de cobro por encima de lo bonito, siempre.**

Antes de agregar cualquier elemento nuevo del lenguaje "libreta" a una
pantalla, pregúntate: ¿esto ayuda a leer más rápido, o solo se ve lindo?
Si es lo segundo, va con moderación o no va.

---

## 2. Sistema de color

| Rol | Nombre | Hex propuesto (ajustar si ya tienes valores exactos) | Uso |
|---|---|---|---|
| Primario / éxito | Verde esmeralda | `#0E9F6E` | Ingresos, confirmaciones, ícono activo, botón Cobrar |
| Texto importante | Azul noche | `#1E2A38` | Encabezados, totales, texto de alto peso |
| Alertas | Ámbar | `#F2A93C` | Urgente, vencimientos, avisos (nunca rojo) |
| Secundario / inactivo | Gris cálido | `#8A9A96` | Íconos inactivos, texto muted |
| Papel (modo claro) | Crema cálido | `#FAF8F3` | Fondo base, evoca papel real sin ser blanco frío |
| Papel (modo oscuro) | Marrón oscuro cálido | `#1C1B18` | Fondo base en modo oscuro — nunca negro puro, mantiene la calidez |
| Margen de libreta | Coral apagado | `#C1503A` a 40% opacidad | Línea vertical de margen, decorativa únicamente |

Nota: en modo oscuro, la sensación de "papel" no viene del color de fondo
(que debe ser oscuro por accesibilidad), sino de mantener el renglón
rayado, el espiral y la línea de margen visibles con suficiente
contraste — la textura es lo que dice "cuaderno", no el tono cálido.

---

## 3. Tipografía

- **Interfaz / datos (99% del texto):** la fuente sans-serif que ya
  estén usando en Flutter (Material 3 default o la que tengan definida).
  Dos pesos solamente — regular y medio — nunca más de dos, para que no
  se sienta pesado.
- **Firma / calidez (Caveat, Google Fonts, gratis):** solo para los
  usos listados en la sección 1. Un solo peso (600/semibold), nunca en
  tamaños menores a 18px porque la manuscrita pierde legibilidad chica.
- **Números financieros:** siempre tabular (`fontFeatures:
  [FontFeature.tabularFigures()]` en Flutter) para que las columnas de
  montos alineen bien en la vista de libreta contable.

---

## 4. Elementos de firma (lo que hace única a la app)

Elige **uno o dos** de estos como el elemento memorable central — no los
metas todos con la misma intensidad en todas partes, o se diluye el
efecto (regla de restricción: gasta tu atrevimiento en un solo lugar).

1. **Espiral de cuaderno** — fila de puntos/círculos en la parte superior
   de pantallas clave (Ventas, Reportes). Bajo costo, alto reconocimiento
   inmediato.
2. **Línea de margen roja/coral** — vertical, a la izquierda del área de
   contenido con datos tipo ledger.
3. **Renglón rayado** — textura de fondo sutil en listas de movimientos.
4. **El check a mano** — la marca de check del logo, pero animada como si
   se "dibujara" al confirmarse una acción (venta cobrada, pedido
   convertido). Este es el más fuerte candidato a ser *el* elemento de
   firma de toda la app — recomendado como el principal.
5. **Post-it torcido** — para el badge de "urgente" en vez de una
   insignia plana (pendiente de explorar).

**Recomendación:** el check dibujado a mano (#4) como firma principal de
motion, y el espiral + renglón (#1, #3) como firma visual de layout.
El resto, opcional y en dosis bajas.

---

## 5. Aplicación pantalla por pantalla

| Pantalla | Qué cambia | Prioridad |
|---|---|---|
| Ventas | Espiral, renglón, margen, lista tipo ledger (ya prototipado) | Alta |
| Mercancía / Inventario | Renglón rayado en lista de insumos, sin espiral (evitar saturar) | Media |
| Reportes | Gráficas con trazo tipo "dibujado a mano" (no barras de esquinas perfectas) — explorar librería de gráficos con estilo hand-drawn o simular con stroke irregular | Media |
| Confirmar venta | El check final se "dibuja" al tocar Cobrar, no aparece de golpe | Alta |
| Estado vacío (sin pedidos, sin ventas) | Ilustración de hoja en blanco con lápiz, tagline en Caveat invitando a la acción | Alta |
| Onboarding | Selector de tipo de negocio con ilustraciones simples, sin gesto de libreta todavía (se "revela" el cuaderno como momento especial después del onboarding) | Media |
| Pedidos por WhatsApp (Plus) | Mantiene el estilo de card visto en el mockup — el gesto de libreta es de fondo de la app, no invade cada componente | Baja |
| Ajustes | Sin gesto decorativo — pantalla utilitaria, prioriza función | N/A |

---

## 6. Movimiento e interacción

- **El check al confirmar:** trazo de línea animado (stroke-dasharray
  animado en Flutter con `CustomPainter` + `AnimationController`, ~400ms),
  como si se dibujara a mano. Éste es el momento de celebración de la app.
- **Transición entre pestañas:** considerar un sutil "page turn" (curva de
  esquina) solo si el costo de rendimiento lo permite — si degrada
  fluidez en gama media/baja, priorizar rendimiento y descartar.
- **Reducción de movimiento:** respetar la preferencia del sistema
  (`MediaQuery.disableAnimations`) — todo lo anterior debe tener
  fallback estático.
- Nada de animación decorativa que no sirva a un momento real (evitar la
  sensación "esto se ve generado por IA" que menciona la guía de diseño:
  la clave es un momento orquestado bien pensado, no efectos dispersos
  por todos lados.

---

## 7. Notas técnicas de implementación en Flutter

- **Renglón rayado:** `CustomPainter` simple dibujando líneas horizontales
  espaciadas, o `DecorationImage` con un patrón PNG/SVG repetido — el
  `CustomPainter` es más liviano y se adapta mejor a modo oscuro/claro
  cambiando el color en tiempo real.
- **Espiral:** fila de `Container` circulares, sin necesidad de asset.
- **Fuente Caveat:** paquete `google_fonts` (`GoogleFonts.caveat(...)`),
  cachea localmente después del primer uso.
- **Check dibujado a mano:** `CustomPainter` + `AnimationController`
  dibujando el path del check con `PathMetric` para animar el trazo
  progresivamente. No requiere Lottie/Rive para este caso puntual.
- **Rendimiento:** cachear el renglón rayado como imagen si se repite en
  muchas pantallas (`RepaintBoundary`), para no recalcular el patrón en
  cada rebuild.
- **Accesibilidad:** verificar contraste del renglón rayado contra el
  fondo cumple mínimo legible (no tiene que pasar WCAG estricto porque es
  decorativo, pero no debe ser invisible ni competir con el texto).

---

## 8. Roadmap sugerido (para repartir en meses, no en un sprint)

1. **Fase 1 — Fundación (2-3 semanas):** tokens de color/tipografía
   formalizados en el theme de Flutter, `CustomPainter` de renglón y
   espiral reutilizables, pantalla de Ventas terminada de punta a punta.
2. **Fase 2 — Núcleo funcional (3-4 semanas):** Mercancía, Confirmar
   venta con el check animado, estados vacíos con ilustración.
3. **Fase 3 — Onboarding y diferenciación (2-3 semanas):** selector de
   rubro de negocio, integración visual del bot de WhatsApp Plus.
4. **Fase 4 — Reportes y pulido (3-4 semanas):** gráficas con estilo
   propio, modo oscuro afinado, Ajustes.
5. **Fase 5 — Autocrítica y recorte (1-2 semanas):** ver sección 9 antes
   de considerar esto "listo para lanzar".

---

## 9. Checklist de autocrítica antes de lanzar

- [ ] ¿Hay alguna pantalla donde el gesto de libreta compite con un
      número o monto en vez de acompañarlo?
- [ ] ¿Se ve igual de bien con datos reales y feos (montos largos,
      nombres largos) y no solo con los datos de ejemplo bonitos?
- [ ] ¿Funciona en modo oscuro sin perder la sensación de "cuaderno"?
- [ ] ¿Hay alguna pantalla sobrecargada de decoración donde, si le quitas
      un elemento, se ve mejor? (la prueba del espejo de Chanel: quítale
      un accesorio antes de salir)
- [ ] ¿Alguien que nunca usó la app reconoce en los primeros 5 segundos
      que esto es diferente a un dashboard genérico?
- [ ] ¿El flujo de cobro sigue siendo igual de rápido que antes de
      agregar todo esto, o se volvió más lento por la decoración?

Si la respuesta a la última pregunta es "más lento", esa es la única
regla de este documento que no se negocia: se recorta lo que haga falta.
