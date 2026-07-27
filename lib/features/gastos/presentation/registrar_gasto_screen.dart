import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';

/// Pantalla 9 — Registrar gasto (réplica visual de `P1 · REGISTRAR GASTO`,
/// `Lote C · Gastos y Productos`).
///
/// La foto del recibo es opcional; con ella la IA puede prellenar monto,
/// fecha, categoría y descripción — y como siempre, solo PRELLENA: el dueño
/// revisa y toca "Guardar", nada se registra solo.
class RegistrarGastoScreen extends ConsumerStatefulWidget {
  const RegistrarGastoScreen({super.key});

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
  bool _fechaTocada = false;

  @override
  void dispose() {
    _monto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  double? get _montoValor =>
      double.tryParse(_monto.text.replaceAll(',', '.'));

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
        if (monto != null && montoVacio) _monto.text = monto.toStringAsFixed(2);
        if (!_fechaTocada &&
            datos.fecha != null &&
            !datos.fecha!.isAfter(hoy) &&
            !datos.fecha!.isBefore(limiteFecha)) {
          _fecha = datos.fecha!;
        }
        if (!_categoriaTocada && datos.categoria != null) {
          _categoria = CategoriaGasto.fromId(datos.categoria);
          _subcategoria = null;
        }
        if (datos.descripcion != null && descripcionVacia) {
          _descripcion.text = datos.descripcion!;
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
      _mostrar('No se pudo leer el recibo: $e');
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
        _fechaTocada = true;
      });
    }
  }

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

      final confirmado = await repo.crear(
        membresia.negocioId,
        Gasto(
          id: '',
          categoria: _categoria,
          subcategoria: _subcategoria,
          descripcion: _descripcion.text.trim(),
          monto: monto,
          fecha: _fecha,
          fotoReciboUrl: fotoUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _mostrar(
        avisoFoto ??
            (confirmado
                ? 'Gasto registrado: ${MoneyFormatter.usd(monto)}'
                : 'Guardado sin señal. Se sube solo cuando vuelva '
                    'la conexión.'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _mostrar('No se pudo guardar: $e');
    }
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
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
                    'Nuevo gasto',
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
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _foto == null
                          ? '¿Tienes el recibo a mano? Fotografíalo y la IA '
                              'rellena el gasto por ti.'
                          : 'Recibo listo. Puedes leerlo con IA o guardarlo '
                              'como comprobante.',
                      style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
                    ),
                    const SizedBox(height: 10),
                    if (_foto != null) ...[
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
                              icon: const Icon(Icons.photo_camera_outlined, size: 16),
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
                    border: Border.all(color: const Color(0x141E2A38)),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              LibretaButton(
                label: 'Guardar gasto',
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
