import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
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
  final _telefonoContacto = TextEditingController();

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
    _telefonoContacto.dispose();
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
    _telefonoContacto.text = n.telefonoContacto ?? '';
  }

  void _marcarSucio() {
    if (!_sucio) setState(() => _sucio = true);
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
            telefonoContacto: _telefonoContacto.text.trim(),
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
          content: Text('No se pudieron guardar los ajustes: $e'),
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
          content: Text('No se pudo guardar: $e'),
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
                  leading: const Icon(Icons.photo_camera_outlined),
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
          content: Text('No se pudo subir la foto: $e'),
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.libreta.textoFuerte,
                        letterSpacing: -0.4,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                              inicial: negocio.nombre.isEmpty
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
                              style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- 1. Negocio ---
                    _EntradaSuave(
                      orden: 2,
                      child: _Seccion(
                        titulo: 'Negocio',
                        child: Column(
                          children: [
                            _Fila(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nombre del negocio',
                                    style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Rubro',
                                    style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                                  ),
                                  Text(
                                    negocio.rubro.etiqueta,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: context.libreta.textoFuerte,
                                    ),
                                  ),
                                ],
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
                              ultima: true,
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
                                    style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
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
                                  Text(
                                    'Mi teléfono de contacto',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.libreta.textoFuerte,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'El que ven tus clientes en el catálogo y '
                                    'en el Estado',
                                    style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
                                  ),
                                  const SizedBox(height: 8),
                                  LibretaInput(
                                    controller: _telefonoContacto,
                                    hint: 'Ej: 0414 123 4567',
                                    height: 42,
                                    enabled: esDueno,
                                    keyboardType: TextInputType.phone,
                                    onChanged: (_) => _marcarSucio(),
                                  ),
                                  const SizedBox(height: 4),
                                  _FilaInterruptor(
                                    titulo: 'Hago delivery',
                                    detalle: 'Se anuncia en el Estado y el catálogo',
                                    value: negocio.haceDelivery,
                                    onChanged: esDueno
                                        ? (v) => _guardarInterruptor(negocio.id, haceDelivery: v)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- 2. Tasa de cambio · usar al cobrar ---
                    _EntradaSuave(
                      orden: 3,
                      child: _Seccion(
                        titulo: 'Tasa de cambio · usar al cobrar',
                        child: const _SelectorTasaAjustes(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        'La tasa elegida se usa para convertir el total a '
                        'bolívares al momento de cobrar.',
                        style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const _HistorialTasa(),
                    const SizedBox(height: 18),

                    _EntradaSuave(
                      orden: 4,
                      child: _Seccion(
                        titulo: 'Seguridad',
                        child: _Fila(
                          ultima: true,
                          child: const _InterruptorBiometria(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- 3. Recibos e impuestos ---
                    _EntradaSuave(
                      orden: 4,
                      child: _Seccion(
                        titulo: 'Recibos e impuestos',
                        child: Column(
                          children: [
                            _Fila(
                              child: _FilaInterruptor(
                                titulo: 'Incluir IVA en recibos',
                                detalle: 'Sumamos el 16% automáticamente al total',
                                value: negocio.incluirIva,
                                onChanged: esDueno
                                    ? (v) => _guardarInterruptor(negocio.id, incluirIva: v)
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
                                      hintStyle: TextStyle(color: context.libreta.textoMuted),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- 4. Avisos ---
                    _EntradaSuave(
                      orden: 5,
                      child: _Seccion(
                        titulo: 'Avisos',
                        child: Column(
                          children: [
                            _Fila(
                              child: _FilaInterruptor(
                                titulo: 'Avísame si baja el stock',
                                detalle: 'Te avisamos antes de que se agote algo',
                                value: negocio.alertaStockActiva,
                                onChanged: esDueno
                                    ? (v) => _guardarInterruptor(negocio.id, alertaStock: v)
                                    : null,
                              ),
                            ),
                            _Fila(
                              ultima: true,
                              onTap: () => context.push(Routes.notificaciones),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Ver mis notificaciones',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.libreta.textoFuerte,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 19,
                                    color: context.libreta.textoMuted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _EntradaSuave(orden: 6, child: AvisosTasaSeccion()),
                    const SizedBox(height: 18),

                    // --- 5. Apariencia ---
                    _EntradaSuave(
                      orden: 7,
                      child: _Seccion(
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
                                value: ref.watch(themeModeProvider) ==
                                    ThemeMode.dark,
                                onChanged: (v) =>
                                    ref.read(themeModeProvider.notifier).alternar(),
                              ),
                            ),
                            if (tieneFoto)
                              _Fila(
                                ultima: true,
                                child: _FilaInterruptor(
                                  titulo:
                                      'Usar tu foto de fondo en el Inicio',
                                  detalle:
                                      'Se muestra detrás del dashboard, con '
                                      'un velo para que el texto se siga '
                                      'leyendo',
                                  value: negocio.fotoComoFondo,
                                  onChanged: esDueno
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
                    const SizedBox(height: 18),

                    // --- 6. Banco principal (solo dueño) ---
                    if (esDueno) ...[
                      _EntradaSuave(
                        orden: 8,
                        child: _Seccion(
                          titulo: 'Banco principal',
                          child: _Fila(
                            ultima: true,
                            onTap: () => context.push(Routes.selectorBanco),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        negocio.bancoNombre ??
                                            'Seleccionar banco',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: context.libreta.textoFuerte,
                                        ),
                                      ),
                                      if (negocio.bancoNombre != null)
                                        Text(
                                          'Código ${negocio.bancoCodigo}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: context.libreta.textoMuted,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 19,
                                  color: context.libreta.textoMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // --- 7. Legal ---
                    _EntradaSuave(
                      orden: 9,
                      child: _Seccion(
                        titulo: 'Legal',
                        child: Column(
                          children: [
                            _Fila(
                              onTap: () => context.push(Routes.legal),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Privacidad y términos',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: context.libreta.textoFuerte,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 19,
                                    color: context.libreta.textoMuted,
                                  ),
                                ],
                              ),
                            ),
                            _Fila(
                              ultima: true,
                              onTap: () => context.push(Routes.eliminarCuenta),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Eliminar cuenta',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: LibretaColors.peligro,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 19,
                                    color: context.libreta.textoMuted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // --- 8. Ayuda ---
                    _EntradaSuave(
                      orden: 10,
                      child: _Seccion(
                        titulo: 'Ayuda',
                        child: _Fila(
                          ultima: true,
                          onTap: () => context.push(Routes.ayuda),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Centro de ayuda',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.libreta.textoFuerte,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 19,
                                color: context.libreta.textoMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: (_sucio && esDueno)
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
          onTap: () => ref.read(tasaActivaProvider.notifier).elegir(TipoTasa.bcv),
        ),
        _FilaTasa(
          seleccionada: tipo == TipoTasa.binance,
          titulo: 'Paralelo',
          subtitulo: 'mercado P2P',
          calificador: 'paralelo',
          valor: binance,
          ultima: true,
          onTap: () => ref.read(tasaActivaProvider.notifier).elegir(TipoTasa.binance),
        ),
      ],
    );
  }
}

/// Últimos días de la tasa activa (Lote E · F5.4).
///
/// Solo aparece si hay al menos dos días guardados: un solo renglón repitiendo
/// lo que ya dice el selector de arriba no informa nada.
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
      detalle: disponible
          ? 'Protege tus ventas si alguien agarra tu teléfono'
          : 'Tu teléfono no tiene huella ni rostro configurados',
      value: servicio.activa,
      onChanged: !disponible
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
              border: seleccionada
                  ? null
                  : Border.all(color: context.libreta.bordeSuave, width: 2),
            ),
            alignment: Alignment.center,
            child: seleccionada
                ? const Icon(Icons.check, size: 13, color: Colors.white)
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
                  style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
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
                style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
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
              child: widget.subiendo
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
                  child: Icon(
                    Icons.photo_camera_outlined,
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

/// Título de sección + tarjeta agrupadora.
class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: context.libreta.textoMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.libreta.superficie,
            border: Border.all(color: const Color(0x141E2A38)),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
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
        border: ultima
            ? null
            : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: child,
    );
    if (onTap == null) return contenido;
    return GestureDetector(onTap: onTap, child: contenido);
  }
}
