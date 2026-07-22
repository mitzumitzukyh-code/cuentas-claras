import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../services/cloudinary/cloudinary_service.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../notificaciones/presentation/avisos_tasa_seccion.dart';

/// Ajustes de la cuenta (bloque `isAjustes` del diseño).
///
/// Los ajustes están agrupados por tema, de lo más identitario a lo más
/// opcional: primero la foto, luego los datos del negocio, después recibos,
/// avisos y por último la apariencia. Cada sección entra con una pequeña
/// animación escalonada (fade + deslizamiento) para que la pantalla se sienta
/// ordenada en vez de un bloque que aparece de golpe.
///
/// Los campos de texto ya NO se guardan solos mientras escribes — antes lo
/// hacían con un pequeño retardo, pero eso hacía salir "Guardado" cada vez
/// que el dueño hacía una pausa al teclear (por ejemplo, anotando un
/// teléfono en varias tandas). Ahora solo se guardan al tocar "Guardar
/// cambios". Los interruptores y la foto de perfil, al ser una sola acción
/// deliberada, se siguen guardando al toque.
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

  /// Copia los valores del negocio a los campos la primera vez que llegan.
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
          content: Text('No se pudieron guardar los ajustes: $e'),
          backgroundColor: AppColors.peligro,
        ),
      );
    }
  }

  /// Interruptores: se guardan al toque, sin botón — es una sola acción
  /// deliberada, no una ráfaga de tecleo.
  Future<void> _guardarInterruptor(
    String negocioId, {
    bool? incluirIva,
    bool? alertaStock,
    bool? fotoComoFondo,
  }) async {
    try {
      await ref
          .read(negocioRepositoryProvider)
          .actualizarAjustes(
            negocioId,
            incluirIva: incluirIva,
            alertaStockActiva: alertaStock,
            fotoComoFondo: fotoComoFondo,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          backgroundColor: AppColors.peligro,
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
                  leading: const Text('📷', style: TextStyle(fontSize: 20)),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.of(c).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
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
          backgroundColor: AppColors.peligro,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final esDueno = ref.watch(esDuenoProvider);
    final modoOscuro = ref.watch(themeModeProvider) == ThemeMode.dark;

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _sembrar(negocio);

    final tieneFoto = negocio.fotoUrl != null && negocio.fotoUrl!.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
                      Expanded(
                        child: Text(
                          'Ajustes de la cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: t.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aquí puedes personalizar todo a tu manera 🙂',
                    style: TextStyle(fontSize: 13, color: t.textSec),
                  ),

                  if (!esDueno) ...[
                    const SizedBox(height: 16),
                    _EntradaSuave(
                      orden: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.avisoSuave,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Como empleado solo puedes cambiar tus preferencias '
                          'personales, no la configuración del negocio.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.aviso,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

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
                            style: TextStyle(fontSize: 12, color: t.textSec),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // --- 1. Negocio: identidad y datos de trabajo ---
                  _EntradaSuave(
                    orden: 2,
                    child: _Seccion(
                      titulo: '🏪 Negocio',
                      child: Column(
                        children: [
                          NeuListTile(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nombre del negocio',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: t.textSec,
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
                                    color: t.text,
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
                          NeuListTile(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Rubro',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.textSec,
                                  ),
                                ),
                                Text(
                                  negocio.rubro.etiqueta,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: t.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          NeuListTile(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🎯 Meta de ventas mensual (USD)',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.text,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                NeuInput(
                                  controller: _meta,
                                  hint: '0',
                                  height: 42,
                                  radius: 14,
                                  fillWithPageBg: true,
                                  enabled: esDueno,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => _marcarSucio(),
                                ),
                              ],
                            ),
                          ),
                          NeuListTile(
                            divider: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '🚚 WhatsApp del proveedor',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Para pedir reabastecimiento cuando el '
                                  'stock esté bajo',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: t.textSec,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                NeuInput(
                                  controller: _proveedor,
                                  hint: 'Ej: 584121234567',
                                  height: 42,
                                  radius: 14,
                                  fillWithPageBg: true,
                                  enabled: esDueno,
                                  keyboardType: TextInputType.phone,
                                  onChanged: (_) => _marcarSucio(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- 2. Recibos e impuestos ---
                  _EntradaSuave(
                    orden: 3,
                    child: _Seccion(
                      titulo: '🧾 Recibos e impuestos',
                      child: Column(
                        children: [
                          NeuListTile(
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
                          NeuListTile(
                            divider: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mensaje en el recibo 💬',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.text,
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
                                    color: t.textSec,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    hintText: 'Gracias por su compra',
                                    hintStyle: TextStyle(color: t.muted),
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

                  // --- 3. Avisos: stock bajo + tasa del dólar, juntos ---
                  _EntradaSuave(
                    orden: 4,
                    child: _Seccion(
                      titulo: '🔔 Avisos',
                      child: NeuListTile(
                        divider: false,
                        child: _FilaInterruptor(
                          titulo: 'Avísame si baja el stock',
                          detalle: 'Te avisamos antes de que se agote algo',
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
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _EntradaSuave(orden: 5, child: AvisosTasaSeccion()),
                  const SizedBox(height: 18),

                  // --- 4. Apariencia: cómo se ve la app ---
                  _EntradaSuave(
                    orden: 6,
                    child: _Seccion(
                      titulo: '🎨 Apariencia',
                      child: Column(
                        children: [
                          NeuListTile(
                            divider: tieneFoto,
                            child: _FilaInterruptor(
                              titulo: 'Modo oscuro 🌙',
                              detalle: 'Más cómodo para tus ojos de noche',
                              value: modoOscuro,
                              // Es preferencia del dispositivo, no del negocio:
                              // la puede cambiar cualquiera.
                              onChanged:
                                  (_) =>
                                      ref
                                          .read(themeModeProvider.notifier)
                                          .alternar(),
                            ),
                          ),
                          if (tieneFoto)
                            NeuListTile(
                              divider: false,
                              child: _FilaInterruptor(
                                titulo: 'Usar tu foto de fondo en el Inicio',
                                detalle:
                                    'Se muestra detrás del dashboard, con un '
                                    'velo para que el texto se siga leyendo',
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
                ],
              ),
            ),

            // Solo aparece cuando hay algo sin guardar: nada de avisos por
            // cada pausa al escribir, y el dueño siempre sabe si le falta
            // confirmar. Entra y sale con una animación de tamaño.
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
    );
  }
}

/// Fade + deslizamiento hacia arriba al entrar, escalonado por [orden].
///
/// Cada sección espera `orden × 60 ms` antes de aparecer, así la pantalla se
/// "construye" de arriba hacia abajo en vez de caer toda de golpe.
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
///
/// Con [onChanged] nulo el interruptor se ve pero no responde (empleados).
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
    final t = context.tokens;
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
                  color: t.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detalle,
                style: TextStyle(fontSize: 11.5, color: t.textSec),
              ),
            ],
          ),
        ),
        NeuToggle(value: value, onChanged: onChanged ?? (_) {}),
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
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.border2)),
      ),
      child: NeuButton(
        label: guardando ? 'Guardando…' : 'Guardar cambios',
        height: 48,
        loading: guardando,
        onPressed: guardando ? null : onGuardar,
      ),
    );
  }
}

/// Avatar circular con badge de cámara; mientras sube muestra un spinner y la
/// foto hace un pequeño "respiro" (escala) al tocarse.
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
    final t = context.tokens;
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
              decoration: BoxDecoration(
                color: AppColors.marca,
                shape: BoxShape.circle,
                boxShadow: t.shadowBtn,
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
                    color: t.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.pageBg, width: 2),
                    boxShadow: t.shadowRaisedSm,
                  ),
                  alignment: Alignment.center,
                  child: const Text('📷', style: TextStyle(fontSize: 13)),
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
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.textSec,
          ),
        ),
        const SizedBox(height: 8),
        NeuCard(clip: true, child: child),
      ],
    );
  }
}
