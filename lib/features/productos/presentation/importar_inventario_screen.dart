import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/numero_ve.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';

/// Importar inventario (réplica visual de `P1 · IMPORTAR INVENTARIO`,
/// `Lote K · Navegación`).
///
/// Reemplaza al diálogo modal que vivía en Productos: la foto de la libreta
/// y la carga manual pasan a esta pantalla propia, con la migración desde
/// otra app como acceso adicional.
class ImportarInventarioScreen extends ConsumerStatefulWidget {
  const ImportarInventarioScreen({super.key});

  @override
  ConsumerState<ImportarInventarioScreen> createState() =>
      _ImportarInventarioScreenState();
}

class _ImportarInventarioScreenState
    extends ConsumerState<ImportarInventarioScreen> {
  List<FilaLibreta> _filas = [];

  /// Lo que dijo la lectura además de las filas: qué clase de papel era y si
  /// el total declarado cuadra con lo leído.
  LecturaInventario? _lectura;
  bool _leyendo = false;
  bool _guardando = false;

  Future<void> _elegirFuente() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HojaFuente(),
    );
    if (fuente == null || !mounted) return;
    await _leerFoto(fuente);
  }

  Future<void> _leerFoto(ImageSource fuente) async {
    final x = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (x == null || !mounted) return;

    setState(() => _leyendo = true);
    try {
      final lectura = await ref
          .read(lectorEtiquetaServiceProvider)
          .leerLibreta(File(x.path));
      if (!mounted) return;
      setState(() {
        _lectura = lectura;
        _filas = lectura.filas;
        _leyendo = false;
      });
      if (lectura.filas.isEmpty) {
        _avisar('No reconocimos productos en la foto.');
      } else if (lectura.tipo == TipoDocumento.facturaCompra) {
        // Una factura de compra trae precios de COSTO. Cargarlos como precio
        // de venta deja al dueño vendiendo a lo que le costó, sin ganancia.
        _avisar(
          'Esto parece una factura de compra: los precios son de costo, no de '
          'venta. Revísalos antes de importar.',
        );
      } else if (!lectura.cuadra) {
        _avisar(
          'La lista dice ${lectura.totalDeclarado!.toStringAsFixed(0)} '
          'artículos y leímos otra cantidad. Revisa antes de importar.',
        );
      }
    } on SinReconocer {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar('No reconocimos una lista de productos en la foto.');
    } on LimiteDiarioIA {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar('Se agotaron las lecturas con IA por hoy. Vuelve mañana.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar(mensajeDeError(e, accion: 'leer la foto'));
    }
  }

  Future<void> _importar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (membresia == null || negocio == null || _filas.isEmpty) return;

    setState(() => _guardando = true);
    final categoria = negocio.rubro.config.categoriasSugeridas.firstOrNull ?? '';
    // `f.precio ?? 0` era el bug: cuando la lectura no podía con la cifra, el
    // producto entraba al inventario en $0,00 — y un producto en cero se puede
    // cobrar, así que se regalaba la mercancía. Ahora el precio ausente viaja
    // como `null` y el producto queda marcado para revisar: se ve en la
    // mercancía y no se puede agregar al carrito hasta que tenga precio.
    final nuevos = _filas
        .map((f) => Producto(
              id: '',
              nombre: f.nombre,
              categoria: categoria,
              precio: f.precio,
              cantidad: f.cantidad ?? 0,
              alertaEn: 5,
              requiereRevision: f.precio == null || f.cantidad == null,
            ))
        .toList();

    try {
      await ref
          .read(productoRepositoryProvider)
          .crearVarios(membresia.negocioId, nuevos);
      if (!mounted) return;
      final cantidad = nuevos.length;
      final sinPrecio = nuevos.where((p) => p.precio == null).length;
      Navigator.of(context).pop();
      // Si algo entró sin precio se dice en el momento. Callarlo es como el
      // gasto que se guardaba en otro mes: el dueño se entera cuando intenta
      // cobrarlo, con el cliente delante.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sinPrecio == 0
                ? '$cantidad productos importados'
                : '$cantidad productos importados · $sinPrecio sin precio, '
                    'ponles uno antes de venderlos',
          ),
          duration: Duration(seconds: sinPrecio == 0 ? 4 : 7),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(mensajeDeError(e, accion: 'importar los productos'));
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _proximamente() =>
      _avisar('Muy pronto podrás importar desde Excel o CSV.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar inventario',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.libreta.textoFuerte,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Carga tus productos sin escribir uno por uno.',
                          style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _FilaOpcion(
                icono: Icons.photo_camera_outlined,
                iconoVerde: true,
                titulo: 'Foto de tu lista',
                detalle: _leyendo
                    ? 'Leyendo tu foto…'
                    : 'La app lee nombres y precios de la foto',
                cargando: _leyendo,
                onTap: _leyendo ? null : _elegirFuente,
              ),
              const SizedBox(height: 12),
              _FilaOpcion(
                icono: Icons.description_outlined,
                titulo: 'Subir Excel o CSV',
                detalle: 'Desde otra app o tu computadora',
                proximamente: true,
                onTap: _proximamente,
              ),
              const SizedBox(height: 12),
              _FilaOpcion(
                icono: Icons.edit_outlined,
                titulo: 'Escribir a mano',
                detalle: 'Uno por uno, con calma',
                onTap: () => context.push(Routes.nuevoProducto),
              ),

              if (_filas.isNotEmpty) ...[
                const SizedBox(height: 20),
                if (_lectura?.tipo == TipoDocumento.facturaCompra)
                  _AvisoLectura(
                    texto: 'Esto parece una factura de compra: esos precios '
                        'son de COSTO, no de venta.',
                  )
                else if (_lectura?.cuadra == false)
                  _AvisoLectura(
                    texto: 'La lista declara '
                        '${_lectura!.totalDeclarado!.toStringAsFixed(0)} '
                        'artículos y lo leído suma otra cantidad.',
                  ),
                _TablaRevision(
                  filas: _filas,
                  onCambio: (nuevas) => setState(() => _filas = nuevas),
                ),
                const SizedBox(height: 16),
                LibretaButton(
                  label: _guardando
                      ? 'Importando…'
                      : 'Confirmar importación · ${_filas.length}',
                  loading: _guardando,
                  onPressed: _guardando || _filas.isEmpty ? null : _importar,
                ),
              ],

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.migrarOtraApp),
                  child: Text(
                    '¿Vienes de otra app?',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: LibretaColors.verde,
                    ),
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

/// Hoja para elegir cámara o galería al leer una foto.
class _HojaFuente extends StatelessWidget {
  const _HojaFuente();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: LibretaIcono(AppAssets.accCamara, color: t.textoFuerte),
              title: Text('Cámara', style: TextStyle(color: t.textoFuerte, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: t.textoFuerte),
              title: Text('Galería', style: TextStyle(color: t.textoFuerte, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila-tarjeta de una forma de importar (réplica de las 3 filas de P1).
class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.iconoVerde = false,
    this.cargando = false,
    this.proximamente = false,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final bool iconoVerde;
  final bool cargando;
  final bool proximamente;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.bordeSuave),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconoVerde ? LibretaColors.verde.withValues(alpha: .12) : t.bordeSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icono,
                size: 22,
                color: iconoVerde ? LibretaColors.verde : t.textoFuerte,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.textoFuerte),
                  ),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 12, color: t.textoMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (cargando)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else if (proximamente)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.bordeSuave,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Próximamente',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: t.textoMuted),
                ),
              )
            else
              Icon(Icons.chevron_right, size: 18, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}

