import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../core/utils/numero_ve.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';
import '../../../shared/utils/errores.dart';

/// Pantalla 9 — Registrar gasto (réplica visual de `P1 · REGISTRAR GASTO`,
/// `Lote C · Gastos y Productos`).
///
/// La foto del recibo es opcional; con ella la IA puede prellenar monto,
/// fecha, categoría y descripción — y como siempre, solo PRELLENA: el dueño
/// revisa y toca "Guardar", nada se registra solo.
class RegistrarGastoScreen extends ConsumerStatefulWidget {
  const RegistrarGastoScreen({super.key, this.gasto});

  /// `null` = alta. Con valor, la misma pantalla edita ese gasto: sin esto, un
  /// gasto con la fecha mal —lo que hace la IA cuando el recibo trae la del
  /// proveedor— solo se arreglaba desde la consola de Firebase.
  final Gasto? gasto;

  @override
  ConsumerState<RegistrarGastoScreen> createState() =>
      _RegistrarGastoScreenState();
}

class _RegistrarGastoScreenState extends ConsumerState<RegistrarGastoScreen> {
  final _monto = TextEditingController();
  final _descripcion = TextEditingController();

  CategoriaGasto _categoria = CategoriaGasto.mercancia;
  String? _subcategoria;
  DateTime _fecha = DateTime.now();
  File? _foto;
  bool _leyendoIA = false;
  bool _guardando = false;

  bool _categoriaTocada = false;

  /// Qué campos vienen de la lectura del recibo y el usuario no ha tocado.
  /// Se pintan distinto: un campo que puso la IA no puede verse igual que uno
  /// que escribió el dueño, o se guarda un dato equivocado sin notarlo.
  final Set<String> _deIA = {};

  /// Fecha que leyó la IA y todavía no se aplicó. Se ofrece, no se impone: lo
  /// que importa para el flujo de caja es cuándo salió la plata, no cuándo se
  /// emitió la factura.
  DateTime? _fechaSugerida;

  bool get _editando => widget.gasto != null;

  @override
  void initState() {
    super.initState();
    final g = widget.gasto;
    if (g == null) return;
    _monto.text = g.monto.toStringAsFixed(2);
    _descripcion.text = g.descripcion;
    _categoria = g.categoria;
    _subcategoria = g.subcategoria;
    _fecha = g.fecha;
  }

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  /// Por `normalizarNumeroVE` y no por `replaceAll(',', '.')`: con el apaño
  /// viejo un gasto de "1.500" se registraba como 1,5 —el punto se tomaba por
  /// decimal—, sin fallar ni avisar.
  double? get _montoValor => normalizarNumeroVE(_monto.text);

  bool get _puedeGuardar {
    final m = _montoValor;
    return m != null && m > 0 && !_guardando;
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    final x = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (x != null && mounted) setState(() => _foto = File(x.path));
  }

