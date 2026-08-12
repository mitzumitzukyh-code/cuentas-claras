import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_assets.dart';
import '../../productos/domain/variante.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/numero_ve.dart';
import '../../../shared/presentation/app_bottom_nav.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../../core/utils/telefono_ve.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../auth/data/auth_repository.dart';
import '../../fiados/data/fiado_repository.dart';
import '../../fiados/domain/cliente_fiado.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/metodo_pago_config.dart';
import '../../negocio/domain/negocio.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../../productos/presentation/widgets/escaner_codigo_barras.dart';
import '../data/carrito_provider.dart';
import '../data/venta_repository.dart';
import '../domain/item_carrito.dart';
import '../domain/venta.dart';
import 'widgets/overlay_cobrado.dart';

/// A quién va una cotización.
///
/// **No es un `ClienteFiado` a propósito.** Antes había que elegir a alguien de
/// Fiados para poder cotizar, lo que obligaba a inventar deudores para gente
/// que solo preguntó un precio. Una cotización es para cualquiera —el que pasó
/// preguntando, el que llamó— y no crea cliente ni deuda: vive lo que dura el
/// mensaje.
class _Destinatario {
  const _Destinatario({required this.telefono, this.nombre});

  /// Ya normalizado a E.164 sin `+`, listo para `wa.me`.
  final String telefono;

  /// Opcional: si no lo hay, el mensaje saluda sin nombre.
  final String? nombre;
}

/// Qué se está armando: una venta que se cobra ya, o una cotización que se
/// manda por WhatsApp y no toca inventario ni caja.
enum _Modo { venta, cotizacion }

/// Ventas de los últimos 30 días: la base para saber qué se mueve de verdad.
final _ventasRecientesProvider = StreamProvider.autoDispose<List<Venta>>((ref) {
  final membresia = ref.watch(membresiaActivaProvider);
  if (membresia == null) return Stream.value(const []);
  final hace30dias = DateTime.now().subtract(const Duration(days: 30));
  return ref
      .watch(ventaRepositoryProvider)
      .ventasDesde(membresia.negocioId, hace30dias);
});

/// Unidades vendidas por producto en los últimos 30 días.
///
/// Ordena el catálogo de Cobrar por lo que de verdad se mueve: en una bodega
/// con cientos de productos, lo más vendido debe estar arriba sin que el
/// cajero tenga que escribir nada con clientes esperando.
final _frecuenciaVentaProvider = Provider.autoDispose<Map<String, int>>((ref) {
  final ventas = ref.watch(_ventasRecientesProvider).valueOrNull ?? const [];
  final conteo = <String, int>{};
  for (final v in ventas) {
    if (v.anulada) continue;
    for (final item in v.items) {
      if (item.productoId.isEmpty) continue;
      conteo[item.productoId] = (conteo[item.productoId] ?? 0) + item.cantidad.round();
    }
  }
  return conteo;
});

/// Pantalla 7 — Cobrar (`Lote B · P0`).
///
/// El carrito es la superficie de captura: se toca un producto del catálogo y
/// entra al total. Cada línea lleva su `productoId` real, así que
/// [VentaRepository.registrarVenta] descuenta inventario en la misma
/// transacción que escribe la venta.
///
/// El "monto libre" (venta rápida sin producto asociado) sigue disponible
/// detrás del chevron de la tarjeta de total: entra como una línea con
/// `productoId` vacío, que el repositorio reconoce y no descuenta de nada.
class CobrarScreen extends ConsumerStatefulWidget {
  const CobrarScreen({
    super.key,
    this.iniciarEnCotizacion = false,
    this.abrirEscaner = false,
  });

  /// Abre el segmentado en "Cotización" en vez de "Venta". Lo usa el atajo
  /// `cotizar` del Inicio (`/cobrar?modo=cotizacion`).
  final bool iniciarEnCotizacion;

  /// Levanta el escáner de código de barras apenas cargue el catálogo. Lo usa
  /// el atajo `buscar_codigo` (`/cobrar?escanear=1`).
  final bool abrirEscaner;

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  late _Modo _modo =
      widget.iniciarEnCotizacion ? _Modo.cotizacion : _Modo.venta;

  /// El escáner no se puede abrir en `initState`: hace falta el catálogo ya
  /// cargado para poder resolver el código a un producto. Se dispara en el
  /// primer `build` en que el provider resuelve.
  late bool _escanerPendiente = widget.abrirEscaner;
  MetodoPago _metodo = MetodoPago.efectivo;
  bool _fiado = false;
  ClienteFiado? _cliente;

  /// A quién va la cotización. Independiente de [_cliente], que es para fiar:
  /// fiar exige un cliente real con cuenta; cotizar, no.
  _Destinatario? _destinatario;

  final _busqueda = TextEditingController();
  String _termino = '';

  /// Venta rápida sin producto: se suma al total y no descuenta inventario.
  double _montoLibre = 0;

  bool _cobrando = false;
  bool _mostrarCheck = false;
  double _montoCobrado = 0;
  String? _fiadoA;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  double _totalDe(List<ItemCarrito> carrito) =>
      carrito.fold<double>(0, (s, i) => s + i.subtotal) + _montoLibre;

  int _piezasDe(List<ItemCarrito> carrito) =>
      carrito.fold<int>(0, (s, i) => s + i.cantidad) + (_montoLibre > 0 ? 1 : 0);

