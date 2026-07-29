import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/captura_widget.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../productos/domain/producto.dart';
import '../../ventas/data/venta_repository.dart';

/// Formato de la imagen para el Estado de WhatsApp.
enum FormatoEstado { grilla, flyer }

/// Publicar en Estado (réplica visual de `P2 · ESTADO`, `Lote D · Planes y
/// Catálogo`).
///
/// Genera una imagen vertical 9:16 lista para subir. En grilla entran varios
/// productos; en flyer se destaca uno solo.
class EstadoScreen extends ConsumerStatefulWidget {
  const EstadoScreen({super.key, required this.productos});

  final List<Producto> productos;

  @override
  ConsumerState<EstadoScreen> createState() => _EstadoScreenState();
}

class _EstadoScreenState extends ConsumerState<EstadoScreen> {
  final _lienzo = GlobalKey();
  final _precioAnterior = TextEditingController();

  FormatoEstado _formato = FormatoEstado.grilla;
  Producto? _destacado;
  int _plantilla = 0;
  bool _generando = false;

  /// "¡Oferta de hoy!" (réplica de `P4 · ESTADO EN WHATSAPP`) — es una
  /// anotación solo para esta imagen: no cambia el precio real del producto,
  /// que sigue viviendo en `Producto.precio`.
  bool _esOferta = false;

  /// Filtros de la mercancía que entra en la imagen (Lote O · F7).
  String _busqueda = '';
  bool _soloMasVendidos = false;

  /// Qué se anuncia junto a los productos.
  bool _mostrarBs = true;
  bool _mostrarTelefono = false;
  bool _mostrarDelivery = false;

  /// Variante oscura de la imagen exportada.
  bool _oscuro = false;

  /// Plantillas de color del diseño.
  static const _plantillas = [
    (Color(0xFF0F6B5C), Color(0xFF0B4A40)),
    (Color(0xFF1B3A4B), Color(0xFF102530)),
    (Color(0xFFC9852B), Color(0xFF9A631C)),
    (Color(0xFF8A5FB0), Color(0xFF5F3F7D)),
  ];

  @override
  void initState() {
    super.initState();
    _destacado = widget.productos.firstOrNull;
  }

  /// Los productos que van a salir en la imagen, ya filtrados y ordenados.
  ///
  /// "Más vendidos" se ordena por unidades realmente vendidas en el
  /// historial, no por precio ni por fecha de alta: lo que mueve el negocio
  /// es lo que conviene anunciar.
  List<Producto> get _seleccion {
    var lista = widget.productos;

    final q = _busqueda.trim().toLowerCase();
    if (q.isNotEmpty) {
      lista = lista.where((p) => p.nombre.toLowerCase().contains(q)).toList();
    }

    if (_soloMasVendidos) {
      final ventas = ref.read(historialVentasProvider).valueOrNull ?? const [];
      final unidades = <String, double>{};
      for (final v in ventas.where((v) => !v.anulada)) {
        for (final i in v.items) {
          if (i.productoId.isEmpty) continue;
          unidades[i.productoId] = (unidades[i.productoId] ?? 0) + i.cantidad;
        }
      }
      lista = [...lista]..sort(
          (a, b) => (unidades[b.id] ?? 0).compareTo(unidades[a.id] ?? 0),
        );
    }

    return lista;
  }

  @override
  void dispose() {
    _precioAnterior.dispose();
    super.dispose();
  }

  Future<void> _compartir() async {
    setState(() => _generando = true);
    try {
      // 360×640 lógicos × 3 = 1080×1920, el tamaño que pide WhatsApp.
      final archivo = await CapturaWidget.aPng(
        _lienzo,
        escala: 3,
        nombre: 'estado',
      );
      await Share.shareXFiles(
        [XFile(archivo.path)],
        text: '📲 Hecho con Cuenta Clara — ${AppLinks.descargar}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo generar la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final precioAnterior =
        double.tryParse(_precioAnterior.text.replaceAll(',', '.'));
    final telefono = (negocio.telefonoContacto ?? '').trim().isEmpty
        ? null
        : negocio.telefonoContacto!.trim();
    final lienzo = _LienzoEstado(
      formato: _formato,
      negocioNombre: negocio.nombre,
      productos: _seleccion,
      destacado: _destacado,
      colores: _oscuro
          ? (const Color(0xFF262420), const Color(0xFF141311))
          : _plantillas[_plantilla],
      tasa: _mostrarBs ? tasa : null,
      esOferta: _formato == FormatoEstado.flyer && _esOferta,
      precioAnterior: precioAnterior,
      telefono: _mostrarTelefono ? telefono : null,
      delivery: _mostrarDelivery,
    );

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: widget.productos.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(24, 100, 24, 0),
                  child: LibretaEstadoVacio(
                    titulo: 'Catálogo vacío',
                    detalle: 'Agrega productos al catálogo para poder'
                        ' publicarlos en tu Estado de WhatsApp.',
                  ),
                )
              : ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Publicar en Estado',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: LibretaAvisoOfflineCompacto(
                  copy: 'Necesitas internet para publicar en Estado',
                ),
              ),
              const SizedBox(height: 18),

