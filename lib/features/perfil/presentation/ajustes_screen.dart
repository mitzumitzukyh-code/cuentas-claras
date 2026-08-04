import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
import 'package:share_plus/share_plus.dart';
import '../../onboarding/domain/rubro.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_links.dart';
import 'legal_screen.dart';
import '../../../services/respaldo/respaldo_service.dart';
import '../../../core/providers/historial_tasa_provider.dart';
import '../../auth/data/biometria_service.dart';
import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../services/binance/binance_p2p_service.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../notificaciones/presentation/avisos_tasa_seccion.dart';
import '../../../shared/utils/errores.dart';

/// Ajustes de la cuenta (réplica visual de `P3 · AJUSTES`, `Lote E ·
/// Negocio y Perfil`).
///
/// Los ajustes están agrupados por tema: negocio, tasa de cambio, recibos,
/// avisos y apariencia. Los campos de texto solo se guardan al tocar
/// "Guardar cambios"; los interruptores y la foto, al ser una sola acción
/// deliberada, se guardan al toque.
class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  final _nombre = TextEditingController();
  final _reciboMensaje = TextEditingController();
  final _meta = TextEditingController();
  final _proveedor = TextEditingController();

  bool _inicializado = false;
  bool _sucio = false;
  bool _guardando = false;
  bool _subiendoFoto = false;

  @override
  void dispose() {
    _nombre.dispose();
    _reciboMensaje.dispose();
    _meta.dispose();
    _proveedor.dispose();
    super.dispose();
  }

  void _sembrar(Negocio n) {
    if (_inicializado) return;
    _inicializado = true;
    _nombre.text = n.nombre;
    _reciboMensaje.text = n.reciboMensaje;
    _meta.text =
        n.metaMensualUsd == 0 ? '' : n.metaMensualUsd.toStringAsFixed(0);
    _proveedor.text = n.proveedorWhatsapp ?? '';
  }

  void _marcarSucio() {
    if (!_sucio) setState(() => _sucio = true);
  }

  bool _exportando = false;

  /// Exporta ventas, gastos, productos y fiados a un .zip de CSV y lo comparte
  /// (`Lote E · P3`).
  ///
  /// CSV y no un formato propio: el dueño se lo manda al contador, que lo abre
  /// en Excel sin instalar nada. Un respaldo que solo esta app puede leer no
  /// es un respaldo.
  Future<void> _exportarNegocio() async {
    final membresia = ref.read(membresiaActivaProvider);
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (membresia == null || negocio == null || _exportando) return;

    setState(() => _exportando = true);
    try {
      final archivo = await ref
          .read(respaldoServiceProvider)
          .exportarZip(membresia.negocioId, negocio.nombre);
      if (!mounted) return;
      await Share.shareXFiles([
        XFile(archivo.path),
      ], subject: 'Respaldo de ${negocio.nombre}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'exportar tus datos')),
          backgroundColor: AppColors.peligro,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _guardarTexto(String negocioId) async {
    setState(() => _guardando = true);
    try {
      await ref
          .read(negocioRepositoryProvider)
          .actualizarAjustes(
            negocioId,
            nombre: _nombre.text.trim().isEmpty ? null : _nombre.text.trim(),
            reciboMensaje: _reciboMensaje.text.trim(),
            metaMensualUsd:
                double.tryParse(_meta.text.replaceAll(',', '.')) ?? 0,
            proveedorWhatsapp: _proveedor.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _sucio = false;
        _guardando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cambios guardados ✓')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'guardar los ajustes')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  Future<void> _guardarInterruptor(
    String negocioId, {
    bool? incluirIva,
    bool? alertaStock,
    bool? fotoComoFondo,
    bool? haceDelivery,
  }) async {
    try {
      await ref
          .read(negocioRepositoryProvider)
          .actualizarAjustes(
            negocioId,
            incluirIva: incluirIva,
            alertaStockActiva: alertaStock,
            haceDelivery: haceDelivery,
            fotoComoFondo: fotoComoFondo,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'guardar')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  /// Cambiar el rubro del negocio (Ajustes → Negocio → Tipo de negocio).
  ///
  /// El rubro es lo único que se pregunta en el onboarding y de él cuelga todo
  /// el perfil: vocabulario, unidades, qué campos pinta el formulario de
  /// producto y qué atajos salen en el Inicio. Cambiarlo no toca ni un producto
  /// guardado — solo cambia qué se muestra de aquí en adelante.
  Future<void> _abrirSelectorRubro(Negocio negocio) async {
    final elegido = await showModalBottomSheet<Rubro>(
      context: context,
      builder:
          (c) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in Rubro.values)
                    ListTile(
                      leading: LibretaIcono(r.icono, color: r.color),
                      title: Text(r.etiqueta),
                      trailing:
                          r == negocio.rubro ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.of(c).pop(r),
                    ),
                ],
              ),
            ),
          ),
    );

    if (elegido == null || elegido == negocio.rubro) return;
    try {
      await ref
          .read(negocioRepositoryProvider)
          .actualizarAjustes(negocio.id, rubro: elegido);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'guardar')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  Future<void> _abrirSelectorFoto(String negocioId) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (c) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const LibretaIcono(AppAssets.accCamara),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.of(c).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Elegir de la galería'),
                  onTap: () => Navigator.of(c).pop(ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
    if (origen != null) await _elegirFotoPerfil(negocioId, origen);
  }

  Future<void> _elegirFotoPerfil(String negocioId, ImageSource fuente) async {
    final x = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 75,
      maxWidth: 1000,
    );
    if (x == null || !mounted) return;

    setState(() => _subiendoFoto = true);
    try {
      final url = await ref
          .read(cloudinaryServiceProvider)
          .subirImagen(File(x.path), carpeta: 'cuenta-clara/$negocioId/perfil');
      await ref
          .read(negocioRepositoryProvider)
          .actualizarAjustes(negocioId, fotoUrl: url);
      if (!mounted) return;
      setState(() => _subiendoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'subir la foto')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final esDueno = ref.watch(esDuenoProvider);

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _sembrar(negocio);

    final tieneFoto = negocio.fotoUrl != null && negocio.fotoUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                child: Row(
                  children: [
                    LibretaBackButton(
                      oscuro: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ajustes',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.libreta.textoFuerte,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.libreta.renglon),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    if (!esDueno) ...[
                      _EntradaSuave(
                        orden: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x21F2A93C),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Como empleado solo puedes cambiar tus preferencias '
                            'personales, no la configuración del negocio.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: LibretaColors.aviso,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- Foto de perfil ---
                    _EntradaSuave(
                      orden: 1,
                      child: Column(
                        children: [
                          Center(
                            child: _AvatarEditable(
                              fotoUrl: negocio.fotoUrl,
                              inicial:
                                  negocio.nombre.isEmpty
                                      ? '?'
                                      : negocio.nombre[0].toUpperCase(),
                              subiendo: _subiendoFoto,
                              editable: esDueno,
                              onTap: () => _abrirSelectorFoto(negocio.id),
                            ),
                          ),
                          if (esDueno) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Toca la foto para cambiarla',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Negocio ---
                    _EntradaSuave(
                      orden: 2,
                      child: _SeccionAcordeon(
                        icono: Icons.storefront_outlined,
                        titulo: 'Negocio',
                        child: Column(
                          children: [
                            _Fila(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nombre del negocio',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.libreta.textoMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _nombre,
                                    enabled: esDueno,
                                    onChanged: (_) => _marcarSucio(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: context.libreta.textoFuerte,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _Fila(
                              onTap:
                                  esDueno
                                      ? () => _abrirSelectorRubro(negocio)
                                      : null,
                              child: _FilaSimple(
                                icono: Icons.tune_outlined,
                                texto: 'Tipo de negocio',
                                valor: negocio.rubro.etiqueta,
                              ),
                            ),
                            _Fila(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Meta de ventas mensual (USD)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.libreta.textoFuerte,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LibretaInput(
                                    controller: _meta,
                                    hint: '0',
                                    height: 42,
                                    enabled: esDueno,
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => _marcarSucio(),
                                  ),
                                ],
                              ),
                            ),
                            _Fila(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'WhatsApp del proveedor',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.libreta.textoFuerte,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Para pedir reabastecimiento cuando el '
                                    'stock esté bajo',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.libreta.textoMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  LibretaInput(
                                    controller: _proveedor,
                                    hint: 'Ej: 584121234567',
                                    height: 42,
                                    enabled: esDueno,
                                    keyboardType: TextInputType.phone,
                                    onChanged: (_) => _marcarSucio(),
                                  ),
                                  const SizedBox(height: 14),
                                  _FilaInterruptor(
                                    titulo: 'Hago delivery',
                                    detalle:
                                        'Se anuncia en el Estado y el catálogo',
                                    value: negocio.haceDelivery,
                                    onChanged:
                                        esDueno
                                            ? (v) => _guardarInterruptor(
                                              negocio.id,
                                              haceDelivery: v,
                                            )
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                            _Fila(
                              ultima: true,
                              onTap: () => context.push(Routes.unirseCodigo),
                              child: const _FilaSimple(
                                icono: Icons.group_add_outlined,
                                texto: 'Unirme a otro negocio',
                                valor: 'con un código',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Cobros y tasa ---
                    _EntradaSuave(
                      orden: 3,
                      child: _SeccionAcordeon(
                        icono: Icons.payments_outlined,
                        titulo: 'Cobros y tasa',
                        child: Column(
                          children: [
                            const _SelectorTasaAjustes(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'La tasa elegida se usa para convertir '
                                    'el total a bolívares al momento de '
                                    'cobrar.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.libreta.textoMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const _HistorialTasa(),
                                ],
                              ),
                            ),
                            _Fila(
                              child: _FilaInterruptor(
                                titulo: 'Incluir IVA en recibos',
                                detalle:
                                    'Sumamos el 16% automáticamente al total',
                                value: negocio.incluirIva,
                                onChanged:
                                    esDueno
                                        ? (v) => _guardarInterruptor(
                                          negocio.id,
                                          incluirIva: v,
                                        )
                                        : null,
                              ),
                            ),
                            _Fila(
                              ultima: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mensaje en el recibo',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.libreta.textoFuerte,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _reciboMensaje,
                                    enabled: esDueno,
                                    onChanged: (_) => _marcarSucio(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: context.libreta.textoMuted,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: 'Gracias por su compra',
                                      hintStyle: TextStyle(
                                        color: context.libreta.textoMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Avisos ---
                    _EntradaSuave(
                      orden: 4,
                      child: _SeccionAcordeon(
                        icono: Icons.notifications_none_rounded,
                        titulo: 'Avisos',
                        child: Column(
                          children: [
                            _Fila(
                              ultima: true,
                              child: _FilaInterruptor(
                                titulo: 'Avísame si baja el stock',
                                detalle:
                                    'Te avisamos antes de que se agote algo',
                                value: negocio.alertaStockActiva,
                                onChanged:
                                    esDueno
                                        ? (v) => _guardarInterruptor(
                                          negocio.id,
                                          alertaStock: v,
                                        )
                                        : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                14,
                              ),
                              child: const AvisosTasaSeccion(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Apariencia ---
                    _EntradaSuave(
                      orden: 5,
                      child: _SeccionAcordeon(
                        icono: Icons.palette_outlined,
                        titulo: 'Apariencia',
                        child: Column(
                          children: [
                            _Fila(
                              ultima: !tieneFoto,
                              child: _FilaInterruptor(
                                titulo: 'Modo oscuro',
                                detalle:
                                    'Reduce la fatiga visual con una interfaz '
                                    'más oscura',
                                value:
                                    ref.watch(themeModeProvider) ==
                                    ThemeMode.dark,
                                onChanged:
                                    (v) =>
                                        ref
                                            .read(themeModeProvider.notifier)
                                            .alternar(),
                              ),
                            ),
                            if (tieneFoto)
                              _Fila(
                                ultima: true,
                                child: _FilaInterruptor(
                                  titulo: 'Usar tu foto de fondo en el Inicio',
                                  detalle:
                                      'Se muestra detrás del dashboard, con '
                                      'un velo para que el texto se siga '
                                      'leyendo',
                                  value: negocio.fotoComoFondo,
                                  onChanged:
                                      esDueno
                                          ? (v) => _guardarInterruptor(
                                            negocio.id,
                                            fotoComoFondo: v,
                                          )
                                          : null,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Seguridad y datos ---
                    _EntradaSuave(
                      orden: 6,
                      child: _SeccionAcordeon(
                        icono: Icons.lock_outline_rounded,
                        titulo: 'Seguridad y datos',
                        child: Column(
                          children: [
                            _Fila(child: const _InterruptorBiometria()),
                            _Fila(
                              onTap: esDueno ? _exportarNegocio : null,
                              child: _FilaSimple(
                                icono: Icons.file_download_outlined,
                                texto: 'Exportar todo mi negocio',
                                valor: _exportando ? 'generando…' : '.zip',
                              ),
                            ),
                            _Fila(
                              ultima: true,
                              onTap:
                                  esDueno
                                      ? () => context.push(Routes.auditoria)
                                      : null,
                              child: _FilaSimple(
                                icono: Icons.fact_check_outlined,
                                texto: 'Historial de auditoría',
                                valor: 'quién hizo qué',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Legal ---
                    _EntradaSuave(
                      orden: 7,
                      child: _SeccionAcordeon(
                        icono: Icons.gavel_outlined,
                        titulo: 'Legal',
                        child: Column(
                          children: [
                            _Fila(
                              onTap:
                                  () => LegalScreen.abrir(
                                    context,
                                    DocumentoLegal.privacidad,
                                  ),
                              child: _FilaLegal(
                                texto: 'Política de privacidad',
                              ),
                            ),
                            _Fila(
                              ultima: true,
                              onTap:
                                  () => LegalScreen.abrir(
                                    context,
                                    DocumentoLegal.terminos,
                                  ),
                              child: _FilaLegal(texto: 'Términos de uso'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    Center(
                      child: Text(
                        'Cuenta Clara · v${AppLinks.version}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child:
                    (_sucio && esDueno)
                        ? _BarraGuardar(
                          guardando: _guardando,
                          onGuardar: () => _guardarTexto(negocio.id),
                        )
                        : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de tasa BCV/Binance (réplica exacta de `P3 · AJUSTES`) — usa el
/// mismo `tasaActivaProvider` que Cobrar (Lote B): la elección se comparte en
/// toda la app.
class _SelectorTasaAjustes extends ConsumerWidget {
  const _SelectorTasaAjustes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipo = ref.watch(tasaActivaProvider);
    final bcv = ref.watch(bcvRateProvider).valueOrNull?.tasa;
    final binance = ref.watch(binanceP2PRateProvider).valueOrNull?.precio;

    return Column(
      children: [
        _FilaTasa(
          seleccionada: tipo == TipoTasa.bcv,
          titulo: 'BCV',
          subtitulo: 'Banco Central de Venezuela',
          calificador: 'oficial',
          valor: bcv,
          onTap:
              () => ref.read(tasaActivaProvider.notifier).elegir(TipoTasa.bcv),
        ),
        _FilaTasa(
          seleccionada: tipo == TipoTasa.binance,
          titulo: 'Paralelo',
          subtitulo: 'mercado P2P',
          calificador: 'paralelo',
          valor: binance,
          ultima: true,
          onTap:
              () => ref
                  .read(tasaActivaProvider.notifier)
                  .elegir(TipoTasa.binance),
        ),
      ],
    );
  }
}

/// Últimos días de la tasa activa (Lote E · F5.4).
///
/// Solo aparece si hay al menos dos días guardados: un solo renglón repitiendo
/// lo que ya dice el selector de arriba no informa nada.
/// Fila de la sección Legal: solo texto y chevron.
class _FilaLegal extends StatelessWidget {
  const _FilaLegal({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: t.textoFuerte,
            ),
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: t.textoMuted),
      ],
    );
  }
}

/// Fila de Ajustes con icono, texto y un valor opcional a la derecha.
class _FilaSimple extends StatelessWidget {
  const _FilaSimple({required this.icono, required this.texto, this.valor});

  final IconData icono;
  final String texto;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Row(
      children: [
        Icon(icono, size: 20, color: t.textoFuerte),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: t.textoFuerte,
            ),
          ),
        ),
        if (valor != null) ...[
          Text(
            valor!,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: t.textoMuted,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Icon(Icons.chevron_right, size: 18, color: t.textoMuted),
      ],
    );
  }
}

/// Activar el candado de huella/rostro (Lote A · F7).
///
/// Solo se ofrece si el teléfono tiene biometría configurada: un interruptor
/// que no puede hacer nada es peor que no tenerlo.
class _InterruptorBiometria extends ConsumerStatefulWidget {
  const _InterruptorBiometria();

  @override
  ConsumerState<_InterruptorBiometria> createState() =>
      _InterruptorBiometriaState();
}

class _InterruptorBiometriaState extends ConsumerState<_InterruptorBiometria> {
  @override
  Widget build(BuildContext context) {
    final disponible =
        ref.watch(biometriaDisponibleProvider).valueOrNull ?? false;
    final servicio = ref.watch(biometriaServiceProvider);

    return _FilaInterruptor(
      titulo: 'Pedir huella al abrir',
      detalle:
          disponible
              ? 'Protege tus ventas si alguien agarra tu teléfono'
              : 'Tu teléfono no tiene huella ni rostro configurados',
      value: servicio.activa,
      onChanged:
          !disponible
              ? null
              : (v) async {
                // Al activarlo se pide una vez: si la huella no funciona, mejor
                // enterarse ahora que la próxima vez que abra la app.
                if (v && !await servicio.pedir()) return;
                await servicio.activar(v);
                if (mounted) setState(() {});
              },
    );
  }
}

class _HistorialTasa extends ConsumerWidget {
  const _HistorialTasa();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historial = ref.watch(historialTasaProvider);
    if (historial.length < 2) return const SizedBox.shrink();

    final t = context.libreta;
    final dias = historial.take(3).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ÚLTIMOS DÍAS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: t.textoMuted,
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < dias.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dias[i].etiqueta,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                        color: i == 0 ? t.textoFuerte : t.textoMuted,
                      ),
                    ),
                  ),
                  Text(
                    MoneyFormatter.bs(dias[i].valor),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: i == 0 ? t.textoFuerte : t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FilaTasa extends StatelessWidget {
  const _FilaTasa({
    required this.seleccionada,
    required this.titulo,
    required this.subtitulo,
    required this.calificador,
    required this.valor,
    required this.onTap,
    this.ultima = false,
  });

  final bool seleccionada;
  final String titulo;
  final String subtitulo;
  final String calificador;
  final double? valor;
  final VoidCallback onTap;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final v = valor;
    return _Fila(
      ultima: ultima,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: seleccionada ? LibretaColors.verde : Colors.transparent,
              shape: BoxShape.circle,
              border:
                  seleccionada
                      ? null
                      : Border.all(color: context.libreta.bordeSuave, width: 2),
            ),
            alignment: Alignment.center,
            child:
                seleccionada
                    ? const LibretaIcono(AppAssets.accConfirmar, size: 13, color: Colors.white)
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.libreta.textoFuerte,
                      ),
                    ),
                    Text(
                      ' · $calificador',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.libreta.textoMuted,
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.libreta.textoMuted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            v == null ? '—' : MoneyFormatter.bs(v),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.libreta.textoFuerte,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + deslizamiento hacia arriba al entrar, escalonado por [orden].
class _EntradaSuave extends StatefulWidget {
  const _EntradaSuave({required this.orden, required this.child});

  final int orden;
  final Widget child;

  @override
  State<_EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<_EntradaSuave> {
  bool _visible = false;
  Timer? _arranque;

  @override
  void initState() {
    super.initState();
    _arranque = Timer(Duration(milliseconds: 60 * widget.orden), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _arranque?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fila estándar "título + detalle + interruptor" de las secciones.
class _FilaInterruptor extends StatelessWidget {
  const _FilaInterruptor({
    required this.titulo,
    required this.detalle,
    required this.value,
    required this.onChanged,
  });

  final String titulo;
  final String detalle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.libreta.textoFuerte,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.libreta.textoMuted,
                ),
              ),
            ],
          ),
        ),
        LibretaToggle(value: value, onChanged: onChanged ?? (_) {}),
      ],
    );
  }
}

/// Barra fija al fondo con el botón "Guardar cambios".
class _BarraGuardar extends StatelessWidget {
  const _BarraGuardar({required this.guardando, required this.onGuardar});

  final bool guardando;
  final VoidCallback onGuardar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: context.libreta.superficie,
        border: Border(top: BorderSide(color: context.libreta.renglon)),
      ),
      child: LibretaButton(
        label: guardando ? 'Guardando…' : 'Guardar cambios',
        height: 48,
        loading: guardando,
        onPressed: guardando ? null : onGuardar,
      ),
    );
  }
}

/// Avatar circular con badge de cámara.
class _AvatarEditable extends StatefulWidget {
  const _AvatarEditable({
    required this.fotoUrl,
    required this.inicial,
    required this.subiendo,
    required this.editable,
    required this.onTap,
  });

  final String? fotoUrl;
  final String inicial;
  final bool subiendo;
  final bool editable;
  final VoidCallback onTap;

  @override
  State<_AvatarEditable> createState() => _AvatarEditableState();
}

class _AvatarEditableState extends State<_AvatarEditable> {
  bool _presionado = false;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty;
    final inicialBlanca = Text(
      widget.inicial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
    );

    return GestureDetector(
      onTap: widget.editable && !widget.subiendo ? widget.onTap : null,
      onTapDown: (_) => setState(() => _presionado = true),
      onTapUp: (_) => setState(() => _presionado = false),
      onTapCancel: () => setState(() => _presionado = false),
      child: AnimatedScale(
        scale: _presionado ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),
        child: Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: LibretaColors.verde,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child:
                  widget.subiendo
                      ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      )
                      : tieneFoto
                      ? FotoRed(
                        widget.fotoUrl!,
                        width: 88,
                        height: 88,
                        alError: inicialBlanca,
                      )
                      : inicialBlanca,
            ),
            if (widget.editable)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.libreta.papel, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: LibretaIcono(AppAssets.accCamara,
                    size: 14,
                    color: context.libreta.textoFuerte,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Categoría colapsable de Ajustes: se ve solo el título hasta que se toca.
///
/// Antes cada tema (Negocio, Tasa, Avisos, Apariencia…) era una tarjeta
/// siempre abierta, una tras otra — 9 seguidas en una sola lista larga.
/// Agruparlas en acordeones deja ver de entrada solo 6 títulos; cada quien
/// abre nada más el tema al que vino.
class _SeccionAcordeon extends StatefulWidget {
  const _SeccionAcordeon({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  State<_SeccionAcordeon> createState() => _SeccionAcordeonState();
}

class _SeccionAcordeonState extends State<_SeccionAcordeon> {
  bool _abierta = false;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(
          color:
              _abierta
                  ? const Color(0x590E9F6E)
                  : const Color(0x141E2A38),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _abierta = !_abierta),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              child: Row(
                children: [
                  Icon(widget.icono, size: 19, color: LibretaColors.verde),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: t.textoFuerte,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _abierta ? 1 : 0,
              child: Column(
                children: [
                  Divider(height: 1, color: t.renglon),
                  widget.child,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila con separador inferior opcional (réplica de `NeuListTile` en plano).
class _Fila extends StatelessWidget {
  const _Fila({required this.child, this.ultima = false, this.onTap});

  final Widget child;
  final bool ultima;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final contenido = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border:
            ultima
                ? null
                : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: child,
    );
    if (onTap == null) return contenido;
    return GestureDetector(onTap: onTap, child: contenido);
  }
}
