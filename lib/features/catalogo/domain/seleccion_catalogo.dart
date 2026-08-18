/// Las decisiones del Catálogo que no dependen de la pantalla.
///
/// Viven aquí y no dentro del `State` porque son lo único de esa pantalla que
/// se puede equivocar en silencio: un filtro que descarta de más deja al dueño
/// mandando medio catálogo sin enterarse, y un resumen mal contado le hace
/// mandar precios que no revisó. Aquí se prueban sin Firebase ni tasa.
library;

import 'package:flutter/material.dart' show RangeValues;

import '../../../core/utils/money_formatter.dart';
import '../../productos/domain/producto.dart';

/// El precio más bajo y el más alto del catálogo, con margen hacia afuera.
///
/// Los extremos salen de los productos y no de una escala fija: un filtro de
/// \$0 a \$1.000 en una bodega donde nada pasa de \$8 no filtra nada. El
/// margen de arriba evita que el producto más caro quede pegado al borde del
/// control —parece excluido— y que con un solo producto los dos extremos
/// coincidan y el control no se pueda mover.
(double, double) rangoDePrecios(List<Producto> productos) {
  final precios = [
    for (final p in productos)
      if (p.precio != null) p.precio!,
  ];
  if (precios.isEmpty) return (0, 1);

  var min = precios.first;
  var max = precios.first;
  for (final v in precios) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return (min.floorToDouble(), (max + 1).ceilToDouble());
}

/// Si un producto sobrevive a los filtros visibles de la pantalla.
///
/// La búsqueda no distingue mayúsculas ni acentos de más: se compara en
/// minúscula y por trozo del nombre, que es como busca quien recuerda «pan» de
/// «Harina PAN 1kg».
bool pasaFiltros(
  Producto p, {
  String? categoria,
  String busqueda = '',
  RangeValues? rango,
}) {
  if (categoria != null && p.categoria != categoria) return false;

  final texto = busqueda.trim().toLowerCase();
  if (texto.isNotEmpty && !p.nombre.toLowerCase().contains(texto)) return false;

  if (rango != null) {
    final precio = p.precio;
    // Un producto sin precio no llega hasta aquí (el catálogo ya los descarta),
    // pero si llegara, filtrarlo por un rango sería inventarle una cifra.
    if (precio == null) return false;
    if (precio < rango.start || precio > rango.end) return false;
  }
  return true;
}

/// Un rango que abarca todo el catálogo es lo mismo que no filtrar.
///
/// Se distingue para que el chip no se quede en verde diciendo que hay un
/// filtro activo cuando no está escondiendo nada.
bool filtraAlgo(RangeValues rango, (double, double) topes) {
  final (min, max) = topes;
  return rango.start > min || rango.end < max;
}

/// Lo que se va a mandar, en una línea: «11 productos · $1,20 a $8,00».
///
/// No es un contador de casillas. «12 seleccionados» no dice nada que ayude a
/// decidir; el rango de precios sí — es lo último que el dueño lee antes de
/// mandarle una lista de precios a un cliente, y donde se caza el producto que
/// se coló con un cero de más.
String resumenSeleccion(List<Producto> elegidos) {
  if (elegidos.isEmpty) return 'No has marcado ningún producto';

  final precios = [
    for (final p in elegidos)
      if (p.precio != null) p.precio!,
  ]..sort();

  final cuantos =
      '${elegidos.length} ${elegidos.length == 1 ? "producto" : "productos"}';
  if (precios.isEmpty) return cuantos;
  if (precios.first == precios.last) {
    return '$cuantos · ${MoneyFormatter.usd(precios.first)}';
  }
  return '$cuantos · ${MoneyFormatter.usd(precios.first)} '
      'a ${MoneyFormatter.usd(precios.last)}';
}
