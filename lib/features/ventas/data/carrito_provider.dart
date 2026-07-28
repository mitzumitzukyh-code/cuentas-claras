import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/item_carrito.dart';

/// Estado del carrito de cobro. Un `StateNotifier` que gestiona la lista de
/// ítems, total, y operaciones de agregar/quitar/incrementar/decrementar.
class CarritoNotifier extends StateNotifier<List<ItemCarrito>> {
  CarritoNotifier() : super(const []);

  double get total => state.fold(0.0, (sum, item) => sum + item.subtotal);

  int get cantidad => state.fold(0, (sum, item) => sum + item.cantidad);

  /// Agrega un producto. Si ya existe (mismo productoId y varianteId),
  /// incrementa la cantidad en vez de duplicar la fila.
  void agregar(ItemCarrito item) {
    final idx = state.indexWhere(
      (i) => i.productoId == item.productoId && i.varianteId == item.varianteId,
    );
    if (idx >= 0) {
      final existente = state[idx];
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx)
            existente.copyWith(cantidad: existente.cantidad + item.cantidad)
          else
            state[i],
      ];
    } else {
      state = [...state, item];
    }
  }

  /// Quita una unidad del ítem en [idx]. Si queda en 0, lo elimina.
  void quitar(int idx) {
    if (idx < 0 || idx >= state.length) return;
    final item = state[idx];
    if (item.cantidad <= 1) {
      state = [...state.take(idx), ...state.skip(idx + 1)];
    } else {
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx) item.copyWith(cantidad: item.cantidad - 1) else state[i],
      ];
    }
  }

  /// Pone una cantidad exacta (desde el grid, tap rápido).
  void ponerCantidad(int idx, int cantidad) {
    if (idx < 0 || idx >= state.length) return;
    if (cantidad <= 0) {
      state = [...state.take(idx), ...state.skip(idx + 1)];
    } else {
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(cantidad: cantidad) else state[i],
      ];
    }
  }

  /// Vacía el carrito.
  void vaciar() => state = const [];
}

final carritoProvider = StateNotifierProvider<CarritoNotifier, List<ItemCarrito>>(
  (_) => CarritoNotifier(),
);

/// Total en USD del carrito, derivado.
final carritoTotalProvider = Provider<double>((ref) {
  return ref.watch(carritoProvider).fold(0.0, (s, i) => s + i.subtotal);
});

/// Cantidad de ítems en el carrito, derivado.
final carritoCantidadProvider = Provider<int>((ref) {
  final items = ref.watch(carritoProvider);
  return items.fold(0, (s, i) => s + i.cantidad);
});