  void _aviso(String texto, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: error ? AppColors.peligro : AppColors.marca,
      ),
    );
  }

  // ── Catálogo ────────────────────────────────────────────────────────────

  /// Filtra por nombre y ordena por lo más vendido — con empate, se respeta
  /// el orden original para que la grilla no "baile" en cada venta.
  List<Producto> _filtrarYOrdenar(
    List<Producto> productos,
    Map<String, int> frecuencia,
  ) {
    final termino = _termino.trim().toLowerCase();
    final indexados = productos
        .asMap()
        .entries
        .where((e) => termino.isEmpty || e.value.nombre.toLowerCase().contains(termino))
        .toList();
    indexados.sort((a, b) {
      final fa = frecuencia[a.value.id] ?? 0;
      final fb = frecuencia[b.value.id] ?? 0;
      if (fa != fb) return fb.compareTo(fa);
      return a.key.compareTo(b.key);
    });
    return [for (final e in indexados) e.value];
  }

  Future<void> _escanearProducto(List<Producto> productos) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanerCodigoBarras()),
    );
    if (codigo == null || !mounted) return;
    final producto =
        productos.where((p) => p.codigoBarras == codigo).firstOrNull;
    if (producto == null) {
      _aviso('Ningún producto tiene ese código de barras.');
      return;
    }
    await _agregar(producto);
    if (!mounted) return;
    _aviso(
      '${producto.nombre} · ${producto.precioLabel}',
      error: false,
    );
  }

  Future<void> _agregar(Producto p) async {
    // Un producto sin precio no entra al carrito. Antes la importación
    // guardaba 0 cuando no podía leer la cifra, y ese 0 se podía cobrar: la
    // mercancía se regalaba sin que nadie lo notara.
    if (!p.sePuedeVender) {
      _aviso('"${p.nombre}" no tiene precio. Ponle uno antes de venderlo.');
      return;
    }

    Variante? variante;
    double? kg;

    if (p.tieneVariantes) {
      variante = await _elegirVariante(p);
      if (variante == null) return;
    }
    if (p.vendidoPorPeso) {
      // El peso viaja tal cual, sin `.round()`. Redondearlo cobraba 3 kg de
      // queso por 2,5 y metía 0,4 kg como 0 —es decir, gratis—, aunque el
      // resto de la cadena lleva siempre decimales.
      kg = await _pedirCantidad(p);
      if (kg == null) return;
      if (kg <= 0) {
        _aviso('El peso tiene que ser mayor que cero.');
        return;
      }
    }

    ref.read(carritoProvider.notifier).agregar(
          ItemCarrito(
            productoId: p.id,
            nombre: p.nombre,
            precioUnitario: p.precio!,
            pesoKg: kg,
            varianteValor: variante?.valor,
            varianteColor: variante?.color,
            fotoUrl: p.fotoUrl,
            precioAnterior: p.tieneOferta ? p.precioAnterior : null,
          ),
        );
    // En un mostrador ruidoso, con el cliente al frente, el golpecito es la
    // señal más confiable de que el toque entró — más que cualquier color.
    unawaited(HapticFeedback.selectionClick());
  }

  /// Quita una unidad desde la propia ficha del catálogo (botón − o toque
  /// largo), sin abrir el carrito.
  ///
  /// Se descuenta de la ÚLTIMA línea de ese producto: con variantes hay varias
  /// —una por talla/color— y la última es la que el dueño acaba de tocar, que
  /// es la que espera deshacer. Para cambios finos está el carrito.
  void _quitarDelGrid(Producto p) {
    final carrito = ref.read(carritoProvider);
    final idx = carrito.lastIndexWhere((i) => i.productoId == p.id);
    if (idx < 0) return;
    ref.read(carritoProvider.notifier).quitar(idx);
    unawaited(HapticFeedback.selectionClick());
  }

  Future<Variante?> _elegirVariante(Producto p) {
    return showModalBottomSheet<Variante>(
      context: context,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = ctx.libreta;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 12),
                ...p.variantes.map(
                  (v) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      [
                        v.valor,
                        if (v.color != null && v.color!.isNotEmpty) v.color!,
                      ].join(' / '),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.textoFuerte,
                      ),
                    ),
                    subtitle: Text(
                      'Quedan ${v.cantidad}',
                      style: TextStyle(fontSize: 12, color: t.textoMuted),
                    ),
                    onTap: v.cantidad <= 0 && p.bloquearAlAgotarse
                        ? null
                        : () => Navigator.of(ctx).pop(v),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<double?> _pedirCantidad(Producto p) {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Cuántos kg de ${p.nombre}?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            // "1.500" kg con `replaceAll` se leia como 1,5: el punto se
            // tomaba por decimal y se cobraba mil veces menos peso.
            onPressed: () =>
                Navigator.of(ctx).pop(normalizarNumeroVE(ctrl.text)),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirMontoLibre() async {
    final ctrl = TextEditingController(
      text: _montoLibre > 0 ? _montoLibre.toStringAsFixed(2) : '',
    );
    final monto = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monto libre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para cobrar algo que no está en el inventario. No descuenta '
              'existencias.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: r'$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(0.0),
            child: const Text('Quitar'),
          ),
          TextButton(
            // Vacio quita el monto libre; algo escrito que no se puede leer
            // no lo pone en cero -eso regalaba el cobro en silencio-, sino
            // que deja el importe como estaba.
            onPressed: () => Navigator.of(ctx).pop(
              normalizarNumeroVE(ctrl.text) ??
                  (ctrl.text.trim().isEmpty ? 0.0 : null),
            ),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (monto != null && mounted) setState(() => _montoLibre = monto);
  }

  /// Hoja de "Carrito": lo que antes vivía siempre visible bajo el total
  /// ahora solo aparece al pedirlo, para que la grilla de productos sea lo
  /// primero que ve un cajero nuevo y no una lista de líneas que todavía no
  /// tiene.
  Future<void> _abrirCarrito() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Consumer(
          builder: (ctx, ref, _) {
            final t = ctx.libreta;
            final carrito = ref.watch(carritoProvider);
            final vacio = carrito.isEmpty && _montoLibre <= 0;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Carrito',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: t.textoFuerte,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vacio
                          ? 'Todavía no agregaste nada.'
                          : 'Toca una línea para quitarla.',
                      style: TextStyle(fontSize: 12.5, color: t.textoMuted),
                    ),
                    const SizedBox(height: 12),
                    if (!vacio)
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (var i = 0; i < carrito.length; i++)
                              _FilaCarrito(
                                nombre: carrito[i].cantidad > 1 ||
                                        carrito[i].porPeso
                                    ? '${carrito[i].nombre} ×${carrito[i].cantidadLabel}'
                                    : carrito[i].nombre,
                                monto: carrito[i].subtotal,
                                onQuitar: () => ref
                                    .read(carritoProvider.notifier)
                                    .quitar(i),
                              ),
                            if (_montoLibre > 0)
                              _FilaCarrito(
                                nombre: 'Monto libre',
                                monto: _montoLibre,
                                onQuitar: () => setModalState(
                                  () => setState(() => _montoLibre = 0),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    LibretaSecondaryButton(
                      label: 'Agregar monto libre',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _abrirMontoLibre();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Cliente ─────────────────────────────────────────────────────────────

  /// A quién va la cotización: alguien de Fiados, o un número suelto.
  ///
  /// El número escrito a mano es el caso común —quien pasó preguntando— y no
  /// guarda nada: ni cliente, ni deuda. Si el dueño quiere conservarlo, lo
  /// agrega desde Fiados, que es una decisión aparte.
  ///
  /// Falta el tercer camino, el contacto de la agenda: la app no pide hoy el
  /// permiso de contactos y no vale gastarlo en esto.
  Future<void> _elegirDestinatario() async {
    final via = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const LibretaIcono(AppAssets.navClientes),
              title: const Text('Un cliente de Fiados'),
              subtitle: const Text('de los que ya tienes guardados'),
              onTap: () => Navigator.of(ctx).pop('fiado'),
            ),
            ListTile(
              leading: const Icon(Icons.dialpad),
              title: const Text('Escribir un número'),
              subtitle: const Text('no se guarda como cliente'),
              onTap: () => Navigator.of(ctx).pop('numero'),
            ),
          ],
        ),
      ),
    );
    if (via == null || !mounted) return;

    if (via == 'fiado') {
      final cliente = await _abrirSelectorCliente();
      if (cliente == null || !mounted) return;
      final tel = normalizarTelefonoVE(cliente.telefono);
      if (tel == null) {
        _aviso('${cliente.nombre} no tiene un teléfono válido guardado.');
        return;
      }
      setState(() {
        _destinatario = _Destinatario(telefono: tel, nombre: cliente.nombre);
      });
      return;
    }

    final escrito = await _pedirNumeroSuelto();
    if (escrito != null && mounted) setState(() => _destinatario = escrito);
  }

  Future<_Destinatario?> _pedirNumeroSuelto() {
    final telefono = TextEditingController();
    final nombre = TextEditingController();
    String? error;

    return showModalBottomSheet<_Destinatario>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            // `viewInsets` cubre el teclado pero NO la barra de navegación
            // del sistema: sin `viewPadding`, el botón de confirmar quedaba
            // medio tapado por los botones de Android.
            bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                MediaQuery.viewPaddingOf(ctx).bottom +
                18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿A qué número?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: ctx.libreta.textoFuerte,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No se guarda como cliente ni queda debiendo nada.',
                style: TextStyle(fontSize: 12.5, color: ctx.libreta.textoMuted),
              ),
              const SizedBox(height: 14),
              LibretaInput(
                controller: telefono,
                label: 'Teléfono',
                hint: '0414-510-0255',
                keyboardType: TextInputType.phone,
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: LibretaColors.peligro,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LibretaInput(
                controller: nombre,
                label: 'Nombre (opcional)',
                hint: 'Para saludarlo por su nombre',
              ),
              const SizedBox(height: 16),
              LibretaButton(
                label: 'Usar este número',
                onPressed: () {
                  final tel = normalizarTelefonoVE(telefono.text);
                  if (tel == null) {
                    setSheet(() => error =
                        'Ese no parece un número venezolano. Ej: 0414-510-0255');
                    return;
                  }
                  final n = nombre.text.trim();
                  Navigator.of(ctx).pop(
                    _Destinatario(telefono: tel, nombre: n.isEmpty ? null : n),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      telefono.dispose();
      nombre.dispose();
    });
  }

  /// Selector puro: no toca el estado de la pantalla, solo devuelve lo
  /// elegido. Lo reutiliza tanto la cotización (que fija el cliente al
  /// vuelo) como la hoja de confirmar cobro (que decide recién al cerrar).
  Future<ClienteFiado?> _abrirSelectorCliente() async {
    final clientes = ref.read(clientesFiadoProvider).valueOrNull ?? const [];
    return showModalBottomSheet<ClienteFiado>(
      context: context,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = ctx.libreta;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elegir cliente',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 8),
                if (clientes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Todavía no tienes clientes con cuenta. Créalos '
                          'desde Fiados.',
                          style:
                              TextStyle(fontSize: 13.5, color: t.textoMuted),
                        ),
                        const SizedBox(height: 10),
                        LibretaSecondaryButton(
                          label: 'Ir a Fiados',
                          icon: const LibretaIcono(AppAssets.navClientes,
                            size: 16,
                            color: LibretaColors.verde,
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            context.push(Routes.fiados);
                          },
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final c in clientes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: _Avatar(nombre: c.nombre),
                            title: Text(
                              c.nombre,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: t.textoFuerte,
                              ),
                            ),
                            subtitle: Text(
                              c.saldoUSD > 0
                                  ? 'Debe ${MoneyFormatter.usd(c.saldoUSD)}'
                                  : 'Al día',
                              style: TextStyle(
                                fontSize: 12,
                                color: t.textoMuted,
                              ),
                            ),
                            onTap: () => Navigator.of(ctx).pop(c),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Cobrar ──────────────────────────────────────────────────────────────

  /// Un producto marcado "bloquear al agotarse" no se puede vender por encima
  /// de su stock. Los demás sí (una bodega vende y ajusta después).
  ///
  /// Se comprueba **sumando** todas las líneas del mismo producto, no una a
  /// una. `CarritoNotifier.agregar` fusiona por producto *y variante*, así que
  /// una franela en talla M y en L son dos líneas del mismo `productoId`: con
  /// el control línea a línea, 4 M + 4 L pasaban contra un stock de 6 —cada
  /// una comparaba 4 contra 6— y se vendían 8.
  ///
  /// Y cuando la línea trae variante se mira **la casilla de esa variante**,
  /// que es de donde el repositorio va a descontar. El total del producto no
  /// dice nada sobre si quedan tallas M.
  String? _stockInsuficiente(List<ItemCarrito> carrito) {
    final productos = ref.read(productosProvider).valueOrNull ?? const [];

    final porProducto = <String, double>{};
    final porVariante = <String, double>{};
    for (final item in carrito) {
      if (item.productoId.isEmpty) continue;
      porProducto[item.productoId] =
          (porProducto[item.productoId] ?? 0) + item.cantidadCobrada;
      if (item.tieneVariante) {
        final clave = '${item.productoId}|${item.varianteValor}'
            '|${item.varianteColor ?? ''}';
        porVariante[clave] = (porVariante[clave] ?? 0) + item.cantidadCobrada;
      }
    }

    for (final item in carrito) {
      final p = productos.where((x) => x.id == item.productoId).firstOrNull;
      if (p == null || !p.bloquearAlAgotarse) continue;

      if (item.tieneVariante) {
        final v = p.variantes
            .where((x) =>
                x.valor == item.varianteValor &&
                (x.color ?? '') == (item.varianteColor ?? ''))
            .firstOrNull;
        final clave = '${item.productoId}|${item.varianteValor}'
            '|${item.varianteColor ?? ''}';
        final pedido = porVariante[clave] ?? 0;
        if (v != null && pedido > v.cantidad) {
          return 'Solo quedan ${v.cantidad} de "${p.nombre} '
              '${item.varianteValor}".';
        }
        continue;
      }

      if ((porProducto[p.id] ?? 0) > p.cantidad) {
        return 'Solo quedan ${p.cantidadLabel} de "${p.nombre}".';
      }
    }
    return null;
  }

  String _concepto(List<ItemCarrito> carrito) {
    if (carrito.isEmpty) return 'Venta rápida';
    if (carrito.length <= 2) {
      return carrito
          .map((i) => i.cantidad > 1 || i.porPeso
              ? '${i.nombre} ×${i.cantidadLabel}'
              : i.nombre)
          .join(' + ');
    }
    return '${carrito.length} productos';
  }

  /// Hoja "¿Cómo te pagó?": el método de pago (y a quién se le fía) se
  /// decide al confirmar, no mientras se arma el carrito — con clientes
  /// esperando, elegir entre 6 chips antes de saber cuánto es no ayuda.
  Future<void> _abrirConfirmarCobro(
    double tasa,
    Negocio negocio,
    double total,
    int piezas,
  ) async {
    final resultado = await showModalBottomSheet<_PagoElegido>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.libreta.papel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HojaConfirmarPago(
        total: total,
        piezas: piezas,
        activos: negocio.metodosActivos,
        metodoInicial: _metodo,
        fiadoInicial: _fiado,
        clienteInicial: _cliente,
        onElegirCliente: _abrirSelectorCliente,
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _metodo = resultado.metodo;
      _fiado = resultado.fiado;
      _cliente = resultado.cliente;
    });
    await _cobrar(tasa, negocio);
  }

  Future<void> _cobrar(double tasa, Negocio negocio) async {
    final carrito = ref.read(carritoProvider);
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).value;
    final total = _totalDe(carrito);
    if (membresia == null || user == null || total <= 0) return;

    if (_fiado && _cliente == null) {
      _aviso('Elige a quién se le fía.');
      return;
    }
    final falta = _stockInsuficiente(carrito);
    if (falta != null) {
      _aviso(falta);
      return;
    }

    setState(() => _cobrando = true);

    final productos = ref.read(productosProvider).valueOrNull ?? const [];
    final items = <ItemVenta>[
      for (final i in carrito)
        ItemVenta(
          productoId: i.productoId,
          nombre: i.nombre,
          cantidad: i.cantidadCobrada,
          precioUnitario: i.precioUnitario,
          costoUnitario:
              productos.where((p) => p.id == i.productoId).firstOrNull?.costo,
          varianteValor: i.varianteValor,
          varianteColor: i.varianteColor,
          fotoUrl: i.fotoUrl,
          // Sin esto el historial y los reportes enseñaban «3» donde tenía que
          // decir «3 kg»: `ItemVenta.cantidadLabel` ya sabía formatearlo, pero
          // nunca se enteraba de que la línea era de las que se pesan.
          vendidoPorPeso: i.porPeso,
        ),
      // Línea sin producto: el repositorio la reconoce y no toca inventario.
      if (_montoLibre > 0)
        ItemVenta(
          productoId: '',
          nombre: 'Venta rápida',
          cantidad: 1,
          precioUnitario: _montoLibre,
        ),
    ];

    final iva = negocio.incluirIva
        ? total * Negocio.tasaIva / (1 + Negocio.tasaIva)
        : 0.0;
    final venta = Venta(
      id: '',
      items: items,
      totalUSD: total,
      totalBs: MoneyFormatter.convertirABs(total, tasa),
      tasaBcvUsada: tasa,
      vendidoPor: user.uid,
      fecha: DateTime.now(),
      metodoPago: _metodo,
      ivaUSD: iva,
      fiadoClienteId: _fiado ? _cliente!.id : null,
      fiadoClienteNombre: _fiado ? _cliente!.nombre : null,
    );

    try {
      await ref.read(ventaRepositoryProvider).registrarVenta(
            membresia.negocioId,
            venta,
            fiadoA: _fiado
                ? FiadoDeVenta(
                    clienteId: _cliente!.id,
                    clienteNombre: _cliente!.nombre,
                    concepto: _concepto(carrito),
                  )
                : null,
          );
      if (!mounted) return;
      final eraFiado = _fiado;
      final nombre = _cliente?.nombre;
      ref.read(carritoProvider.notifier).vaciar();
      setState(() {
        _montoCobrado = total;
        _montoLibre = 0;
        _cobrando = false;
        _mostrarCheck = true;
        _fiadoA = eraFiado ? nombre : null;
        _fiado = false;
        _cliente = null;
        _metodo = MetodoPago.efectivo;
      });
      Future.delayed(const Duration(milliseconds: 1900), () {
        if (mounted) setState(() => _mostrarCheck = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cobrando = false);
      // La excepcion cruda iba a la pantalla, y en el peor sitio: el momento
      // en que el cobro no salio y el cliente esta esperando.
      _aviso(mensajeDeError(e, accion: 'registrar la venta'));
    }
  }

  // ── Cotización ──────────────────────────────────────────────────────────

  Future<void> _enviarCotizacion(double tasa, Negocio negocio) async {
    final carrito = ref.read(carritoProvider);
    final total = _totalDe(carrito);
    if (total <= 0) return;
    final destino = _destinatario;
    if (destino == null) {
      _aviso('Elige a quién va la cotización.');
      return;
    }

    final tipo = ref.read(tasaActivaProvider);
    // El monto libre entra en el desglose además de en el total. Se quedaba
    // fuera: el cliente recibía tres renglones y un total mayor que su suma,
    // y quien tiene que explicar esa diferencia es el dueño.
    final lineas = [
      for (final i in carrito)
        '• ${i.nombre} ×${i.cantidadLabel} — ${MoneyFormatter.usd(i.subtotal)}',
      if (_montoLibre > 0) '• Otros — ${MoneyFormatter.usd(_montoLibre)}',
    ].join('\n');

    final mensaje = StringBuffer()
      ..writeln('Hola${destino.nombre == null ? '' : ' ${destino.nombre}'} 👋 '
          'aquí tu cotización de ${negocio.nombre}:')
      ..writeln()
      ..writeln(lineas)
      ..writeln()
      ..writeln('${MoneyFormatter.usd(total)} · '
          '${MoneyFormatter.usdComoBs(total, tasa)}')
      ..writeln('válida por 24h · ${tipo.etiqueta}')
      ..writeln()
      ..write('¿La confirmamos? Aviso cuando pases a recoger.');

    // Al chat del cliente, no al selector de contactos: `abrirWhatsApp`
    // normaliza el teléfono a E.164, que es lo que `wa.me` necesita para
    // resolver a una persona esté o no agendada.
    final resultado = await abrirWhatsApp(
      texto: mensaje.toString(),
      telefono: destino.telefono,
    );
    if (!mounted) return;

    // Con un teléfono que no se puede marcar el carrito NO se limpia: la
    // cotización no salió y el dueño tiene que poder reintentarla.
    if (resultado == ResultadoWhatsApp.telefonoInvalido) {
      _aviso(avisoDe(resultado)!);
      return;
    }

    ref.read(carritoProvider.notifier).vaciar();
    setState(() {
      _montoLibre = 0;
      _cliente = null;
      _destinatario = null;
      _modo = _Modo.venta;
    });
    final aviso = avisoDe(resultado);
    _aviso(aviso ?? 'Cotización enviada.', error: aviso != null);
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tipoTasa = ref.watch(tasaActivaProvider);
    final tasa = ref.watch(tasaActivaValorProvider);
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final carrito = ref.watch(carritoProvider);
    final productosAsync = ref.watch(productosProvider);
    final productos = productosAsync.valueOrNull ?? const <Producto>[];
    final frecuencia = ref.watch(_frecuenciaVentaProvider);

    // Atajo "Buscar código": el escáner se abre una sola vez, cuando ya hay
    // catálogo contra el cual resolver lo escaneado.
    if (_escanerPendiente && productosAsync.hasValue) {
      _escanerPendiente = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _escanearProducto(productos);
      });
    }

    final productosVisibles = _filtrarYOrdenar(productos, frecuencia);
    final total = _totalDe(carrito);
    final piezas = _piezasDe(carrito);
    // El orden de los dos montos lo decide la moneda que el negocio eligió en
    // el onboarding, no la pantalla.
    final (principalTotal, secundarioTotal) = montosDelNegocio(ref, total);
    // Cuántas unidades lleva cada producto, sumando sus variantes: es lo que
    // pinta el badge de la ficha. Al vaciar el carrito el mapa queda vacío y
    // todas las fichas vuelven solas a su estado normal.
    final cantidadesPorProducto = <String, int>{};
    for (final item in carrito) {
      cantidadesPorProducto[item.productoId] =
          (cantidadesPorProducto[item.productoId] ?? 0) + item.cantidad;
    }
    final esCotizacion = _modo == _Modo.cotizacion;

    final listo = total > 0 && tasa != null && negocio != null && !_cobrando;

    return Scaffold(
      backgroundColor: t.papel,
      bottomNavigationBar: const AppBottomNav(activa: NavTab.cobrar),
      body: Stack(
        children: [
          LibretaPageBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Encabezado ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Cobrar',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: t.textoFuerte,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            _SelectorTasa(
                              valor: tipoTasa,
                              onChanged: (v) => ref
                                  .read(tasaActivaProvider.notifier)
                                  .elegir(v),
                            ),
                          ],
                        ),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: LibretaAvisoOfflineCompacto(),
                        ),
                        const SizedBox(height: 12),
                        _Segmentado(
                          modo: _modo,
                          onChanged: (m) => setState(() {
                            _modo = m;
                            if (m == _Modo.cotizacion) _fiado = false;
                          }),
                        ),
                        // El método de pago (y a quién se le fía) se elige al
                        // confirmar el cobro, no aquí — ver
                        // `_abrirConfirmarCobro`. La cotización sí necesita el
                        // cliente desde ya: la promesa es para alguien en
                        // concreto desde el primer producto que se agrega.
                        if (esCotizacion) ...[
                          const SizedBox(height: 10),
                          _TarjetaCliente(
                            nombre: _destinatario?.nombre,
                            telefono: _destinatario?.telefono,
                            vacio: _destinatario == null,
                            sufijo: 'recibe la cotización',
                            onCambiar: _elegirDestinatario,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Total, carrito y catálogo ───────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _BuscadorProductos(
                            controller: _busqueda,
                            onChanged: (v) => setState(() => _termino = v),
                            onEscanear: () => _escanearProducto(productos),
                          ),
                          const SizedBox(height: 10),
                          _TarjetaTotal(
                            etiqueta: esCotizacion
                                ? 'TOTAL A COTIZAR'
                                : 'TOTAL A COBRAR',
                            principal: principalTotal,
                            // La segunda línea siempre dice de qué tasa se
                            // trata. Con el modo "ambas" no hay segundo monto
                            // —van los dos arriba— y queda solo la etiqueta.
                            secundario: secundarioTotal != null
                                ? '$secundarioTotal · ${tipoTasa.etiqueta}'
                                : tasa == null
                                    ? '${tipoTasa.etiqueta} no disponible'
                                    : tipoTasa.etiqueta,
                            piezas: piezas,
                            onTapPie: _abrirCarrito,
                          ),
                          const SizedBox(height: 10),
                          if (_termino.isEmpty && frecuencia.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 13,
                                    color: LibretaColors.aviso,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'MÁS VENDIDOS PRIMERO',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4,
                                      color: t.textoMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _GridCatalogo(
                              productos: productosVisibles,
                              buscando: _termino.isNotEmpty,
                              onTap: _agregar,
                              onQuitar: _quitarDelGrid,
                              cantidades: cantidadesPorProducto,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _BotonCobrar(
                            label: esCotizacion
                                ? 'Enviar cotización ${MoneyFormatter.usd(total)}'
                                : 'Cobrar ${MoneyFormatter.usd(total)}',
                            icono: esCotizacion
                                ? Icons.chat_bubble
                                : Icons.check_rounded,
                            cargando: _cobrando,
                            onPressed: !listo
                                ? null
                                : esCotizacion
                                    ? () => _enviarCotizacion(tasa, negocio)
                                    : () => _abrirConfirmarCobro(
                                          tasa,
                                          negocio,
                                          total,
                                          piezas,
                                        ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mostrarCheck)
            OverlayCobrado(
              monto: _montoCobrado,
              tasa: tasa,
              fiadoA: _fiadoA,
              onTap: () => setState(() => _mostrarCheck = false),
            ),
        ],
      ),
    );
  }
}

/// Fondo de las "pistas" de pastillas y segmentados: rgba(30,42,56,.06) en
/// claro, su equivalente crema en oscuro.
Color _pista(LibretaTokens t) => t.textoFuerte.withValues(alpha: 0.06);

// ── Encabezado ────────────────────────────────────────────────────────────

/// Pastillas BCV / Paralelo del encabezado.
class _SelectorTasa extends StatelessWidget {
  const _SelectorTasa({required this.valor, required this.onChanged});

  final TipoTasa valor;
  final ValueChanged<TipoTasa> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _pista(t),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillTasa(
            texto: 'BCV',
            activa: valor == TipoTasa.bcv,
            onTap: () => onChanged(TipoTasa.bcv),
          ),
          _PillTasa(
            // Copy de cara al usuario; el enum sigue siendo `binance`.
            texto: 'Paralelo',
            activa: valor == TipoTasa.binance,
            onTap: () => onChanged(TipoTasa.binance),
          ),
        ],
      ),
    );
  }
}

