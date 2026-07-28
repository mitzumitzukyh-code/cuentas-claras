import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../onboarding/domain/rubro.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';
import '../domain/variante.dart';
import 'widgets/escaner_codigo_barras.dart';

/// Pantalla 6 — Nuevo producto / Editar producto (réplica visual de
/// `P3 · NUEVO PRODUCTO`, `Lote C · Gastos y Productos`).
///
/// Zona de foto punteada, atajos de cámara y escáner, chips de categoría y los
/// campos de precio/stock lado a lado. Se adapta al rubro: foto obligatoria
/// (ropa/belleza/quincallería), variantes (ropa/belleza), vencimiento (belleza).
///
/// Con [producto] pasa a modo edición: cambia el título, aparecen el ajuste
/// rápido de stock y el botón de eliminar.
class NuevoProductoScreen extends ConsumerStatefulWidget {
  const NuevoProductoScreen({super.key, this.producto});

  /// `null` = alta. Con valor = edición de ese producto.
  final Producto? producto;

  @override
  ConsumerState<NuevoProductoScreen> createState() =>
      _NuevoProductoScreenState();
}

class _NuevoProductoScreenState extends ConsumerState<NuevoProductoScreen> {
  final _nombre = TextEditingController();
  final _precio = TextEditingController();
  final _costo = TextEditingController();
  final _cantidad = TextEditingController();
  final _alertaEn = TextEditingController(text: '5');

  String? _categoria;
  String? _codigoBarras;
  File? _foto;
  DateTime? _vencimiento;
  final List<Variante> _variantes = [];
  bool _vendidoPorPeso = false;
  bool _guardando = false;
  bool _leyendoIA = false;
  TipoProducto _tipo = TipoProducto.simple;
  bool _bloquearAlAgotarse = false;
  bool _enOferta = false;
  final _precioAnterior = TextEditingController();
  int? _garantiaMeses;

