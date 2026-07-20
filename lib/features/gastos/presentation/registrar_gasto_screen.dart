import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';

/// Pantalla 9 — Registrar gasto.
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

      // Recibo en bolívares: se convierte a USD con la tasa BCV del día,
      // porque toda la contabilidad de la app va en dólares.
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

      setState(() {
        if (monto != null) _monto.text = monto.toStringAsFixed(2);
        if (datos.fecha != null && !datos.fecha!.isAfter(DateTime.now())) {
          _fecha = datos.fecha!;
        }
        if (datos.categoria != null) {
          _categoria = CategoriaGasto.fromId(datos.categoria);
          _subcategoria = null;
        }
        if (datos.descripcion != null) _descripcion.text = datos.descripcion!;
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
      // Un recibo con fecha fuera del rango (OCR de un papel viejo) no puede
      // ser el initialDate: el picker lo rechaza con un assert.
      initialDate: _fecha.isBefore(limite) ? hoy : _fecha,
      firstDate: limite,
      lastDate: hoy,
    );
    if (fecha != null && mounted) setState(() => _fecha = fecha);
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
          // El gasto vale más que su comprobante: se guarda sin la foto.
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
    final t = context.tokens;
    final tasa = ref.watch(bcvRateProvider).valueOrNull?.tasa;
    final monto = _montoValor;

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
                  'Registrar gasto',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // --- Recibo + IA ---
            NeuCard(
              small: true,
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _foto == null
                        ? '🧾 ¿Tienes el recibo a mano? Fotografíalo y la IA '
                            'rellena el gasto por ti.'
                        : '🧾 Recibo listo. Puedes leerlo con IA o guardarlo '
                            'como comprobante.',
                    style: TextStyle(fontSize: 12.5, color: t.textSec),
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
                          child: NeuSecondaryButton(
                            label: '📷 Cámara',
                            height: 38,
                            radius: 12,
                            onPressed: () => _elegirFoto(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: NeuSecondaryButton(
                            label: '🖼️ Galería',
                            height: 38,
                            radius: 12,
                            onPressed: () => _elegirFoto(ImageSource.gallery),
                          ),
                        ),
                        if (_foto != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: NeuSecondaryButton(
                              label: '✨ Leer con IA',
                              height: 38,
                              radius: 12,
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
            NeuInput(
              controller: _monto,
              label: 'Monto (USD)',
              hint: '0.00',
              height: 48,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            if (monto != null && monto > 0 && tasa != null) ...[
              const SizedBox(height: 6),
              Text(
                MoneyFormatter.usdComoBs(monto, tasa),
                style: TextStyle(fontSize: 12, color: t.textSec),
              ),
            ],
            const SizedBox(height: 18),

            // --- Categoría ---
            Text(
              'Categoría',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.textSec,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in CategoriaGasto.values)
                  NeuChip(
                    label: c.etiqueta,
                    selected: _categoria == c,
                    onTap: () => setState(() {
                      _categoria = c;
                      _subcategoria = null;
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
                    NeuChip(
                      label: s,
                      dense: true,
                      selected: _subcategoria == s,
                      onTap: () => setState(
                        () => _subcategoria = _subcategoria == s ? null : s,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),

            // --- Descripción ---
            NeuInput(
              controller: _descripcion,
              label: 'Descripción (opcional)',
              hint: 'Ej: Mercancía distribuidora Polar',
              height: 48,
            ),
            const SizedBox(height: 18),

            // --- Fecha ---
            NeuCard(
              small: true,
              radius: 16,
              onTap: _elegirFecha,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Fecha del gasto',
                      style: TextStyle(fontSize: 13, color: t.textSec),
                    ),
                  ),
                  Text(
                    '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.marca,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            NeuButton(
              label: 'Guardar gasto',
              height: 50,
              loading: _guardando,
              onPressed: _puedeGuardar ? _guardar : null,
            ),
          ],
        ),
      ),
    );
  }
}