/// Panel "Detectados de tu foto": vista previa de lo leído antes de importar.
/// La revisión antes de guardar.
///
/// Sin esto el dueño no tenía forma de atrapar los errores de la lectura: los
/// productos entraban al inventario tal como salieran, y los que salieron en
/// $0,00 solo se descubrían al intentar cobrarlos.
///
/// Lo dudoso —lo que no se pudo leer o se leyó con poca confianza— va en ámbar,
/// que es el color de "míralo", no de "está roto".
class _TablaRevision extends StatefulWidget {
  const _TablaRevision({required this.filas, required this.onCambio});

  final List<FilaLibreta> filas;

  /// Devuelve la lista completa cada vez que algo cambia: la pantalla es la
  /// dueña de los datos, esta tabla solo los edita.
  final ValueChanged<List<FilaLibreta>> onCambio;

  @override
  State<_TablaRevision> createState() => _TablaRevisionState();
}

class _TablaRevisionState extends State<_TablaRevision> {
  void _editar(int i, {double? precio, double? cantidad, bool quitar = false}) {
    final copia = [...widget.filas];
    if (quitar) {
      copia.removeAt(i);
    } else {
      copia[i] = copia[i].copyCon(precio: precio, cantidad: cantidad);
    }
    widget.onCambio(copia);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final dudosas = widget.filas.where((f) => f.dudosa).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVISA ANTES DE IMPORTAR',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: t.textoMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dudosas == 0
                ? '${widget.filas.length} productos leídos'
                : '${widget.filas.length} leídos · $dudosas por revisar',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: dudosas == 0 ? t.textoMuted : LibretaColors.aviso,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.filas.length; i++)
            _RenglonRevision(
              key: ValueKey('${widget.filas[i].clave}-$i'),
              fila: widget.filas[i],
              onPrecio: (v) => _editar(i, precio: v),
              onCantidad: (v) => _editar(i, cantidad: v),
              onQuitar: () => _editar(i, quitar: true),
            ),
        ],
      ),
    );
  }
}

