import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_links.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/captura_widget.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/estado_carga.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../planes/data/plan_repository.dart';
import '../../productos/data/producto_repository.dart';
import '../../productos/domain/producto.dart';
import '../../ventas/data/venta_repository.dart';
import '../../../shared/utils/errores.dart';

/// Formato de la imagen para el Estado de WhatsApp (`Lote O · P0`).
enum FormatoEstado {
  /// Hasta 6 productos con su precio.
  grilla,

  /// Un producto grande, para destacar.
  flyer,

  /// Cuatro productos y el total de llevárselos juntos.
  combo,

  /// Aviso de mercancía recién llegada.
  nuevo;

  String get titulo => switch (this) {
    FormatoEstado.grilla => 'Lista de precios',
    FormatoEstado.flyer => 'Oferta del día',
    FormatoEstado.combo => 'Combo',
    FormatoEstado.nuevo => 'Llegó nuevo',
  };

  String get detalle => switch (this) {
    FormatoEstado.grilla => 'hasta 6 productos',
    FormatoEstado.flyer => '1 producto grande',
    FormatoEstado.combo => '4 productos + total',
    FormatoEstado.nuevo => 'avisar mercancía',
  };

  /// Cuántos productos entran.
  int get cupo => switch (this) {
    FormatoEstado.grilla => 6,
    FormatoEstado.flyer => 1,
    FormatoEstado.combo => 4,
    FormatoEstado.nuevo => 3,
  };
}

/// Los tres pasos del asistente (`Lote O · P0-P2`).
enum _Paso { plantilla, productos, prevista }

/// Publicar en Estado (réplica visual de `P2 · ESTADO`, `Lote D · Planes y
/// Catálogo`).
///
/// Genera una imagen vertical 9:16 lista para subir. En grilla entran varios
/// productos; en flyer se destaca uno solo.
class EstadoScreen extends ConsumerStatefulWidget {
  const EstadoScreen({super.key});

  @override
  ConsumerState<EstadoScreen> createState() => _EstadoScreenState();
}

class _EstadoScreenState extends ConsumerState<EstadoScreen> {
  final _lienzo = GlobalKey();
  final _precioAnterior = TextEditingController();

  _Paso _paso = _Paso.plantilla;
  FormatoEstado _formato = FormatoEstado.grilla;

  /// Qué productos entran en la imagen. Vacío = todavía no eligió.
  final Set<String> _elegidos = {};

  Producto? _destacado;
  final int _plantilla = 0;
  bool _generando = false;

  /// "¡Oferta de hoy!" (réplica de `P4 · ESTADO EN WHATSAPP`) — es una
  /// anotación solo para esta imagen: no cambia el precio real del producto,
  /// que sigue viviendo en `Producto.precio`.
  final bool _esOferta = false;

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

  /// Todo el inventario, sin filtrar.
  /// Sin precio no se anuncia: un Estado es una lista de precios, y un
  /// renglón sin cifra solo genera preguntas que el dueño no quería responder.
  /// La excepción es "Llegó nuevo", que a propósito no lleva precios — pero ahí
  /// tampoco sirve un producto que ni siquiera se puede vender.
  List<Producto> get _todos =>
      (ref.watch(productosProvider).valueOrNull ?? const <Producto>[])
          .where((p) => p.sePuedeVender)
          .toList();

  /// Los productos que van a salir en la imagen, ya filtrados y ordenados.
  ///
  /// "Más vendidos" se ordena por unidades realmente vendidas en el
  /// historial, no por precio ni por fecha de alta: lo que mueve el negocio
  /// es lo que conviene anunciar.
  List<Producto> get _seleccion {
    var lista = _todos;

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
      lista = [...lista]
        ..sort((a, b) => (unidades[b.id] ?? 0).compareTo(unidades[a.id] ?? 0));
    }