              // --- Formato ---
              Row(
                children: [
                  Expanded(
                    child: _Pestana(
                      texto: 'Grilla',
                      activa: _formato == FormatoEstado.grilla,
                      onTap: () =>
                          setState(() => _formato = FormatoEstado.grilla),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Pestana(
                      texto: 'Flyer destacado',
                      activa: _formato == FormatoEstado.flyer,
                      onTap: () =>
                          setState(() => _formato = FormatoEstado.flyer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              LibretaInput(
                hint: 'Buscar en mi mercancía…',
                height: 44,
                leading: const Icon(Icons.search, size: 18, color: LibretaColors.verde),
                onChanged: (v) => setState(() => _busqueda = v),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ChipFiltro(
                    texto: 'Más vendidos',
                    activo: _soloMasVendidos,
                    onTap: () => setState(
                      () => _soloMasVendidos = !_soloMasVendidos,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ChipFiltro(
                    texto: _oscuro ? 'Fondo oscuro' : 'Fondo claro',
                    activo: _oscuro,
                    onTap: () => setState(() => _oscuro = !_oscuro),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ToggleEstado(
                texto: 'Mostrar precios en Bs',
                valor: _mostrarBs,
                onChanged: (v) => setState(() => _mostrarBs = v),
              ),
              _ToggleEstado(
                texto: 'Mostrar mi teléfono',
                valor: _mostrarTelefono,
                detalle: telefono ?? 'Agrega tu teléfono en Ajustes',
                onChanged: telefono == null
                    ? null
                    : (v) => setState(() => _mostrarTelefono = v),
              ),
              _ToggleEstado(
                texto: 'Anunciar delivery',
                valor: _mostrarDelivery,
                onChanged: (v) => setState(() => _mostrarDelivery = v),
              ),
              const SizedBox(height: 14),

              if (_formato == FormatoEstado.grilla)
                Text(
                  'Se incluirán ${_seleccion.length.clamp(0, 6)} productos '
                  'del catálogo.',
                  style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                )
              else ...[
                Text(
                  'Elige el producto a destacar',
                  style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                ),
                const SizedBox(height: 10),
                for (final p in _seleccion)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _destacado = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.libreta.superficie,
                          border: Border.all(color: const Color(0x141E2A38)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _destacado?.id == p.id
                                    ? LibretaColors.verde
                                    : Colors.transparent,
                                border: Border.all(
                                  color: _destacado?.id == p.id
                                      ? LibretaColors.verde
                                      : context.libreta.bordeSuave,
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.libreta.textoFuerte,
                                ),
                              ),
                            ),
                            Text(
                              MoneyFormatter.usd(p.precio),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.libreta.textoFuerte,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: const Color(0x141E2A38)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '¡Oferta de hoy!',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: context.libreta.textoFuerte,
                              ),
                            ),
                          ),
                          LibretaToggle(
                            value: _esOferta,
                            onChanged: (v) => setState(() => _esOferta = v),
                          ),
                        ],
                      ),
                      if (_esOferta) ...[
                        const SizedBox(height: 10),
                        LibretaInput(
                          controller: _precioAnterior,
                          label: 'Precio anterior (USD)',
                          hint: 'Opcional — para mostrar el tachado',
                          height: 44,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // --- Plantillas de color ---
              Text(
                'Color',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.libreta.textoMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < _plantillas.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _plantilla = i),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _plantillas[i].$1,
                                _plantillas[i].$2,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _plantilla == i
                                  ? LibretaColors.verde
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // --- Vista previa (el mismo widget que se captura) ---
              Center(
                child: FittedBox(
                  child: RepaintBoundary(key: _lienzo, child: lienzo),
                ),
              ),
              const SizedBox(height: 18),

              LibretaButton(
                label: 'Compartir en Estado',
                loading: _generando,
                onPressed: widget.productos.isEmpty ? null : _compartir,
              ),
              const SizedBox(height: 10),
              Text(
                'Se abre WhatsApp para que la subas a tu Estado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro de la mercancía que entra en la imagen.
class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? LibretaColors.verde : t.superficie,
          border: Border.all(color: activo ? LibretaColors.verde : t.renglon),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: activo ? Colors.white : t.textoFuerte,
          ),
        ),
      ),
    );
  }
}

/// Interruptor de lo que se anuncia en la imagen del Estado.
class _ToggleEstado extends StatelessWidget {
  const _ToggleEstado({
    required this.texto,
    required this.valor,
    required this.onChanged,
    this.detalle,
  });

  final String texto;
  final bool valor;
  final String? detalle;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final activo = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: activo ? t.textoFuerte : t.textoMuted,
                  ),
                ),
                if (detalle != null)
                  Text(
                    detalle!,
                    style: TextStyle(fontSize: 11.5, color: t.textoMuted),
                  ),
              ],
            ),
          ),
          Switch(
            value: valor,
            onChanged: onChanged,
            activeTrackColor: LibretaColors.verde,
          ),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: activa ? LibretaColors.verde : context.libreta.superficie,
          border: activa ? null : Border.all(color: context.libreta.bordeSuave),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: activa ? Colors.white : context.libreta.textoFuerte,
          ),
        ),
      ),
    );
  }
}