class _RenglonRevision extends StatefulWidget {
  const _RenglonRevision({
    super.key,
    required this.fila,
    required this.onPrecio,
    required this.onCantidad,
    required this.onQuitar,
  });

  final FilaLibreta fila;
  final ValueChanged<double?> onPrecio;
  final ValueChanged<double?> onCantidad;
  final VoidCallback onQuitar;

  @override
  State<_RenglonRevision> createState() => _RenglonRevisionState();
}

class _RenglonRevisionState extends State<_RenglonRevision> {
  late final _precio = TextEditingController(
    text: widget.fila.precio?.toStringAsFixed(2) ?? '',
  );
  late final _cantidad = TextEditingController(
    text: widget.fila.cantidad == null
        ? ''
        : Producto.formatearCantidad(widget.fila.cantidad!, false),
  );

  @override
  void dispose() {
    _precio.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final f = widget.fila;
    final faltaPrecio = f.precio == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: f.dudosa
            ? LibretaColors.aviso.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border.all(
          color: f.dudosa ? LibretaColors.aviso : t.renglon,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: t.textoFuerte,
                  ),
                ),
              ),
              GestureDetector(
                onTap: widget.onQuitar,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(Icons.close, size: 18, color: t.textoMuted),
                ),
              ),
            ],
          ),
          if (f.codigo != null && f.codigo!.isNotEmpty ||
              f.talla != null && f.talla!.isNotEmpty ||
              f.color != null && f.color!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (f.codigo != null && f.codigo!.isNotEmpty) f.codigo!,
                  if (f.talla != null && f.talla!.isNotEmpty) f.talla!,
                  if (f.color != null && f.color!.isNotEmpty) f.color!,
                ].join(' · '),
                style: TextStyle(fontSize: 11.5, color: t.textoMuted),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LibretaInput(
                  controller: _precio,
                  label: 'Precio (USD)',
                  hint: faltaPrecio ? 'no se leyó' : '0.00',
                  height: 42,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => widget.onPrecio(normalizarPositivoVE(v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LibretaInput(
                  controller: _cantidad,
                  label: 'Existencia',
                  hint: f.cantidad == null ? 'no se leyó' : '0',
                  height: 42,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => widget.onCantidad(normalizarPositivoVE(v)),
                ),
              ),
            ],
          ),
          if (faltaPrecio)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Sin precio no se puede vender.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: LibretaColors.aviso,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Franja ámbar sobre la tabla cuando la lectura entera merece desconfianza.
class _AvisoLectura extends StatelessWidget {
  const _AvisoLectura({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LibretaColors.aviso.withValues(alpha: 0.12),
        border: Border.all(color: LibretaColors.aviso),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: LibretaColors.aviso),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: context.libreta.textoFuerte,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