  Future<void> _leerRecibo() async {
    final foto = _foto;
    if (foto == null) return;
    setState(() => _leyendoIA = true);
    try {
      final datos =
          await ref.read(lectorEtiquetaServiceProvider).leerRecibo(foto);
      if (!mounted) return;

      final tasa = ref.read(bcvRateProvider).valueOrNull?.tasa;
      double? monto = datos.monto;
      var notaBs = '';
      if (monto != null && datos.moneda == 'VES') {
        if (tasa == null) {
          monto = null;
          notaBs = ' El monto venía en Bs y no hay tasa BCV: ingrésalo tú.';
        } else {
          monto = monto / tasa;
          notaBs = ' El monto venía en Bs y se convirtió con la tasa BCV.';
        }
      }

      final montoVacio = _monto.text.trim().isEmpty;
      final descripcionVacia = _descripcion.text.trim().isEmpty;
      final hoy = DateTime.now();
      final limiteFecha = DateTime(hoy.year - 2);
      setState(() {
        if (monto != null && montoVacio) {
          _monto.text = monto.toStringAsFixed(2);
          _deIA.add('monto');
        }
        // La fecha del recibo NO se aplica sola: se ofrece. Un recibo de julio
        // registrado en agosto es un gasto de agosto para el flujo de caja, y
        // aplicarla en silencio hacía que el gasto desapareciera del mes que
        // el dueño estaba mirando.
        if (datos.fecha != null &&
            !datos.fecha!.isAfter(hoy) &&
            !datos.fecha!.isBefore(limiteFecha) &&
            !_mismoDia(datos.fecha!, _fecha)) {
          _fechaSugerida = datos.fecha;
        }
        if (!_categoriaTocada && datos.categoria != null) {
          _categoria = CategoriaGasto.fromId(datos.categoria);
          _subcategoria = null;
          _deIA.add('categoria');
        }
        if (datos.descripcion != null && descripcionVacia) {
          _descripcion.text = datos.descripcion!;
          _deIA.add('descripcion');
        }
        _leyendoIA = false;
      });
      _mostrar('Datos sugeridos del recibo — revísalos antes de guardar.$notaBs');
    } on SinReconocer {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar('No reconocimos un recibo en la foto.');
    } on LimiteDiarioIA {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar('Se agotaron las lecturas con IA por hoy. Vuelve mañana.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _leyendoIA = false);
      _mostrar(mensajeDeError(e, accion: 'leer el recibo'));
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final limite = DateTime(hoy.year - 2);
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha.isBefore(limite) ? hoy : _fecha,
      firstDate: limite,
      lastDate: hoy,
    );
    if (fecha != null && mounted) {
      setState(() {
        _fecha = fecha;
        _deIA.remove('fecha');
        _fechaSugerida = null;
      });
    }
  }

  /// Aplica la fecha que leyó el recibo, con un toque.
  void _usarFechaSugerida() {
    final f = _fechaSugerida;
    if (f == null) return;
    setState(() {
      _fecha = f;
      _fechaSugerida = null;
      _deIA.add('fecha');
    });
  }

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  static String mesYAno(DateTime f) => '${_meses[f.month - 1]} ${f.year}';

  Future<void> _guardar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final monto = _montoValor;
    if (membresia == null || monto == null || monto <= 0) return;

    setState(() => _guardando = true);
    final repo = ref.read(gastoRepositoryProvider);

    try {
      String? fotoUrl;
      String? avisoFoto;
      if (_foto != null) {
        try {
          fotoUrl = await repo.subirFotoRecibo(membresia.negocioId, _foto!);
        } catch (_) {
          avisoFoto = 'Se guardó sin la foto del recibo (no se pudo subir).';
        }
      }

      final anterior = widget.gasto;
      final gasto = Gasto(
        id: anterior?.id ?? '',
        categoria: _categoria,
        subcategoria: _subcategoria,
        descripcion: _descripcion.text.trim(),
        monto: monto,
        fecha: _fecha,
        fotoReciboUrl: fotoUrl ?? anterior?.fotoReciboUrl,
        // La tasa se congela al registrar y no se reescribe al editar: es la
        // del día en que salió la plata (ver `Gasto.tasaUsada`).
        tasaUsada: anterior?.tasaUsada ?? ref.read(bcvRateProvider).valueOrNull?.tasa,
      );

      final confirmado = anterior == null
          ? await repo.crear(membresia.negocioId, gasto)
          : await repo.actualizar(membresia.negocioId, gasto);
      if (!mounted) return;

      // Si el gasto cae fuera del mes que la pantalla de destino está
      // mirando, se dice y se ofrece ir. Un "Gasto registrado: $104,86" a
      // secas dejaba al dueño mirando una lista vacía, convencido de que no
      // se había guardado.
      final mesVisible = ref.read(mesGastosProvider);
      final fueraDelMes =
          _fecha.year != mesVisible.year || _fecha.month != mesVisible.month;

      Navigator.of(context).pop();
      if (avisoFoto != null) {
        _mostrar(avisoFoto);
      } else if (!confirmado) {
        _mostrar('Guardado sin señal. Se sube solo cuando vuelva la conexión.');
      } else if (fueraDelMes) {
        _avisarOtroMes(gasto.fecha);
      } else {
        _mostrar(
          anterior == null
              ? 'Gasto registrado: ${MoneyFormatter.usd(monto)}'
              : 'Gasto actualizado: ${MoneyFormatter.usd(monto)}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrar(mensajeDeError(e, accion: 'guardar el gasto'));
    }
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  /// El gasto quedó en otro mes: se dice cuál y se ofrece ir a verlo.
  void _avisarOtroMes(DateTime fecha) {
    final mes = mesYAno(fecha);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gasto guardado en $mes'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Ver $mes',
          onPressed: () {
            ref.read(mesGastosProvider.notifier).state =
                DateTime(fecha.year, fecha.month);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;
    final monto = _montoValor;

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
                    _editando ? 'Editar gasto' : 'Nuevo gasto',
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

              // --- Recibo + IA ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: context.libreta.renglon),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_foto == null) ...[
                      Center(
                        child: GestureDetector(
                          onTap: () => _elegirFoto(ImageSource.camera),
                          child: const _ReciboPegado(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Text(
                          'toca para tomar la foto',
                          style: GoogleFonts.caveat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.libreta.textoMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Con el recibo a mano, la IA rellena el gasto por ti.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_foto != null) ...[
                      Text(
                        'Recibo listo. Puedes leerlo con IA o guardarlo como '
                        'comprobante.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _foto!,
                          height: 110,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_leyendoIA)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: LibretaSecondaryButton(
                              label: 'Cámara',
                              height: 38,
                              icon: const LibretaIcono(AppAssets.accCamara, size: 16),
                              onPressed: () => _elegirFoto(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LibretaSecondaryButton(
                              label: 'Galería',
                              height: 38,
                              icon: const Icon(Icons.image_outlined, size: 16),
                              onPressed: () => _elegirFoto(ImageSource.gallery),
                            ),
                          ),
                          if (_foto != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: LibretaSecondaryButton(
                                label: 'Leer con IA',
                                height: 38,
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                onPressed: _leerRecibo,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // --- Monto ---
              if (_deIA.contains('monto')) ...[
                const Align(alignment: Alignment.centerLeft, child: _SelloIA()),
                const SizedBox(height: 4),
              ],
              LibretaInput(
                controller: _monto,
                label: 'Monto (USD)',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
              if (monto != null && monto > 0 && tasa != null) ...[
                const SizedBox(height: 6),
                Text(
                  MoneyFormatter.usdComoBs(monto, tasa),
                  style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                ),
              ],
              const SizedBox(height: 18),

              // --- Categoría ---
              if (_deIA.contains('categoria')) ...[
                const Align(alignment: Alignment.centerLeft, child: _SelloIA()),
                const SizedBox(height: 4),
              ],
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
                  for (final c in CategoriaGasto.values)
                    LibretaChip(
                      label: _sinEmoji(c.etiqueta),
                      selected: _categoria == c,
                      onTap: () => setState(() {
                        _categoria = c;
                        _subcategoria = null;
                        _categoriaTocada = true;
                      }),
                    ),
                ],
              ),
              if (_categoria.subcategorias.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in _categoria.subcategorias)
                      LibretaChip(
                        label: s,
                        dense: true,
                        selected: _subcategoria == s,
                        onTap: () => setState(() {
                          _subcategoria = _subcategoria == s ? null : s;
                          _categoriaTocada = true;
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),

              // --- Descripción ---
              if (_deIA.contains('descripcion')) ...[
                const Align(alignment: Alignment.centerLeft, child: _SelloIA()),
                const SizedBox(height: 4),
              ],
              LibretaInput(
                controller: _descripcion,
                label: 'Descripción (opcional)',
                hint: 'Ej: Mercancía distribuidora Polar',
              ),
              const SizedBox(height: 18),

              // --- Fecha ---
              GestureDetector(
                onTap: _elegirFecha,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: context.libreta.renglon),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fecha del gasto',
                          style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                        ),
                      ),
                      Text(
                        '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: LibretaColors.verde,
                        ),
                      ),
                      if (_deIA.contains('fecha')) ...[
                        const SizedBox(width: 6),
                        const _SelloIA(),
                      ],
                    ],
                  ),
                ),
              ),

              // La fecha del recibo se ofrece, no se impone. Un toque la aplica.
              if (_fechaSugerida != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _usarFechaSugerida,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: LibretaColors.verde.withValues(alpha: 0.10),
                      border: Border.all(color: LibretaColors.verde),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                          color: LibretaColors.verde,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El recibo dice ${_fechaSugerida!.day}/'
                            '${_fechaSugerida!.month}/${_fechaSugerida!.year}'
                            ' — usar esa fecha',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: context.libreta.textoFuerte,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              LibretaButton(
                label: _editando ? 'Guardar cambios' : 'Guardar gasto',
                loading: _guardando,
                onPressed: _puedeGuardar ? _guardar : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quita el emoji de `etiqueta` — las categorías se muestran sin emoji aquí.
String _sinEmoji(String etiqueta) =>
    etiqueta.replaceFirst(RegExp(r'^\S+\s'), '');

/// Recibo pegado con dos tiras de cinta (`Lote C · P1`).
///
/// Ladeado −2,5° a propósito: el sistema libreta es papel, y un papel pegado
/// nunca queda recto. Es lo que separa esta pantalla de un formulario.
class _ReciboPegado extends StatelessWidget {
  const _ReciboPegado();

  static const _cinta = Color(0x8CE8D796);

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SizedBox(
      width: 170,
      height: 168,
      child: Transform.rotate(
        angle: -0.0436, // −2,5°
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: t.superficie,
                border: Border.all(color: t.renglon),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x241E2A38),
                    offset: Offset(0, 8),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LibretaIcono(AppAssets.navVentas,
                    size: 34,
                    color: t.textoMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Foto del recibo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 12,
              child: Transform.rotate(
                angle: -0.314, // −18°
                child: Container(width: 52, height: 22, color: _cinta),
              ),
            ),
            Positioned(
              top: 0,
              right: 10,
              child: Transform.rotate(
                angle: 0.262, // 15°
                child: Container(width: 52, height: 22, color: _cinta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marca de "esto lo puso la IA, revísalo".
///
/// Un campo prellenado por la lectura del recibo no puede verse igual que uno
/// escrito por el dueño: así fue como se guardó un gasto con la fecha del
/// proveedor sin que nadie lo notara.
class _SelloIA extends StatelessWidget {
  const _SelloIA();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: LibretaColors.verde.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 11,
            color: LibretaColors.verde,
          ),
          const SizedBox(width: 3),
          Text(
            'según el recibo',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: LibretaColors.verde,
            ),
          ),
        ],
      ),
    );
  }
}