    return lista;
  }

  /// Lo que finalmente se dibuja: solo lo elegido, en el orden de la lista.
  List<Producto> get _paraLienzo =>
      _todos.where((p) => _elegidos.contains(p.id)).toList();

  /// En "Oferta del día" se destaca un producto: elegir otro reemplaza.
  void _alternarProducto(Producto p) {
    setState(() {
      if (_formato.cupo == 1) {
        _elegidos
          ..clear()
          ..add(p.id);
        return;
      }
      if (!_elegidos.remove(p.id)) _elegidos.add(p.id);
    });
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
      await Share.shareXFiles([
        XFile(archivo.path),
      ], text: '📲 Hecho con Cuenta Clara — ${AppLinks.descargar}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeDeError(e, accion: 'generar la imagen'))),
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
      // Antes era un spinner sin fin: con un fallo de carga el negocio nunca
      // llega, y la pantalla giraba para siempre sin error ni salida.
      final negocioAsync = ref.watch(negocioActivoProvider);
      return Scaffold(
        backgroundColor: context.libreta.papel,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: negocioAsync.hasError
                  ? LibretaErrorCarga(
                      mensaje: mensajeDeError(
                        negocioAsync.error,
                        accion: 'cargar tu negocio',
                      ),
                      detalleTecnico: negocioAsync.error,
                      onReintentar: () =>
                          ref.invalidate(negocioActivoProvider),
                    )
                  : const LibretaCargando(),
            ),
          ),
        ),
      );
    }

    // El destacado del flyer es el único elegido; en la parrilla no aplica.
    _destacado = _todos.where((p) => _elegidos.contains(p.id)).firstOrNull;

    final precioAnterior = double.tryParse(
      _precioAnterior.text.replaceAll(',', '.'),
    );
    final telefono = negocio.telefonoParaCliente;
    final lienzo = _LienzoEstado(
      conMarcaDeAgua: ref.watch(planDelNegocioProvider).marcaDeAgua,
      formato: _formato,
      negocioNombre: negocio.nombre,
      productos: _paraLienzo,
      destacado: _destacado,
      colores:
          _oscuro
              ? (const Color(0xFF262420), const Color(0xFF141311))
              : _plantillas[_plantilla],
      tasa: _mostrarBs ? tasa : null,
      esOferta: _formato == FormatoEstado.flyer && _esOferta,
      precioAnterior: precioAnterior,
      telefono: _mostrarTelefono ? telefono : null,
      delivery: _mostrarDelivery,
    );

    if (_todos.isEmpty) {
      return Scaffold(
        backgroundColor: context.libreta.papel,
        body: LibretaPageBackground(
          child: SafeArea(
            // El botón de atrás va también aquí: esta rama devuelve su propio
            // Scaffold y se salta el encabezado del flujo normal, así que sin
            // él quien entra sin productos se queda sin salida visible.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  LibretaBackButton(oscuro: true),
                  SizedBox(height: 60),
                  LibretaEstadoVacio(
                    ilustracion: Ilustracion.sinProductos,
                    titulo: 'Todavía no tienes mercancía',
                    detalle:
                        'Carga tus productos y arma con ellos la imagen '
                        'para tu Estado de WhatsApp.',
                    tagline: 'tus precios, en la pantalla de todos',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // La prevista se pinta a pantalla completa sobre navy, sin el papel.
    if (_paso == _Paso.prevista) {
      return _Prevista(
        lienzo: lienzo,
        claveLienzo: _lienzo,
        formato: _formato,
        oscuro: _oscuro,
        generando: _generando,
        onFormato:
            (f) => setState(() {
              _formato = f;
              _oscuro = false;
            }),
        onOscuro: () => setState(() => _oscuro = !_oscuro),
        onCompartir: _compartir,
        onVolver: () => setState(() => _paso = _Paso.productos),
      );
    }

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child:
              _paso == _Paso.plantilla
                  ? _PasoPlantilla(
                    formato: _formato,
                    onFormato: (f) => setState(() => _formato = f),
                    onSiguiente: () => setState(() => _paso = _Paso.productos),
                  )
                  : _PasoProductos(
                    titulo: _formato.titulo,
                    cupo: _formato.cupo,
                    productos: _seleccion,
                    elegidos: _elegidos,
                    unicoDestacado: _formato.cupo == 1,
                    masVendidos: _soloMasVendidos,
                    mostrarBs: _mostrarBs,
                    mostrarTelefono: _mostrarTelefono,
                    telefonoDisponible: telefono != null,
                    delivery: _mostrarDelivery,
                    onBuscar: (v) => setState(() => _busqueda = v),
                    onMasVendidos:
                        () => setState(
                          () => _soloMasVendidos = !_soloMasVendidos,
                        ),
                    onAlternar: _alternarProducto,
                    onBs: () => setState(() => _mostrarBs = !_mostrarBs),
                    onTelefono:
                        () => setState(
                          () => _mostrarTelefono = !_mostrarTelefono,
                        ),
                    onDelivery:
                        () => setState(
                          () => _mostrarDelivery = !_mostrarDelivery,
                        ),
                    onAtras: () => setState(() => _paso = _Paso.plantilla),
                    onVer:
                        _elegidos.isEmpty
                            ? null
                            : () => setState(() => _paso = _Paso.prevista),
                  ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// P0 · Elegir plantilla
// ---------------------------------------------------------------------------

/// Primer paso: qué se va a mostrar (`Lote O · P0`).
class _PasoPlantilla extends StatelessWidget {
  const _PasoPlantilla({
    required this.formato,
    required this.onFormato,
    required this.onSiguiente,
  });

  final FormatoEstado formato;
  final ValueChanged<FormatoEstado> onFormato;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Publicar en Estado',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: t.textoFuerte,
                          ),
                        ),
                        Text(
                          '¿qué quieres mostrar hoy?',
                          style: GoogleFonts.caveat(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: LibretaColors.verde,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Lo que más frena al dueño es creer que su cliente necesita
              // instalar algo. Se responde antes de que lo pregunte.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 6, 13, 6),
                  decoration: BoxDecoration(
                    color: LibretaColors.tarjetaOscura,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 19,
                        height: 19,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: LibretaColors.verde,
                          shape: BoxShape.circle,
                        ),
                        child: const LibretaIcono(
                          AppAssets.accConfirmar,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Flexible(
                        child: Text(
                          'Tu cliente no instala nada — lo ve en tu Estado',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: LibretaAvisoOfflineCompacto(
                  copy: 'Sin conexión — necesitas internet para publicar',
                ),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
                children: [
                  for (final f in FormatoEstado.values)
                    _TarjetaPlantilla(
                      titulo: f.titulo,
                      detalle: f.detalle,
                      activa: formato == f,
                      vista: _VistaPlantilla(formato: f),
                      onTap: () => onFormato(f),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: BoxDecoration(
                  color: const Color(0x170E9F6E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: LibretaColors.verde,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'La lista de precios es la que más pedidos trae. Se '
                        'arma sola con lo que tengas en existencia.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: t.textoFuerte,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.renglon)),
          ),
          child: LibretaButton(
            label: 'Escoger productos',
            height: 54,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: Colors.white,
            ),
            onPressed: onSiguiente,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// P1 · Escoger productos
// ---------------------------------------------------------------------------

/// Segundo paso: qué entra en la imagen (`Lote O · P1`).
///
/// Escoger es una decisión aparte de cómo se ve: por eso tiene pantalla
/// propia, con el contador arriba y los interruptores de lo que se anuncia
/// al pie, junto al botón.
class _PasoProductos extends StatelessWidget {
  const _PasoProductos({
    required this.titulo,
    required this.cupo,
    required this.productos,
    required this.elegidos,
    required this.unicoDestacado,
    required this.masVendidos,
    required this.mostrarBs,
    required this.mostrarTelefono,
    required this.telefonoDisponible,
    required this.delivery,
    required this.onBuscar,
    required this.onMasVendidos,
    required this.onAlternar,
    required this.onBs,
    required this.onTelefono,
    required this.onDelivery,
    required this.onAtras,
    required this.onVer,
  });

  final String titulo;
  final int cupo;
  final List<Producto> productos;
  final Set<String> elegidos;
  final bool unicoDestacado;
  final bool masVendidos;
  final bool mostrarBs;
  final bool mostrarTelefono;
  final bool telefonoDisponible;
  final bool delivery;
  final ValueChanged<String> onBuscar;
  final VoidCallback onMasVendidos;
  final ValueChanged<Producto> onAlternar;
  final VoidCallback onBs;
  final VoidCallback onTelefono;
  final VoidCallback onDelivery;
  final VoidCallback onAtras;
  final VoidCallback? onVer;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 26, 18, 12),
          child: Column(
            children: [
              Row(
                children: [
                  LibretaBackButton(oscuro: true, onTap: onAtras),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: t.textoFuerte,
                          ),
                        ),
                        Text(
                          '${elegidos.length} de $cupo escogidos',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: LibretaColors.verde,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onMasVendidos,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: masVendidos ? LibretaColors.verde : t.superficie,
                        border: Border.all(
                          color:
                              masVendidos ? LibretaColors.verde : t.bordeSuave,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        'Más vendidos',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: masVendidos ? Colors.white : t.textoFuerte,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LibretaInput(
                hint: 'Buscar en mi mercancía…',
                height: 44,
                leading: LibretaIcono(
                  AppAssets.accBuscar,
                  size: 17,
                  color: t.textoMuted,
                ),
                onChanged: onBuscar,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            itemCount: productos.length,
            itemBuilder: (_, i) {
              final p = productos[i];
              final elegido = elegidos.contains(p.id);
              return _FilaEscoger(
                producto: p,
                elegido: elegido,
                // Con el cupo lleno solo se puede quitar, no agregar.
                bloqueado:
                    !elegido && !unicoDestacado && elegidos.length >= cupo,
                onTap: () => onAlternar(p),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.renglon)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 9,
                runSpacing: 8,
                children: [
                  _ChipAnuncio(
                    texto: 'Mostrar Bs',
                    activo: mostrarBs,
                    onTap: onBs,
                  ),
                  _ChipAnuncio(
                    texto: 'Mi teléfono',
                    activo: mostrarTelefono,
                    habilitado: telefonoDisponible,
                    onTap: onTelefono,
                  ),
                  _ChipAnuncio(
                    texto: 'Delivery',
                    activo: delivery,
                    onTap: onDelivery,
                  ),
                ],
              ),
              const SizedBox(height: 11),
              LibretaButton(
                label: 'Ver cómo queda',
                height: 54,
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                onPressed: onVer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Fila con casilla, existencia y precio en las dos monedas.
class _FilaEscoger extends ConsumerWidget {
  const _FilaEscoger({
    required this.producto,
    required this.elegido,
    required this.bloqueado,
    required this.onTap,
  });

  final Producto producto;
  final bool elegido;
  final bool bloqueado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;
    final poco = producto.stockBajo;

    return Opacity(
      opacity: bloqueado ? 0.45 : 1,
      child: GestureDetector(
        onTap: bloqueado ? null : onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: t.superficie,
            border: Border.all(
              color: elegido ? LibretaColors.verde : t.renglon,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: elegido ? LibretaColors.verde : Colors.transparent,
                  border:
                      elegido
                          ? null
                          : Border.all(color: t.bordeSuave, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    elegido
                        ? const LibretaIcono(
                          AppAssets.accConfirmar,
                          size: 14,
                          color: Colors.white,
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: t.textoFuerte,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      poco
                          ? 'quedan ${producto.cantidadLabel}'
                          : '${producto.cantidadLabel} en existencia',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: poco ? LibretaColors.peligro : t.textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    MoneyFormatter.usd(producto.precio!),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                    ),
                  ),
                  if (tasa != null)
                    Text(
                      MoneyFormatter.usdComoBs(producto.precio!, tasa),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.textoMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastilla de lo que se anuncia junto a los precios.
class _ChipAnuncio extends StatelessWidget {
  const _ChipAnuncio({
    required this.texto,
    required this.activo,
    required this.onTap,
    this.habilitado = true,
  });

  final String texto;
  final bool activo;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: habilitado ? onTap : null,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              activo
                  ? const Color(0x1F0E9F6E)
                  : t.textoFuerte.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activo) ...[
              const LibretaIcono(
                AppAssets.accConfirmar,
                size: 13,
                color: LibretaColors.verde,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              texto,
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w800 : FontWeight.w700,
                color:
                    !habilitado
                        ? t.textoMuted.withValues(alpha: 0.5)
                        : activo
                        ? LibretaColors.verde
                        : t.textoMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// P2 · Prevista
// ---------------------------------------------------------------------------

/// Tercer paso: la imagen tal cual va a salir, sobre navy (`Lote O · P2`).
///
/// Las pastillas de plantilla van aquí y no atrás: ver el resultado es cuando
/// uno se da cuenta de que quería la otra, y volver dos pantallas para probar
/// mata las ganas de probar.
class _Prevista extends StatelessWidget {
  const _Prevista({
    required this.lienzo,
    required this.claveLienzo,
    required this.formato,
    required this.oscuro,
    required this.generando,
    required this.onFormato,
    required this.onOscuro,
    required this.onCompartir,
    required this.onVolver,
  });

  final Widget lienzo;
  final GlobalKey claveLienzo;
  final FormatoEstado formato;
  final bool oscuro;
  final bool generando;
  final ValueChanged<FormatoEstado> onFormato;
  final VoidCallback onOscuro;
  final VoidCallback onCompartir;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF132030),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onVolver,
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x24FFFFFF),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Así queda',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: RepaintBoundary(key: claveLienzo, child: lienzo),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final f in FormatoEstado.values) ...[
                          _ChipPlantilla(
                            texto: f.titulo,
                            activo: formato == f && !oscuro,
                            onTap: () => onFormato(f),
                          ),
                          const SizedBox(width: 8),
                        ],
                        _ChipPlantilla(
                          texto: 'Oscuro',
                          activo: oscuro,
                          onTap: onOscuro,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  SizedBox(
                    height: 50,
                    child: LibretaButton(
                      label: generando ? 'Generando…' : 'Compartir en Estado',
                      loading: generando,
                      icon: const LibretaIcono(
                        AppAssets.accCompartir,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: generando ? null : onCompartir,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipPlantilla extends StatelessWidget {
  const _ChipPlantilla({
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? Colors.white : const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: activo ? FontWeight.w800 : FontWeight.w700,
            color:
                activo ? LibretaColors.tarjetaOscura : const Color(0xCCFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de plantilla con vista previa (`Lote O · P0`).
///
/// La miniatura vale más que el nombre: "grilla" y "flyer" no le dicen nada a
/// quien nunca publicó un Estado; el dibujito sí.
class _TarjetaPlantilla extends StatelessWidget {
  const _TarjetaPlantilla({
    required this.titulo,
    required this.detalle,
    required this.activa,
    required this.vista,
    required this.onTap,
  });

  final String titulo;
  final String detalle;
  final bool activa;
  final Widget vista;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: t.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: activa ? LibretaColors.verde : t.renglon,
            width: activa ? 2 : 1.5,
          ),
          boxShadow:
              activa
                  ? const [
                    BoxShadow(
                      color: Color(0x240E9F6E),
                      offset: Offset(0, 8),
                      blurRadius: 18,
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 96, child: vista),
            Container(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.renglon)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                    ),
                  ),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La miniatura que corresponde a cada plantilla.
class _VistaPlantilla extends StatelessWidget {
  const _VistaPlantilla({required this.formato});

  final FormatoEstado formato;

  @override
  Widget build(BuildContext context) => switch (formato) {
    FormatoEstado.grilla => const _VistaLista(),
    FormatoEstado.flyer => const _VistaOferta(),
    FormatoEstado.combo => const _VistaCombo(),
    FormatoEstado.nuevo => const _VistaNuevo(),
  };
}

/// Miniatura del combo: cuatro casillas de colores.
class _VistaCombo extends StatelessWidget {
  const _VistaCombo();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      color: t.papel,
      padding: const EdgeInsets.all(10),
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (final c in [
            const Color(0x240E9F6E),
            const Color(0x240E9F6E),
            const Color(0x1A1E2A38),
            LibretaColors.ambarSuperficie.withValues(alpha: .30),
          ])
            DecoratedBox(
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
    );
  }
}

/// Miniatura de "llegó nuevo": caja sobre navy.
class _VistaNuevo extends StatelessWidget {
  const _VistaNuevo();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LibretaColors.tarjetaOscura,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x24FFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              size: 22,
              color: LibretaColors.ambarSuperficie,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 56,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0x80FFFFFF),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de la lista de precios: renglones con su precio verde.
class _VistaLista extends StatelessWidget {
  const _VistaLista();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      color: t.papel,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 7,
            width: 52,
            decoration: BoxDecoration(
              color: LibretaColors.tarjetaOscura,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 5),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: t.textoFuerte.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 8,
                  width: 22,
                  decoration: BoxDecoration(
                    color: LibretaColors.verde,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            if (i < 3) const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

/// Miniatura de la oferta: una pastilla ámbar y un precio grande.
class _VistaOferta extends StatelessWidget {
  const _VistaOferta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4EFE4), Color(0xFFE3D0C2)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 9,
            width: 34,
            decoration: BoxDecoration(
              color: LibretaColors.ambarSuperficie,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 5),
          FractionallySizedBox(
            widthFactor: 0.74,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: LibretaColors.tarjetaOscura,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 5),
          FractionallySizedBox(
            widthFactor: 0.46,
            child: Container(
              height: 16,
              decoration: BoxDecoration(
                color: LibretaColors.verde,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    required this.conMarcaDeAgua,
  });

  final FormatoEstado formato;
  final String negocioNombre;
  final List<Producto> productos;
  final Producto? destacado;
  final (Color, Color) colores;
  final double? tasa;

  /// Si el pie con «Hecho con Cuenta Clara» va en la imagen. Lo decide el plan
  /// del dueño del negocio (CLAUDE.md §6): en gratis va, en Plan Plus no.
  final bool conMarcaDeAgua;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: LibretaColors.ambarSuperficie,
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
            child: switch (formato) {
              FormatoEstado.flyer => _Flyer(
                producto: destacado,
                tasa: tasa,
                precioAnterior: esOferta ? precioAnterior : null,
              ),
              FormatoEstado.combo => _Combo(productos: productos, tasa: tasa),
              FormatoEstado.nuevo => _LlegoNuevo(productos: productos),
              FormatoEstado.grilla => _Grilla(productos: productos, tasa: tasa),
            },
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
          if (conMarcaDeAgua) ...[
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
      childAspectRatio: 0.78,
      children: [
        for (final p in visibles)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (p.fotoUrl != null && p.fotoUrl!.isNotEmpty)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: double.infinity,
                        child: FotoRed(
                          p.fotoUrl!,
                          alError: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                if (p.fotoUrl != null && p.fotoUrl!.isNotEmpty)
                  const SizedBox(height: 7),
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
                      MoneyFormatter.usd(p.precio!),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (tasa != null)
                      Text(
                        MoneyFormatter.usdComoBs(p.precio!, tasa!),
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
        child: Text('Elige un producto', style: TextStyle(color: Colors.white)),
      );
    }

    final foto = p.fotoUrl;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (foto != null && foto.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 190,
                  height: 190,
                  child: FotoRed(foto, alError: const SizedBox.shrink()),
                ),
              ),
              const SizedBox(height: 18),
            ],
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
                  MoneyFormatter.usd(p.precio!),
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                if (precioAnterior != null && precioAnterior! > p.precio!) ...[
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
                MoneyFormatter.usdComoBs(p.precio!, tasa!),
                style: const TextStyle(fontSize: 15, color: Color(0xD9FFFFFF)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Combo: cuatro productos y lo que cuesta llevárselos juntos
/// (`Lote O · P0`).
class _Combo extends StatelessWidget {
  const _Combo({required this.productos, required this.tasa});

  final List<Producto> productos;
  final double? tasa;

  @override
  Widget build(BuildContext context) {
    final visibles = productos.take(4).toList();
    final total = visibles.fold<double>(0, (s, p) => s + p.precio!);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final p in visibles)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (p.fotoUrl != null && p.fotoUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: FotoRed(
                        p.fotoUrl!,
                        alError: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Text(
                    p.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  MoneyFormatter.usd(p.precio!),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0x3DFFFFFF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Text(
                'LLÉVATELO TODO POR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Color(0xB3FFFFFF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MoneyFormatter.usd(total),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: Colors.white,
                ),
              ),
              if (tasa != null)
                Text(
                  MoneyFormatter.usdComoBs(total, tasa!),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xB3FFFFFF),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Llegó nuevo": avisa mercancía recién entrada, sin precios
/// (`Lote O · P0`).
///
/// A propósito sin precio: el objetivo es que pregunten, y una foto sin cifra
/// es la que hace que escriban.
class _LlegoNuevo extends StatelessWidget {
  const _LlegoNuevo({required this.productos});

  final List<Producto> productos;

  @override
  Widget build(BuildContext context) {
    final visibles = productos.take(3).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: LibretaColors.ambarSuperficie,
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text(
            'LLEGÓ NUEVO',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: LibretaColors.tarjetaOscura,
            ),
          ),
        ),
        const SizedBox(height: 22),
        for (final p in visibles) ...[
          if (p.fotoUrl != null && p.fotoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 150,
                height: 150,
                child: FotoRed(p.fotoUrl!, alError: const SizedBox.shrink()),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            p.nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
        ],
        const Text(
          'Pregunta por el precio 👇',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xD9FFFFFF),
          ),
        ),
      ],
    );
  }
}