class _PillTasa extends StatelessWidget {
  const _PillTasa({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: activa ? t.superficie : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: activa
              ? const [
                  BoxShadow(
                    color: Color(0x2E1E2A38),
                    offset: Offset(0, 1),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activa ? FontWeight.w800 : FontWeight.w700,
            color: activa ? t.textoFuerte : t.textoMuted,
          ),
        ),
      ),
    );
  }
}

/// Segmentado Venta | Cotización.
class _Segmentado extends StatelessWidget {
  const _Segmentado({required this.modo, required this.onChanged});

  final _Modo modo;
  final ValueChanged<_Modo> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _pista(t),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final m in _Modo.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: modo == m ? LibretaColors.verde : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    m == _Modo.venta ? 'Venta' : 'Cotización',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          modo == m ? FontWeight.w800 : FontWeight.w700,
                      color: modo == m ? Colors.white : t.textoMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pastilla de método de pago. La de "Fiado" es ámbar con texto navy — es la
/// única que no cobra plata en el momento.
class _PastillaMetodo extends StatelessWidget {
  const _PastillaMetodo({
    required this.label,
    required this.activa,
    required this.onTap,
    this.esFiado = false,
  });

  final String label;
  final bool activa;
  final VoidCallback onTap;
  final bool esFiado;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: activa
              ? (esFiado ? LibretaColors.ambarSuperficie : LibretaColors.verde)
              : _pista(t),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: activa
                ? (esFiado ? LibretaColors.tarjetaOscura : Colors.white)
                : t.textoMuted,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del cliente al que se le fía o se le cotiza.
class _TarjetaCliente extends StatelessWidget {
  const _TarjetaCliente({
    required this.nombre,
    required this.telefono,
    required this.vacio,
    required this.sufijo,
    required this.onCambiar,
  });