  bool get _editando => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p == null) return;
    _nombre.text = p.nombre;
    _precio.text = p.precio.toString();
    _costo.text = p.costo?.toString() ?? '';
    _cantidad.text = p.cantidad.toString();
    _alertaEn.text = (p.alertaEn ?? 5).toString();
    _categoria = p.categoria.isEmpty ? null : p.categoria;
    _codigoBarras = p.codigoBarras;
    _vencimiento = p.fechaVencimiento;
    _vendidoPorPeso = p.vendidoPorPeso;
    _variantes.addAll(p.variantes);
    _tipo = p.tipo;
    _bloquearAlAgotarse = p.bloquearAlAgotarse;
    _enOferta = p.enOferta;
    _precioAnterior.text = p.precioAnterior?.toString() ?? '';
    _garantiaMeses = p.garantiaMeses;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _precioAnterior.dispose();
    _precio.dispose();
    _costo.dispose();
    _cantidad.dispose();
    _alertaEn.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    final x = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (x == null || !mounted) return;
    setState(() => _foto = File(x.path));
    _mostrar('Foto agregada — se sube al guardar el producto.');
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanerCodigoBarras()),
    );
    if (codigo == null || !mounted) return;

    final productos = ref.read(productosProvider).valueOrNull ?? const [];
    final duplicado = productos
        .where((p) =>
            p.codigoBarras == codigo && p.id != (widget.producto?.id ?? ''))
        .firstOrNull;

    if (duplicado != null) {
      final usarIgual = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('Código ya registrado'),
          content: Text(
            'Este código ya lo tiene "${duplicado.nombre}". Si sigues, dos '
            'productos distintos quedarán con el mismo código de barras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              style: TextButton.styleFrom(foregroundColor: LibretaColors.peligro),
              child: const Text('Usar igual'),
            ),
          ],
        ),
      );
      if (usarIgual != true || !mounted) return;
    }

    setState(() => _codigoBarras = codigo);
    _mostrar('Código escaneado: $codigo');
  }

  /// Pide a la IA que sugiera un nombre a partir de la foto ya tomada.
  Future<void> _leerConIA() async {
    if (_foto == null) return;
    final config = (ref.read(negocioActivoProvider).valueOrNull?.rubro ??
            Rubro.otro)
        .config;
    setState(() => _leyendoIA = true);
    try {
      final sugerencia = await ref
          .read(lectorEtiquetaServiceProvider)
          .leer(_foto!, categorias: config.categoriasSugeridas);
      if (!mounted) return;

      var nombre = sugerencia.nombre;
      final presentacion = sugerencia.presentacion;
      if (presentacion != null &&
          !nombre.toLowerCase().contains(presentacion.toLowerCase())) {
        nombre = '$nombre $presentacion';
      }

      final nombreVacio = _nombre.text.trim().isEmpty;
      final categoriaVacia = _categoria == null;
      setState(() {
        if (nombreVacio) _nombre.text = nombre;
        if (sugerencia.categoria != null && categoriaVacia) {
          _categoria = sugerencia.categoria;
        }
        _leyendoIA = false;
      });
      if (!nombreVacio && (sugerencia.categoria == null || !categoriaVacia)) {
        _mostrar('Ya tenías nombre y categoría escritos: no se tocaron.');
      } else {
        _mostrar(
          sugerencia.confianza == 'alta'
              ? 'Datos sugeridos — revísalos antes de guardar'
              : 'Datos sugeridos, con dudas — revísalos bien antes de guardar',
        );
      }
    } on SinReconocer {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar('No reconocimos un producto claro en la foto.');
    } on LimiteDiarioIA {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar('Se agotaron las lecturas con IA por hoy. Vuelve mañana.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar('No se pudo leer la etiqueta: $e');
    }
  }

  Future<void> _elegirVencimiento() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 10),
    );
    if (fecha != null && mounted) setState(() => _vencimiento = fecha);
  }

  bool _puedeGuardar(RubroConfig config) {
    final precio = double.tryParse(_precio.text.replaceAll(',', '.'));
    final stockOk = config.usaVariantes
        ? _variantes.isNotEmpty
        : int.tryParse(_cantidad.text) != null;
    return _nombre.text.trim().isNotEmpty &&
        _categoria != null &&
        precio != null &&
        precio > 0 &&
        stockOk;
  }

  Future<void> _guardar(RubroConfig config) async {
    final faltaFoto = _foto == null && widget.producto?.fotoUrl == null;
    if (config.fotoObligatoria && faltaFoto) {
      _mostrar('La foto es obligatoria para este rubro.');
      return;
    }

    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;

    setState(() => _guardando = true);
    final repo = ref.read(productoRepositoryProvider);

    try {
      String? fotoUrl;
      String? avisoFoto;
      if (_foto != null) {
        try {
          fotoUrl = await repo.subirFoto(membresia.negocioId, _foto!);
        } on CloudinaryException catch (e) {
          if (config.fotoObligatoria) {
            setState(() => _guardando = false);
            _mostrar(e.mensaje);
            return;
          }
          avisoFoto = 'Se guardó sin la foto: ${e.mensaje}';
        } catch (_) {
          if (config.fotoObligatoria) {
            setState(() => _guardando = false);
            _mostrar(
              'Sin conexión no se puede subir la foto, y este rubro '
              'la exige. Intenta de nuevo cuando tengas señal.',
            );
            return;
          }
          avisoFoto =
              'Se guardó sin la foto (sin señal). Edítalo con conexión '
              'para añadirla.';
        }
      }

      final cantidadTotal = _variantes.isEmpty
          ? double.parse(_cantidad.text.replaceAll(',', '.'))
          : _variantes.fold<int>(0, (s, v) => s + v.cantidad).toDouble();

      final precioAnteriorValor = double.tryParse(_precioAnterior.text.replaceAll(',', '.'));
      final producto = Producto(
        id: widget.producto?.id ?? '',
        nombre: _nombre.text.trim(),
        categoria: _categoria ?? '',
        precio: double.parse(_precio.text.replaceAll(',', '.')),
        costo: double.tryParse(_costo.text.replaceAll(',', '.')),
        cantidad: cantidadTotal,
        fotoUrl: fotoUrl ?? widget.producto?.fotoUrl,
        variantes: _variantes,
        alertaEn: int.tryParse(_alertaEn.text),
        fechaVencimiento: _vencimiento,
        codigoBarras: _codigoBarras,
        vendidoPorPeso: _vendidoPorPeso,
        tipo: _tipo,
        bloquearAlAgotarse: _bloquearAlAgotarse,
        precioAnterior: _enOferta ? precioAnteriorValor : null,
        enOferta: _enOferta,
        garantiaMeses: _garantiaMeses,
      );

      final confirmado = _editando
          ? await repo.actualizar(membresia.negocioId, producto)
          : await repo.crear(membresia.negocioId, producto);
      if (!mounted) return;
      Navigator.of(context).pop();
      _mostrar(
        avisoFoto ??
            (confirmado
                ? (_editando ? 'Producto actualizado' : 'Producto agregado')
                : 'Guardado sin señal. Se sube solo cuando vuelva '
                    'la conexión.'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrar('No se pudo guardar: $e');
    }
  }

  /// Ajuste rápido de stock del modo edición (merma / reposición).
  void _ajustarStock(int delta) {
    final actual = int.tryParse(_cantidad.text) ?? 0;
    setState(() => _cantidad.text = (actual + delta).clamp(0, 999999).toString());
  }

  Future<void> _eliminar() async {
    final producto = widget.producto;
    final membresia = ref.read(membresiaActivaProvider);
    if (producto == null || membresia == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Eliminar "${producto.nombre}"?'),
        content: const Text(
          'El producto desaparecerá del inventario. Las ventas ya registradas '
          'conservan su nombre y precio, así que el historial no se altera.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: TextButton.styleFrom(foregroundColor: LibretaColors.peligro),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _guardando = true);
    try {
      final confirmado = await ref
          .read(productoRepositoryProvider)
          .eliminar(membresia.negocioId, producto.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      _mostrar(
        confirmado
            ? 'Producto eliminado'
            : 'Eliminado sin señal. Se sincroniza solo cuando vuelva '
                'la conexión.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrar('No se pudo eliminar: $e');
    }
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final config = (negocio?.rubro ?? Rubro.otro).config;

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
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
                    _editando ? 'Editar producto' : 'Nuevo producto',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ZonaFoto(
                    foto: _foto,
                    obligatoria: config.fotoObligatoria,
                    onTap: () => _elegirFoto(ImageSource.gallery),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: LibretaInput(
                      controller: _nombre,
                      label: 'Nombre',
                      hint: 'Ej: Harina PAN 1kg',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: LibretaSecondaryButton(
                      label: 'Tomar foto',
                      height: 44,
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      onPressed: () => _elegirFoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LibretaSecondaryButton(
                      label: _codigoBarras == null ? 'Escanear código' : 'Código ✓',
                      height: 44,
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      onPressed: _escanear,
                    ),
                  ),
                ],
              ),
              if (_foto != null) ...[
                const SizedBox(height: 10),
                LibretaSecondaryButton(
                  label: _leyendoIA ? 'Leyendo la foto…' : 'Sugerir nombre con IA',
                  height: 44,
                  icon: _leyendoIA
                      ? null
                      : const Icon(Icons.auto_awesome, size: 16),
                  onPressed: _leyendoIA ? null : _leerConIA,
                ),
              ],
              const SizedBox(height: 18),

              Text(
                'Categoría',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.libreta.textoMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in config.categoriasSugeridas)
                    LibretaChip(
                      label: c,
                      selected: _categoria == c,
                      onTap: () => setState(() => _categoria = c),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LibretaInput(
                      controller: _precio,
                      label: 'Precio (USD)',
                      hint: '0.00',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LibretaInput(
                      controller: _cantidad,
                      label: config.usaVariantes ? 'Stock (variantes)' : 'Stock inicial',
                      hint: '0',
                      enabled: !config.usaVariantes,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LibretaInput(
                controller: _costo,
                label: _vendidoPorPeso
                    ? 'Costo por kg (USD) — para calcular tu ganancia'
                    : 'Costo por unidad (USD) — para calcular tu ganancia',
                hint: 'Opcional',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (_editando) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ajuste rápido de stock',
                        style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
                      ),
                    ),
                    _BotonAjuste(
                      signo: '−',
                      color: LibretaColors.peligro,
                      onTap: () => _ajustarStock(-1),
                    ),
                    const SizedBox(width: 8),
                    _BotonAjuste(
                      signo: '+',
                      color: LibretaColors.verde,
                      onTap: () => _ajustarStock(1),
                    ),
                  ],
                ),
              ],

              // Ganancia en vivo
              if (_costo.text.isNotEmpty && double.tryParse(_costo.text.replaceAll(',', '.')) != null && double.tryParse(_precio.text.replaceAll(',', '.')) != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x1A0E9F6E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, size: 16, color: LibretaColors.verde),
                      const SizedBox(width: 6),
                      Text(
                        () {
                          final precio = double.tryParse(_precio.text.replaceAll(',', '.'))!;
                          final costo = double.tryParse(_costo.text.replaceAll(',', '.'))!;
                          final ganancia = precio - costo;
                          final pct = costo > 0 ? ((ganancia / costo) * 100).round() : 0;
                          return '${MoneyFormatter.usd(ganancia)} · $pct %';
                        }(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: LibretaColors.verde,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              LibretaInput(
                controller: _alertaEn,
                label: 'Avisarme cuando queden (unidades)',
                hint: '5',
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 18),

              // Tipo de producto
              Text(
                'Tipo de producto',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.libreta.textoMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TipoPill(label: 'Simple', selected: _tipo == TipoProducto.simple, onTap: () => setState(() => _tipo = TipoProducto.simple)),
                  if (config.usaVariantes)
                    _TipoPill(label: 'Con talla-color', selected: _tipo == TipoProducto.variantes, onTap: () => setState(() => _tipo = TipoProducto.variantes)),
                  _TipoPill(label: 'Con serial-garantía', selected: _tipo == TipoProducto.serial, onTap: () => setState(() => _tipo = TipoProducto.serial)),
                ],
              ),

              const SizedBox(height: 18),

              // Cuando el stock llegue a 0
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cuando el stock llegue a 0',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte)),
                          SizedBox(height: 2),
                          Text(_bloquearAlAgotarse ? 'No permitir más ventas' : 'Seguir vendiendo en negativo',
                            style: TextStyle(fontSize: 11, color: context.libreta.textoMuted)),
                        ],
                      ),
                    ),
                    LibretaToggle(
                      value: _bloquearAlAgotarse,
                      onChanged: (v) => setState(() => _bloquearAlAgotarse = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Ponerlo en oferta
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ponerlo en oferta',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte)),
                              SizedBox(height: 2),
                              Text('Mostrar precio anterior tachado',
                                style: TextStyle(fontSize: 11, color: context.libreta.textoMuted)),
                            ],
                          ),
                        ),
                        LibretaToggle(
                          value: _enOferta,
                          onChanged: (v) => setState(() => _enOferta = v),
                        ),
                      ],
                    ),
                    if (_enOferta) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LibretaInput(
                              controller: _precioAnterior,
                              label: 'Precio anterior (USD)',
                              hint: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_precioAnterior.text.isNotEmpty && double.tryParse(_precioAnterior.text.replaceAll(',', '.')) != null && double.tryParse(_precio.text.replaceAll(',', '.')) != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0x24F2A93C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '−${() {
                                  final ant = double.tryParse(_precioAnterior.text.replaceAll(',', '.'))!;
                                  final actual = double.tryParse(_precio.text.replaceAll(',', '.'))!;
                                  return ((ant - actual) / ant * 100).round().toString();
                                }()} %',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB07D1E)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // --- Vender por peso ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vender por peso (kg)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: context.libreta.textoFuerte,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'El precio se calculará según el peso ingresado',
                            style: TextStyle(fontSize: 11, color: context.libreta.textoMuted),
                          ),
                        ],
                      ),
                    ),
                    LibretaToggle(
                      value: _vendidoPorPeso,
                      onChanged: (v) => setState(() => _vendidoPorPeso = v),
                    ),
                  ],
                ),
              ),

              // Fecha de vencimiento — solo belleza.
              if (config.usaFechaVencimiento) ...[
                const SizedBox(height: 18),
                Text(
                  'Fecha de vencimiento (opcional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.libreta.textoMuted,
                  ),
                ),
                const SizedBox(height: 6),
                LibretaSecondaryButton(
                  label: _vencimiento == null
                      ? 'Elegir fecha'
                      : '${_vencimiento!.day}/${_vencimiento!.month}/${_vencimiento!.year}',
                  icon: const Icon(Icons.event_outlined, size: 18),
                  onPressed: _elegirVencimiento,
                ),
              ],

              // Variantes — ropa y belleza.
              if (config.usaVariantes) ...[
                const SizedBox(height: 24),
                _EditorVariantes(
                  etiquetas: config.etiquetasVariante,
                  variantes: _variantes,
                  onAgregar: (v) => setState(() => _variantes.add(v)),
                  onEliminar: (i) => setState(() => _variantes.removeAt(i)),
                ),
              ],

              // Receta (comida rápida) — requiere gestión de insumos, fuera de
              // la Fase 1.
              if (config.usaReceta) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x21F2A93C),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'La receta por insumos se habilita junto con la gestión de '
                    'insumos (pendiente).',
                    style: TextStyle(color: LibretaColors.aviso, fontSize: 13),
                  ),
                ),
              ],

              // Garantía — solo Electrónica.
              if ((negocio?.rubro ?? Rubro.otro) == Rubro.electronica) ...[
                const SizedBox(height: 20),
                Text(
                  'Garantía',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.libreta.textoMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TipoPill(label: 'Sin garantía', selected: _garantiaMeses == null, onTap: () => setState(() => _garantiaMeses = null)),
                    _TipoPill(label: '30 días', selected: _garantiaMeses == 1, onTap: () => setState(() => _garantiaMeses = 1)),
                    _TipoPill(label: '90 días', selected: _garantiaMeses == 3, onTap: () => setState(() => _garantiaMeses = 3)),
                  ],
                ),
              ],

              const SizedBox(height: 28),
              if (_editando) ...[
                LibretaSecondaryButton(
                  label: 'Eliminar producto',
                  onPressed: _guardando ? null : _eliminar,
                ),
                const SizedBox(height: 12),
              ],
              LibretaButton(
                label: _editando ? 'Guardar cambios' : 'Guardar producto',
                loading: _guardando,
                onPressed:
                    _puedeGuardar(config) ? () => _guardar(config) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado − / + del ajuste rápido de stock.
class _BotonAjuste extends StatelessWidget {
  const _BotonAjuste({
    required this.signo,
    required this.color,
    required this.onTap,
  });

  final String signo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: context.libreta.superficie,
          border: Border.all(color: context.libreta.bordeSuave),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          signo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Zona punteada para la foto del producto.
class _ZonaFoto extends StatelessWidget {
  const _ZonaFoto({
    required this.foto,
    required this.obligatoria,
    required this.onTap,
  });

  final File? foto;
  final bool obligatoria;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: context.libreta.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: obligatoria && foto == null
                ? const Color(0xFFF2A93C)
                : const Color(0x381E2A38),
            width: 1.5,
          ),
          image: foto == null
              ? null
              : DecorationImage(image: FileImage(foto!), fit: BoxFit.cover),
        ),
        child: foto != null
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 22, color: context.libreta.textoMuted),
                  SizedBox(height: 4),
                  Text(
                    'Foto',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Editor de variantes (ej: Talla + Color + cantidad).
class _EditorVariantes extends StatefulWidget {
  const _EditorVariantes({
    required this.etiquetas,
    required this.variantes,
    required this.onAgregar,
    required this.onEliminar,
  });

  final List<String> etiquetas;
  final List<Variante> variantes;
  final void Function(Variante) onAgregar;
  final void Function(int) onEliminar;

  @override
  State<_EditorVariantes> createState() => _EditorVariantesState();
}

class _EditorVariantesState extends State<_EditorVariantes> {
  final _valor = TextEditingController();
  final _color = TextEditingController();
  final _cantidad = TextEditingController();

  @override
  void dispose() {
    _valor.dispose();
    _color.dispose();
    _cantidad.dispose();
    super.dispose();
  }

  void _agregar() {
    final cantidad = int.tryParse(_cantidad.text) ?? 0;
    if (_valor.text.trim().isEmpty || cantidad <= 0) return;
    widget.onAgregar(
      Variante(
        valor: _valor.text.trim(),
        color: _color.text.trim().isEmpty ? null : _color.text.trim(),
        cantidad: cantidad,
      ),
    );
    _valor.clear();
    _color.clear();
    _cantidad.clear();
  }

  @override
  Widget build(BuildContext context) {
    final etiqueta1 =
        widget.etiquetas.isNotEmpty ? widget.etiquetas[0] : 'Valor';
    final etiqueta2 =
        widget.etiquetas.length > 1 ? widget.etiquetas[1] : 'Color';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Variantes',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.libreta.textoFuerte,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Agrega cada combinación con su cantidad.',
          style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.variantes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.libreta.superficie,
                border: Border.all(color: context.libreta.bordeSuave),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        widget.variantes[i].valor,
                        if (widget.variantes[i].color != null)
                          widget.variantes[i].color!,
                        '×${widget.variantes[i].cantidad}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: context.libreta.textoFuerte),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onEliminar(i),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: LibretaColors.peligro,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: LibretaInput(controller: _valor, hint: etiqueta1, height: 44),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LibretaInput(controller: _color, hint: etiqueta2, height: 44),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: LibretaInput(
                controller: _cantidad,
                hint: 'Cant.',
                height: 44,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            LibretaIconButton(icon: Icons.add, size: 44, onTap: _agregar),
          ],
        ),
      ],
    );
  }
}

class _TipoPill extends StatelessWidget {
  const _TipoPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? LibretaColors.verde : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? LibretaColors.verde : const Color(0x261E2A38),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : context.libreta.textoMuted,
          ),
        ),
      ),
    );
  }
}
