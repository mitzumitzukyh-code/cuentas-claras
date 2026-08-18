import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
import '../../../core/business/business_profile.dart';
import '../../../core/business/business_profile_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/numero_ve.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../onboarding/domain/rubro.dart';
import '../../planes/data/plan_repository.dart';
import '../../planes/domain/plan.dart';
import '../data/insumo_repository.dart';
import '../data/producto_repository.dart';
import '../domain/insumo.dart';
import '../domain/producto.dart';
import '../domain/variante.dart';
import 'widgets/escaner_codigo_barras.dart';
import 'widgets/extra_fields_section.dart';

/// Pantalla 6 — Nuevo producto / Editar producto (réplica visual de
/// `P3 · NUEVO PRODUCTO`, `Lote C · Gastos y Productos`).
///
/// Zona de foto punteada, atajos de cámara y escáner, chips de categoría y los
/// campos de precio/stock lado a lado.
///
/// Todo lo que cambia entre rubros sale del `BusinessProfile`: las unidades de
/// `allowedUnits`, los campos propios de `extraFields` (que pinta
/// [ExtraFieldsSection]) y las banderas que encienden bloques enteros —foto
/// obligatoria, variantes, receta, serial, peso—. Esta pantalla no sabe qué
/// rubro está activo y no debe averiguarlo.
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

  /// Unidad en la que se vende. `null` = todavía no se eligió y manda la
  /// unidad por defecto del perfil.
  String? _unidad;

  /// Valores de los campos propios del rubro, por clave. Los pinta
  /// [ExtraFieldsSection] a partir de `perfil.extraFields`.
  final Map<String, dynamic> _extras = {};
  final List<Variante> _variantes = [];
  final List<LineaReceta> _receta = [];
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
    // `precio` es nulable, y `toString()` sobre un nulo escribe la palabra
    // "null" en la casilla. Con eso el precio no parseaba, el boton de guardar
    // se quedaba apagado y no habia forma de editar un producto sin precio
    // -que es justo a lo que invita la lista con "ponle precio para venderlo"-.
    _precio.text = p.precio?.toString() ?? '';
    _costo.text = p.costo?.toString() ?? '';
    _cantidad.text = p.cantidad.toString();
    _alertaEn.text = (p.alertaEn ?? 5).toString();
    _categoria = p.categoria.isEmpty ? null : p.categoria;
    _codigoBarras = p.codigoBarras;
    _unidad = p.unidad;
    _extras.addAll(p.extras);
    // `vencimiento` tiene columna propia desde antes de que existieran los
    // campos extra; se sube al mapa para que la sección lo pinte como uno más.
    if (p.fechaVencimiento != null) _extras['vencimiento'] = p.fechaVencimiento;
    _vendidoPorPeso = p.vendidoPorPeso;
    _variantes.addAll(p.variantes);
    _receta.addAll(p.receta);
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
    final duplicado =
        productos
            .where(
              (p) =>
                  p.codigoBarras == codigo &&
                  p.id != (widget.producto?.id ?? ''),
            )
            .firstOrNull;

    if (duplicado != null) {
      final usarIgual = await showDialog<bool>(
        context: context,
        builder:
            (d) => AlertDialog(
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
                  style: TextButton.styleFrom(
                    foregroundColor: LibretaColors.peligro,
                  ),
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
    final rubro =
        ref.read(negocioActivoProvider).valueOrNull?.rubro ?? Rubro.otro;
    final config = rubro.config;
    setState(() => _leyendoIA = true);
    try {
      final sugerencia = await ref
          .read(lectorEtiquetaServiceProvider)
          .leer(
            _foto!,
            categorias: config.categoriasSugeridas,
            rubro: rubro.id,
          );
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
    } on LectorOcupado {
      // Saturado, no roto: la foto y la conexión están bien y lo
      // único que hace falta es esperar.
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar(
        'El lector está ocupado ahora mismo. Espera un momento y vuelve a intentarlo.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar('No se pudo leer la etiqueta: $e');
    }
  }

  /// Nombre del tipo de producto en el idioma del rubro.
  ///
  /// "Con talla-color" es lo que dice un vendedor de ropa; el de repuestos no
  /// vende tallas, vende medidas. La etiqueta se arma con las mismas
  /// [BusinessProfile.etiquetasVariante] que rotulan el editor, así que las dos
  /// no se pueden desincronizar.
  String _etiquetaTipo(TipoProducto tipo, BusinessProfile perfil) =>
      switch (tipo) {
        TipoProducto.simple => 'Simple',
        TipoProducto.serial => 'Con serial-garantía',
        TipoProducto.variantes =>
          perfil.etiquetasVariante.length > 1
              ? 'Con ${perfil.etiquetasVariante[0].toLowerCase()}-'
                  '${perfil.etiquetasVariante[1].toLowerCase()}'
              : 'Con variantes',
      };

  /// Lo escrito en una casilla de cifras, leído a la venezolana.
  ///
  /// Por `normalizarNumeroVE` y no por `replaceAll(',', '.')`: con el apaño
  /// viejo, un precio escrito como `1.250,50` se convertía en `1.250.50`, que
  /// no parsea — el botón de guardar se apagaba y nada decía por qué. El mismo
  /// número leído de una foto sí entraba, porque el importador ya usaba este
  /// lector.
  double? _cifra(TextEditingController campo) =>
      normalizarNumeroVE(campo.text);

  bool _puedeGuardar(BusinessProfile perfil) {
    final precio = _cifra(_precio);
    // La cantidad se valida como decimal porque así se guarda: con
    // `int.tryParse` un producto vendido por peso no se podía guardar con
    // «1,5» y el botón quedaba apagado sin motivo visible.
    final stockOk = perfil.usaVariantes
        ? _variantes.isNotEmpty
        : _cifra(_cantidad) != null;
    return _nombre.text.trim().isNotEmpty &&
        _categoria != null &&
        precio != null &&
        precio > 0 &&
        stockOk;
  }

  Future<void> _guardar(BusinessProfile perfil) async {
    final faltaFoto = _foto == null && widget.producto?.fotoUrl == null;
    if (perfil.fotoObligatoria && faltaFoto) {
      _mostrar('La foto es obligatoria para este rubro.');
      return;
    }

    // El tope del plan se mira al dar de alta, nunca al editar: un negocio que
    // ya tiene más productos de los que el plan gratis permite los conserva
    // todos y los puede seguir corrigiendo. Lo único que no puede es sumar uno
    // más.
    if (!_editando) {
      final limite = LimitePlan.cabeUnoMas(
        actuales: ref.read(productosProvider).valueOrNull?.length ?? 0,
        tope: ref.read(planDelNegocioProvider).maxProductos,
        mensaje: 'El plan gratis llega hasta '
            '${Plan.gratis.maxProductos} productos. Pásate a Plan Plus para '
            'seguir cargando.',
      );
      if (!limite.permitido) {
        _mostrar(limite.mensaje!);
        return;
      }
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
          if (perfil.fotoObligatoria) {
            setState(() => _guardando = false);
            _mostrar(e.mensaje);
            return;
          }
          avisoFoto = 'Se guardó sin la foto: ${e.mensaje}';
        } catch (_) {
          if (perfil.fotoObligatoria) {
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

      // Los mismos lectores que valida `_puedeGuardar`, y sin `parse` a pelo:
      // una excepción aquí caía en el catch de abajo y terminaba enseñándole
      // un `FormatException` al dueño.
      final cantidadTotal = _variantes.isEmpty
          ? (_cifra(_cantidad) ?? 0)
          : _variantes.fold<int>(0, (s, v) => s + v.cantidad).toDouble();

      final precioAnteriorValor = _cifra(_precioAnterior);
      final producto = Producto(
        id: widget.producto?.id ?? '',
        nombre: _nombre.text.trim(),
        categoria: _categoria ?? '',
        precio: _cifra(_precio),
        costo: _cifra(_costo),
        cantidad: cantidadTotal,
        fotoUrl: fotoUrl ?? widget.producto?.fotoUrl,
        variantes: _variantes,
        alertaEn: int.tryParse(_alertaEn.text),
        fechaVencimiento: _extras['vencimiento'] as DateTime?,
        codigoBarras: _codigoBarras,
        vendidoPorPeso: _vendidoPorPeso,
        tipo: _tipo,
        bloquearAlAgotarse: _bloquearAlAgotarse,
        precioAnterior: _enOferta ? precioAnteriorValor : null,
        enOferta: _enOferta,
        garantiaMeses: _garantiaMeses,
        receta: _receta,
        unidad: _unidad ?? perfil.defaultUnit,
        // `vencimiento` ya viajó a su columna: guardarlo también aquí sería
        // tener el mismo dato en dos sitios que pueden discrepar.
        extras: {..._extras}..remove('vencimiento'),
      );

      final confirmado =
          _editando
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
      _mostrar(mensajeDeError(e, accion: 'guardar el producto'));
    }
  }

  /// Ajuste rápido de stock del modo edición (merma / reposición).
  void _ajustarStock(int delta) {
    // En decimal, como se guarda. Con `int.tryParse` un producto de 1,5 kg
    // caía a 0 al tocar +/−: la cantidad no se leía y se partía de cero.
    final actual = _cifra(_cantidad) ?? 0;
    final nuevo = (actual + delta).clamp(0, 999999).toDouble();
    setState(() {
      // Sin `.0` de adorno cuando el resultado es entero, que es lo normal.
      _cantidad.text = nuevo == nuevo.roundToDouble()
          ? nuevo.toInt().toString()
          : nuevo.toString();
    });
  }

  Future<void> _eliminar() async {
    final producto = widget.producto;
    final membresia = ref.read(membresiaActivaProvider);
    if (producto == null || membresia == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (d) => AlertDialog(
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
                style: TextButton.styleFrom(
                  foregroundColor: LibretaColors.peligro,
                ),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final config = (negocio?.rubro ?? Rubro.otro).config;
    final perfil = ref.watch(businessProfileProvider);

    // Tipos de producto que este rubro admite. Un producto ya guardado con un
    // tipo que su rubro hoy no ofrece se agrega igual: si no, al editarlo la
    // fila desaparecería y no habría forma de devolverlo a "Simple".
    final tiposDisponibles = <TipoProducto>[
      TipoProducto.simple,
      if (perfil.usaVariantes) TipoProducto.variantes,
      if (perfil.usaSerial) TipoProducto.serial,
    ];
    if (!tiposDisponibles.contains(_tipo)) tiposDisponibles.add(_tipo);

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
                    obligatoria: perfil.fotoObligatoria,
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
                      icon: const LibretaIcono(AppAssets.accCamara, size: 16),
                      onPressed: () => _elegirFoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LibretaSecondaryButton(
                      label:
                          _codigoBarras == null
                              ? 'Escanear código'
                              : 'Código ✓',
                      height: 44,
                      icon: const LibretaIcono(AppAssets.accEscanear, size: 16),
                      onPressed: _escanear,
                    ),
                  ),
                ],
              ),
              if (_foto != null) ...[
                const SizedBox(height: 10),
                LibretaSecondaryButton(
                  label:
                      _leyendoIA ? 'Leyendo la foto…' : 'Sugerir nombre con IA',
                  height: 44,
                  icon:
                      _leyendoIA
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LibretaInput(
                      controller: _cantidad,
                      label:
                          perfil.usaVariantes
                              ? 'Stock (variantes)'
                              : 'Stock inicial',
                      hint: '0',
                      enabled: !perfil.usaVariantes,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              // Unidad en que se vende. Las opciones salen del perfil: una
              // panadería ofrece kg/docena/bandeja y una tienda de ropa
              // unidad/par, sin que esta pantalla sepa de rubros.
              const SizedBox(height: 14),
              Text(
                'Se vende por',
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
                  for (final u in perfil.allowedUnits)
                    LibretaChip(
                      label: u,
                      selected: (_unidad ?? perfil.defaultUnit) == u,
                      onTap: () => setState(() => _unidad = u),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              LibretaInput(
                controller: _costo,
                label:
                    _vendidoPorPeso
                        ? 'Costo por kg (USD) — para calcular tu ganancia'
                        : 'Costo por unidad (USD) — para calcular tu ganancia',
                hint: 'Opcional',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              if (_editando) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ajuste rápido de stock',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.libreta.textoMuted,
                        ),
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
              if (_costo.text.isNotEmpty &&
                  double.tryParse(_costo.text.replaceAll(',', '.')) != null &&
                  double.tryParse(_precio.text.replaceAll(',', '.')) !=
                      null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1A0E9F6E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 16,
                        color: LibretaColors.verde,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        () {
                          final precio =
                              double.tryParse(
                                _precio.text.replaceAll(',', '.'),
                              )!;
                          final costo =
                              double.tryParse(
                                _costo.text.replaceAll(',', '.'),
                              )!;
                          final ganancia = precio - costo;
                          final pct =
                              costo > 0
                                  ? ((ganancia / costo) * 100).round()
                                  : 0;
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

              // Tipo de producto — solo si el rubro ofrece más de uno. Con
              // una sola opción no hay nada que elegir: la fila era decorado
              // que además invitaba a marcar cosas sin sentido, como ponerle
              // "serial y garantía" a una hamburguesa.
              if (tiposDisponibles.length > 1) ...[
                const SizedBox(height: 18),

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
                    for (final tipo in tiposDisponibles)
                      _TipoPill(
                        label: _etiquetaTipo(tipo, perfil),
                        selected: _tipo == tipo,
                        onTap: () => setState(() => _tipo = tipo),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Cuando el stock llegue a 0
              Container(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cuando el stock llegue a 0',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: context.libreta.textoFuerte,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            _bloquearAlAgotarse
                                ? 'No permitir más ventas'
                                : 'Seguir vendiendo en negativo',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.libreta.textoMuted,
                            ),
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                              Text(
                                'Ponerlo en oferta',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.libreta.textoFuerte,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Mostrar precio anterior tachado',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.libreta.textoMuted,
                                ),
                              ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_precioAnterior.text.isNotEmpty &&
                              double.tryParse(
                                    _precioAnterior.text.replaceAll(',', '.'),
                                  ) !=
                                  null &&
                              double.tryParse(
                                    _precio.text.replaceAll(',', '.'),
                                  ) !=
                                  null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: LibretaColors.ambarSuperficie.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '−${() {
                                  final ant = double.tryParse(_precioAnterior.text.replaceAll(',', '.'))!;
                                  final actual = double.tryParse(_precio.text.replaceAll(',', '.'))!;
                                  return ((ant - actual) / ant * 100).round().toString();
                                }()} %',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFB07D1E),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // --- Vender por peso ---
              // Solo en los rubros que de verdad pesan mercancía. La segunda
              // condición es para no dejar huérfano a un producto que YA se
              // guardó por peso en un rubro donde hoy no se ofrece: sin ella,
              // al editarlo el interruptor desaparecería y no habría forma de
              // quitarle el peso.
              if (perfil.vendePorPeso || _vendidoPorPeso) ...[
                Container(
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
                              style: TextStyle(
                                fontSize: 11,
                                color: context.libreta.textoMuted,
                              ),
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
              ],

              // Campos propios del rubro. Esta sección es la única fuente de
              // qué campos extra se pintan: itera `perfil.extraFields` y no
              // sabe qué rubro está activo (CLAUDE.md §8.b).
              ExtraFieldsSection(
                campos: perfil.extraFields,
                valores: _extras,
                onCambio:
                    (clave, valor) => setState(() {
                      if (valor == null || valor == '') {
                        _extras.remove(clave);
                      } else {
                        _extras[clave] = valor;
                      }
                    }),
              ),

              // Variantes — según el perfil del negocio.
              if (perfil.usaVariantes) ...[
                const SizedBox(height: 24),
                _EditorVariantes(
                  etiquetas: perfil.etiquetasVariante,
                  variantes: _variantes,
                  onAgregar: (v) => setState(() => _variantes.add(v)),
                  onEliminar: (i) => setState(() => _variantes.removeAt(i)),
                ),
              ],

              // Receta (rubros que cocinan o arman) — Lote C · P3.
              if (perfil.usaReceta) ...[
                const SizedBox(height: 20),
                _EditorReceta(
                  receta: _receta,
                  onAgregar: (l) => setState(() => _receta.add(l)),
                  onEliminar: (i) => setState(() => _receta.removeAt(i)),
                ),
              ],

              // Garantía — va con el serial, así que la manda la misma
              // bandera del rubro y no una comparación suelta contra
              // `Rubro.electronica`. Con dos fuentes distintas, agregar un
              // rubro con serial dejaba la garantía fuera sin que se notara.
              if (perfil.usaSerial) ...[
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
                    _TipoPill(
                      label: 'Sin garantía',
                      selected: _garantiaMeses == null,
                      onTap: () => setState(() => _garantiaMeses = null),
                    ),
                    _TipoPill(
                      label: '30 días',
                      selected: _garantiaMeses == 1,
                      onTap: () => setState(() => _garantiaMeses = 1),
                    ),
                    _TipoPill(
                      label: '90 días',
                      selected: _garantiaMeses == 3,
                      onTap: () => setState(() => _garantiaMeses = 3),
                    ),
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
                    _puedeGuardar(perfil) ? () => _guardar(perfil) : null,
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
            color:
                obligatoria && foto == null
                    ? LibretaColors.ambarSuperficie
                    : const Color(0x381E2A38),
            width: 1.5,
          ),
          image:
              foto == null
                  ? null
                  : DecorationImage(image: FileImage(foto!), fit: BoxFit.cover),
        ),
        child:
            foto != null
                ? null
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    LibretaIcono(
                      AppAssets.accCamara,
                      size: 22,
                      color: context.libreta.textoMuted,
                    ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: context.libreta.textoFuerte,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => widget.onEliminar(i),
                    child: const LibretaIcono(
                      AppAssets.accCerrar,
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
              child: LibretaInput(
                controller: _valor,
                hint: etiqueta1,
                height: 44,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LibretaInput(
                controller: _color,
                hint: etiqueta2,
                height: 44,
              ),
            ),
            const SizedBox(width: 8),
            // 80 y no 64: `LibretaInput` se come 14px de padding por lado, así
            // que con 64 le quedaban 36 para el texto y "Cant." salía cortado
            // como "Ca…". Los 16px extra se los quitan Talla y Color, que con
            // palabras tan cortas los tenían de sobra.
            SizedBox(
              width: 80,
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
  const _TipoPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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

/// Receta del producto: qué insumos gasta cada unidad (`Lote C · P3`).
///
/// Solo deja elegir insumos ya dados de alta — escribir el nombre a mano
/// haría que la venta no supiera de qué existencia descontar.
class _EditorReceta extends ConsumerStatefulWidget {
  const _EditorReceta({
    required this.receta,
    required this.onAgregar,
    required this.onEliminar,
  });

  final List<LineaReceta> receta;
  final void Function(LineaReceta) onAgregar;
  final void Function(int) onEliminar;

  @override
  ConsumerState<_EditorReceta> createState() => _EditorRecetaState();
}

class _EditorRecetaState extends ConsumerState<_EditorReceta> {
  final _cantidad = TextEditingController();
  Insumo? _elegido;

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  void _agregar() {
    final insumo = _elegido;
    final cantidad = double.tryParse(_cantidad.text.replaceAll(',', '.')) ?? 0;
    if (insumo == null || cantidad <= 0) return;
    widget.onAgregar(
      LineaReceta(
        insumoId: insumo.id,
        nombre: insumo.nombre,
        cantidadUsada: cantidad,
        unidad: insumo.unidad,
      ),
    );
    _cantidad.clear();
    setState(() => _elegido = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final insumos = ref.watch(insumosProvider).valueOrNull ?? const <Insumo>[];
    final yaEnReceta = widget.receta.map((l) => l.insumoId).toSet();
    final disponibles =
        insumos.where((i) => !yaEnReceta.contains(i.id)).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.bordeSuave),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Receta / insumos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => context.push(Routes.insumos),
                child: const Text(
                  'Ver insumos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Al vender, se descuenta del inventario de insumos.',
            style: TextStyle(fontSize: 12, height: 1.4, color: t.textoMuted),
          ),
          const SizedBox(height: 10),

          for (var i = 0; i < widget.receta.length; i++)
            Container(
              height: 38,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.renglon)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.receta[i].nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.textoFuerte,
                      ),
                    ),
                  ),
                  Text(
                    widget.receta[i].cantidadLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textoMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => widget.onEliminar(i),
                    child: const LibretaIcono(
                      AppAssets.accCerrar,
                      size: 17,
                      color: LibretaColors.peligro,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),
          if (insumos.isEmpty)
            Text(
              'Todavía no tienes insumos cargados. Créalos primero en '
              '«Ver insumos» y vuelve para armar la receta.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: t.textoMuted,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<Insumo>(
                    value: _elegido,
                    isExpanded: true,
                    hint: const Text('Insumo', style: TextStyle(fontSize: 13)),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: t.papel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.bordeSuave),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: t.bordeSuave),
                      ),
                    ),
                    items: [
                      for (final i in disponibles)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i.nombre} (${i.cantidadLabel})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _elegido = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LibretaInput(
                    controller: _cantidad,
                    hint: _elegido?.unidad.corta ?? 'Cant.',
                    height: 44,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _agregar,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: LibretaColors.verde,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