  /// Puede ser `null` aun con destinatario elegido: un número suelto no
  /// necesita nombre.
  final String? nombre;
  final String? telefono;

  /// `true` = todavía no se eligió a nadie.
  final bool vacio;
  final String sufijo;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tel = telefono;
    return GestureDetector(
      onTap: vacio ? onCambiar : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: LibretaColors.verde.withValues(alpha: .30), width: 1.5),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            _Avatar(nombre: nombre),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vacio
                        ? 'Elegir a quién'
                        : (nombre ?? 'Número suelto'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                      height: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    vacio
                        ? 'un cliente o un número suelto'
                        : [
                            if (tel != null && tel.isNotEmpty) tel,
                            sufijo,
                          ].join(' · '),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: t.textoMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCambiar,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  'Cambiar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo que se decidió en la hoja "¿Cómo te pagó?".
class _PagoElegido {
  const _PagoElegido({required this.metodo, required this.fiado, this.cliente});

  final MetodoPago metodo;
  final bool fiado;
  final ClienteFiado? cliente;
}

/// Hoja de confirmación al tocar "Cobrar": elegir método de pago (o fiar) y,
/// si es fiado, a quién. Vive aparte de la pantalla principal para que
/// armar el carrito no obligue a mirar 6 chips de pago antes de saber
/// cuánto es.
class _HojaConfirmarPago extends StatefulWidget {
  const _HojaConfirmarPago({
    required this.total,
    required this.piezas,
    required this.activos,
    required this.metodoInicial,
    required this.fiadoInicial,
    required this.clienteInicial,
    required this.onElegirCliente,
  });

  final double total;
  final int piezas;
  final List<MetodoPagoConfig> activos;
  final MetodoPago metodoInicial;
  final bool fiadoInicial;
  final ClienteFiado? clienteInicial;
  final Future<ClienteFiado?> Function() onElegirCliente;

  @override
  State<_HojaConfirmarPago> createState() => _HojaConfirmarPagoState();
}

class _HojaConfirmarPagoState extends State<_HojaConfirmarPago> {
  late MetodoPago _metodo = widget.metodoInicial;
  late bool _fiado = widget.fiadoInicial;
  late ClienteFiado? _cliente = widget.clienteInicial;

  Future<void> _elegirCliente() async {
    final elegido = await widget.onElegirCliente();
    if (elegido != null && mounted) setState(() => _cliente = elegido);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final puedeConfirmar = !_fiado || _cliente != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Cómo te pagó?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${MoneyFormatter.usd(widget.total)} · ${widget.piezas} '
              '${widget.piezas == 1 ? "producto" : "productos"}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.textoMuted,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in widget.activos)
                  _PastillaMetodo(
                    label: c.metodo.etiquetaCorta,
                    activa: !_fiado && _metodo == c.metodo,
                    onTap: () => setState(() {
                      _metodo = c.metodo;
                      _fiado = false;
                    }),
                  ),
                _PastillaMetodo(
                  label: 'Fiado',
                  activa: _fiado,
                  esFiado: true,
                  onTap: () => setState(() => _fiado = !_fiado),
                ),
              ],
            ),
            if (_fiado) ...[
              const SizedBox(height: 12),
              // Fiar sí exige un cliente real: la deuda tiene que quedar en la
              // cuenta de alguien.
              _TarjetaCliente(
                nombre: _cliente?.nombre,
                telefono: _cliente?.telefono,
                vacio: _cliente == null,
                sufijo: 'se anota a su cuenta',
                onCambiar: _elegirCliente,
              ),
            ],
            const SizedBox(height: 18),
            LibretaButton(
              label: _fiado
                  ? 'Anotar fiado ${MoneyFormatter.usd(widget.total)}'
                  : 'Confirmar cobro ${MoneyFormatter.usd(widget.total)}',
              onPressed: !puedeConfirmar
                  ? null
                  : () => Navigator.of(context).pop(
                        _PagoElegido(
                          metodo: _metodo,
                          fiado: _fiado,
                          cliente: _cliente,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Círculo navy con las iniciales del cliente.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.nombre});

  final String? nombre;

  String get _iniciales {
    final partes = (nombre ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: LibretaColors.tarjetaOscura,
        shape: BoxShape.circle,
      ),
      child: Text(
        _iniciales,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ── Total y carrito ───────────────────────────────────────────────────────

/// Tarjeta hero navy con el total. El pie es tocable: abre el monto libre.
class _TarjetaTotal extends StatelessWidget {
  const _TarjetaTotal({
    required this.etiqueta,
    required this.principal,
    required this.secundario,
    required this.piezas,
    required this.onTapPie,
  });

  final String etiqueta;

  /// El monto grande, ya en la moneda que manda según el modo del negocio.
  final String principal;

  /// La línea de referencia: el otro monto y de qué tasa sale.
  final String secundario;
  final int piezas;
  final VoidCallback onTapPie;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: LibretaColors.tarjetaOscura,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.bordeHero, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0x99FFFFFF),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              principal,
              style: AppTypography.money(fontSize: 44, color: Colors.white)
                  .copyWith(letterSpacing: -1, height: 1),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            secundario,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xB3FFFFFF),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTapPie,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x24FFFFFF))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      piezas == 0
                          ? 'Carrito vacío — toca un producto'
                          : piezas == 1
                              ? '1 producto en el carrito'
                              : '$piezas productos en el carrito',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xD9FFFFFF),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Color(0xB3FFFFFF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCarrito extends StatelessWidget {
  const _FilaCarrito({
    required this.nombre,
    required this.monto,
    required this.onQuitar,
  });

  final String nombre;
  final double monto;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onQuitar,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.renglon)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.textoFuerte,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              MoneyFormatter.usd(monto),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(width: 8),
            LibretaIcono(AppAssets.accCerrar, size: 14, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}

/// Buscador del catálogo + atajo al escáner de código de barras.
///
/// Con muchos productos y varios clientes esperando, deslizar buscando por
/// nombre no alcanza: escribir dos letras o escanear el código es más rápido
/// que leer etiquetas truncadas en la grilla.
class _BuscadorProductos extends StatelessWidget {
  const _BuscadorProductos({
    required this.controller,
    required this.onChanged,
    required this.onEscanear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.superficie,
              border: Border.all(color: t.renglon),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                LibretaIcono(AppAssets.accBuscar, size: 18, color: t.textoMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: t.textoFuerte,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Buscar producto…',
                      hintStyle: TextStyle(
                        color: t.textoMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: LibretaIcono(AppAssets.accCerrar,
                      size: 16,
                      color: t.textoMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onEscanear,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: LibretaColors.tarjetaOscura,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const LibretaIcono(AppAssets.accEscanear,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

/// Catálogo en dos columnas. Es la superficie de captura de la pantalla.
class _GridCatalogo extends StatelessWidget {
  const _GridCatalogo({
    required this.productos,
    required this.onTap,
    required this.onQuitar,
    required this.cantidades,
    this.buscando = false,
  });

  final List<Producto> productos;
  final ValueChanged<Producto> onTap;
  final ValueChanged<Producto> onQuitar;

  /// Unidades en el carrito por `productoId`.
  final Map<String, int> cantidades;
  final bool buscando;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    if (productos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            buscando
                ? 'Ningún producto coincide con esa búsqueda.'
                : 'Todavía no tienes productos cargados.\nToca el total '
                    'para cobrar un monto libre.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: t.textoMuted,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 58,
      ),
      itemCount: productos.length,
      itemBuilder: (_, i) => _FichaProducto(
        producto: productos[i],
        cantidad: cantidades[productos[i].id] ?? 0,
        onTap: () => onTap(productos[i]),
        onQuitar: () => onQuitar(productos[i]),
      ),
    );
  }
}

/// Ficha del catálogo de Cobrar.
///
/// Cuando el producto está en el carrito la ficha cambia de estado y se ve a un
/// metro: borde verde, fondo teñido y un badge con las unidades. Sin eso, la
/// única pista de que el toque entró era que subía el total, y el dueño con un
/// cliente delante tocaba otra vez por las dudas — cobrando doble y
/// descuadrando el inventario.
///
/// Quitar tiene un botón visible, no solo un gesto. El toque largo sobre la
/// ficha también resta —queda como atajo para quien lo descubra— pero un gesto
/// invisible no es una salida: quien agregó de más se quedaba sin forma de
/// deshacerlo salvo abriendo el carrito.
class _FichaProducto extends StatelessWidget {
  const _FichaProducto({
    required this.producto,
    required this.cantidad,
    required this.onTap,
    required this.onQuitar,
  });

  final Producto producto;

  /// Unidades de este producto en el carrito. `0` = ficha en estado normal.
  final int cantidad;
  final VoidCallback onTap;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final enCarrito = cantidad > 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: enCarrito ? onQuitar : null,
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: enCarrito ? 6 : 12,
          top: 10,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          // Verde de marca teñido, no un gris de "seleccionado": el estado
          // dice "esto ya está sumado", que es información de plata.
          color: enCarrito
              ? LibretaColors.verde.withValues(alpha: 0.10)
              : t.superficie,
          border: Border.all(
            color: enCarrito ? LibretaColors.verde : t.renglon,
            width: enCarrito ? 1.6 : 1,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: t.textoFuerte,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        producto.precioLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: producto.sePuedeVender
                              ? LibretaColors.verde
                              : LibretaColors.aviso,
                        ),
                      ),
                      if (producto.tieneOferta) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            MoneyFormatter.usd(producto.precioAnterior!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: t.textoMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (enCarrito) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  // Verde sobre blanco, no ámbar: el ámbar no pasa contraste
                  // sobre el papel claro de la app.
                  color: LibretaColors.verde,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '×$cantidad',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              // El botón se come el toque antes de que llegue a la ficha: si
              // burbujeara, quitar una unidad agregaría otra en el mismo gesto.
              GestureDetector(
                onTap: onQuitar,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: LibretaColors.verde),
                      ),
                      child: const Icon(
                        Icons.remove,
                        size: 15,
                        color: LibretaColors.verde,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// CTA de 56px con la sombra verde del diseño.
class _BotonCobrar extends StatelessWidget {
  const _BotonCobrar({
    required this.label,
    required this.icono,
    required this.cargando,
    required this.onPressed,
  });

  final String label;
  final IconData icono;
  final bool cargando;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: activo
            ? [
                BoxShadow(
                  color: LibretaColors.verde.withValues(alpha: .35),
                  offset: const Offset(0, 12),
                  blurRadius: 24,
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: activo ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: LibretaColors.verde,
            disabledBackgroundColor:
                LibretaColors.verde.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: cargando
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icono, size: 21, color: Colors.white),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
