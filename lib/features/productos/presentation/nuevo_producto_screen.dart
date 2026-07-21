import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../onboarding/domain/rubro.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';
import '../domain/variante.dart';
import 'widgets/escaner_codigo_barras.dart';

/// Pantalla 6 — Nuevo producto / Editar producto (bloques `isNuevoProducto` e
/// `isEditMode` del diseño).
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
  }

  @override
  void dispose() {
    _nombre.dispose();
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

    // Mismo código en dos productos distintos suele ser un error de escaneo
    // (o el dueño escaneando el producto equivocado), no algo intencional:
    // se avisa y se deja decidir en vez de dejarlo pasar en silencio.
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
              style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
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
  ///
  /// Solo rellena el campo: el dueño sigue teniendo que revisarlo y tocar
  /// "Guardar producto" como siempre. El código de barras no pasa por aquí
  /// —lo lee `_escanear()`, con el escáner real— esto es solo para el
  /// nombre, que es lo que una foto puede sugerir con algo de confianza.
  Future<void> _leerConIA() async {
    if (_foto == null) return;
    final config = (ref.read(negocioActivoProvider).valueOrNull?.rubro ??
            Rubro.otro)
        .config;
    setState(() => _leyendoIA = true);
    try {
      // Se le mandan las categorías del rubro para que la sugerencia sea una
      // de ellas (el Worker descarta las inventadas por el modelo).
      final sugerencia = await ref
          .read(lectorEtiquetaServiceProvider)
          .leer(_foto!, categorias: config.categoriasSugeridas);
      if (!mounted) return;

      // El nombre ya suele traer la presentación ("Harina PAN 1kg"); si el
      // modelo la devolvió aparte y no está en el nombre, se añade.
      var nombre = sugerencia.nombre;
      final presentacion = sugerencia.presentacion;
      if (presentacion != null &&
          !nombre.toLowerCase().contains(presentacion.toLowerCase())) {
        nombre = '$nombre $presentacion';
      }

      // Si el dueño ya había escrito el nombre o elegido categoría a mano,
      // la sugerencia no lo pisa: solo rellena lo que está vacío. Si no
      // cambió nada, se avisa en vez de fingir que sí se sugirió algo.
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

  /// El botón principal solo se habilita con nombre, categoría y precio válido.
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
    // Al editar, la foto ya subida cuenta como cumplida.
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
          // Si el rubro exige foto no podemos continuar; si no, es una pena
          // perder el producto entero por un fallo de subida.
          if (config.fotoObligatoria) {
            setState(() => _guardando = false);
            _mostrar(e.mensaje);
            return;
          }
          avisoFoto = 'Se guardó sin la foto: ${e.mensaje}';
        } catch (_) {
          // Sin señal la foto no puede subirse (Cloudinary no tiene caché
          // local como Firestore). El producto sí puede guardarse; la foto
          // se añade después editándolo.
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

      // Con variantes, el stock total es la suma de sus cantidades.
      final cantidadTotal = _variantes.isEmpty
          ? double.parse(_cantidad.text.replaceAll(',', '.'))
          : _variantes.fold<int>(0, (s, v) => s + v.cantidad).toDouble();

      final producto = Producto(
        id: widget.producto?.id ?? '',
        nombre: _nombre.text.trim(),
        categoria: _categoria ?? '',
        precio: double.parse(_precio.text.replaceAll(',', '.')),
        costo: double.tryParse(_costo.text.replaceAll(',', '.')),
        cantidad: cantidadTotal,
        // Sin foto nueva se conserva la que ya tenía.
        fotoUrl: fotoUrl ?? widget.producto?.fotoUrl,
        variantes: _variantes,
        alertaEn: int.tryParse(_alertaEn.text),
        fechaVencimiento: _vencimiento,
        codigoBarras: _codigoBarras,
        vendidoPorPeso: _vendidoPorPeso,
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
            style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
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
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final config = (negocio?.rubro ?? Rubro.otro).config;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Row(
              children: [
                NeuIconBtn(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  _editando ? 'Editar producto' : 'Nuevo producto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            _ZonaFoto(
              foto: _foto,
              obligatoria: config.fotoObligatoria,
              onTap: () => _elegirFoto(ImageSource.gallery),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: NeuSecondaryButton(
                    label: 'Tomar foto',
                    height: 44,
                    radius: 16,
                    icon: const Text('📷', style: TextStyle(fontSize: 14)),
                    onPressed: () => _elegirFoto(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeuSecondaryButton(
                    label: _codigoBarras == null ? 'Escanear código' : 'Código ✓',
                    height: 44,
                    radius: 16,
                    icon: const Text('📊', style: TextStyle(fontSize: 14)),
                    onPressed: _escanear,
                  ),
                ),
              ],
            ),
            if (_foto != null) ...[
              const SizedBox(height: 10),
              NeuSecondaryButton(
                label: _leyendoIA ? 'Leyendo la foto…' : '🤖 Sugerir nombre con IA',
                height: 44,
                radius: 16,
                onPressed: _leyendoIA ? null : _leerConIA,
              ),
            ],
            const SizedBox(height: 18),

            NeuInput(
              controller: _nombre,
              label: 'Nombre',
              hint: 'Ej: Harina PAN 1kg',
              height: 48,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            Text(
              'Categoría',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.textSec,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in config.categoriasSugeridas)
                  NeuChip(
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
                  child: NeuInput(
                    controller: _precio,
                    label: 'Precio (USD)',
                    hint: '0.00',
                    height: 48,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeuInput(
                    controller: _cantidad,
                    label: config.usaVariantes ? 'Stock (variantes)' : 'Stock inicial',
                    hint: '0',
                    height: 48,
                    enabled: !config.usaVariantes,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // El costo es opcional: sin él la app funciona igual, pero la
            // ganancia de este producto no se puede calcular y los reportes
            // lo dirán. Se pide aquí, al lado del precio, para que capturarlo
            // sea natural y no un ajuste escondido.
            NeuInput(
              controller: _costo,
              label: _vendidoPorPeso
                  ? 'Costo por kg (USD) — para calcular tu ganancia'
                  : 'Costo por unidad (USD) — para calcular tu ganancia',
              hint: 'Opcional',
              height: 48,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            // Ajuste rápido de stock — solo al editar (merma o reposición).
            if (_editando) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ajuste rápido de stock',
                      style: TextStyle(fontSize: 12.5, color: t.textSec),
                    ),
                  ),
                  _BotonAjuste(
                    signo: '−',
                    color: AppColors.peligro,
                    onTap: () => _ajustarStock(-1),
                  ),
                  const SizedBox(width: 8),
                  _BotonAjuste(
                    signo: '+',
                    color: AppColors.marca,
                    onTap: () => _ajustarStock(1),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 18),

            NeuInput(
              controller: _alertaEn,
              label: 'Avisarme cuando queden (unidades)',
              hint: '5',
              height: 48,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 18),

            // --- Vender por peso ---
            NeuCard(
              small: true,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚖️ Vender por peso (kg)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'El precio se calculará según el peso ingresado',
                          style: TextStyle(fontSize: 11, color: t.textSec),
                        ),
                      ],
                    ),
                  ),
                  NeuToggle(
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
                  fontWeight: FontWeight.w600,
                  color: t.textSec,
                ),
              ),
              const SizedBox(height: 6),
              NeuSecondaryButton(
                label: _vencimiento == null
                    ? 'Elegir fecha'
                    : '${_vencimiento!.day}/${_vencimiento!.month}/${_vencimiento!.year}',
                height: 48,
                radius: 18,
                icon: Icon(Icons.event_outlined, size: 18, color: t.textSec),
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
                  color: AppColors.avisoSuave,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'La receta por insumos se habilita junto con la gestión de '
                  'insumos (pendiente).',
                  style: TextStyle(color: AppColors.aviso, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 28),
            if (_editando) ...[
              NeuSecondaryButton(
                label: 'Eliminar producto',
                color: AppColors.peligro,
                background: AppColors.peligroSuave,
                onPressed: _guardando ? null : _eliminar,
              ),
              const SizedBox(height: 12),
            ],
            NeuButton(
              label: _editando ? 'Guardar cambios' : 'Guardar producto',
              loading: _guardando,
              onPressed:
                  _puedeGuardar(config) ? () => _guardar(config) : null,
            ),
          ],
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
    return NeuCard(
      onTap: onTap,
      small: true,
      radius: 10,
      width: 34,
      height: 34,
      child: Center(
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
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: t.dashedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: obligatoria && foto == null
                ? AppColors.aviso
                : t.dashedBorder,
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
                  Text('＋', style: TextStyle(fontSize: 24, color: t.muted)),
                  const SizedBox(height: 6),
                  Text(
                    obligatoria
                        ? 'Foto del producto (obligatoria)'
                        : 'Foto del producto (opcional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.muted,
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
    final t = context.tokens;
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
            color: t.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Agrega cada combinación con su cantidad.',
          style: TextStyle(fontSize: 13, color: t.textSec),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.variantes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NeuCard(
              small: true,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      style: TextStyle(fontSize: 13, color: t.text),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onEliminar(i),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.peligro,
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
              child: NeuInput(
                controller: _valor,
                hint: etiqueta1,
                height: 44,
                radius: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NeuInput(
                controller: _color,
                hint: etiqueta2,
                height: 44,
                radius: 14,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: NeuInput(
                controller: _cantidad,
                hint: 'Cant.',
                height: 44,
                radius: 14,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            NeuIconBtn(icon: Icons.add, size: 44, radius: 14, onTap: _agregar),
          ],
        ),
      ],
    );
  }
}