/// La imagen 9:16 que se sube al Estado.
class _LienzoEstado extends StatelessWidget {
  const _LienzoEstado({
    required this.formato,
    required this.negocioNombre,
    required this.productos,
    required this.destacado,
    required this.colores,
    required this.tasa,
    required this.esOferta,
    required this.precioAnterior,
    this.telefono,
    this.delivery = false,
  });

  final FormatoEstado formato;
  final String negocioNombre;
  final List<Producto> productos;
  final Producto? destacado;
  final (Color, Color) colores;
  final double? tasa;

  /// "¡Oferta de hoy!" — solo aplica al formato flyer (`P4 · ESTADO EN
  /// WHATSAPP`).
  final bool esOferta;
  final double? precioAnterior;

  /// Contacto que se anuncia al pie de la imagen. `null` = no mostrarlo.
  final String? telefono;
  final bool delivery;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      height: 640,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colores.$1, colores.$2],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            negocioNombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          if (esOferta)
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2A93C),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  '¡OFERTA DE HOY!',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2A38),
                  ),
                ),
              ),
            )
          else
            const Text(
              'Disponible ahora',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)),
            ),
          const SizedBox(height: 28),

          Expanded(
            child: formato == FormatoEstado.flyer
                ? _Flyer(
                    producto: destacado,
                    tasa: tasa,
                    precioAnterior: esOferta ? precioAnterior : null,
                  )
                : _Grilla(productos: productos, tasa: tasa),
          ),

          const SizedBox(height: 16),
          if (telefono != null || delivery)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                [
                  if (telefono != null) '📱 $telefono',
                  if (delivery) '🛵 Hacemos delivery',
                ].join('   ·   '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xF2FFFFFF),
                ),
              ),
            ),
          if (tasa != null)
            Text(
              'Tasa BCV ${MoneyFormatter.bs(tasa!)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xB3FFFFFF)),
            ),
          const SizedBox(height: 8),
          const Text(
            'Hecho con Cuenta Clara',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0x80FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hasta 6 productos en dos columnas.
class _Grilla extends StatelessWidget {
  const _Grilla({required this.productos, required this.tasa});

  final List<Producto> productos;
  final double? tasa;

  @override
  Widget build(BuildContext context) {
    final visibles = productos.take(6).toList();
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        for (final p in visibles)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      MoneyFormatter.usd(p.precio),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (tasa != null)
                      Text(
                        MoneyFormatter.usdComoBs(p.precio, tasa!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Un solo producto en grande.
class _Flyer extends StatelessWidget {
  const _Flyer({
    required this.producto,
    required this.tasa,
    this.precioAnterior,
  });

  final Producto? producto;
  final double? tasa;

  /// Precio tachado del "¡Oferta de hoy!" — `null` = no mostrar tachado.
  final double? precioAnterior;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    if (p == null) {
      return const Center(
        child: Text(
          'Elige un producto',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              p.nombre,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  MoneyFormatter.usd(p.precio),
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                if (precioAnterior != null && precioAnterior! > p.precio) ...[
                  const SizedBox(width: 12),
                  Text(
                    MoneyFormatter.usd(precioAnterior!),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xA6FFFFFF),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
            if (tasa != null) ...[
              const SizedBox(height: 6),
              Text(
                MoneyFormatter.usdComoBs(p.precio, tasa!),
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xD9FFFFFF),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
