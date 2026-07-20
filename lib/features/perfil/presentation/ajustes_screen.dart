import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../../shared/presentation/neu.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/negocio.dart';
import '../../notificaciones/presentation/avisos_tasa_seccion.dart';

/// Ajustes de la cuenta (bloque `isAjustes` del diseño).
///
/// Los cambios se guardan en Firestore con un pequeño retardo (debounce) para
/// no escribir en cada pulsación de tecla.
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

  Timer? _debounce;
  bool _inicializado = false;

  @override
  void dispose() {
    _debounce?.cancel();
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
    _meta.text = n.metaMensualUsd == 0
        ? ''
        : n.metaMensualUsd.toStringAsFixed(0);
    _proveedor.text = n.proveedorWhatsapp ?? '';
  }

  void _guardarConRetardo(String negocioId) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _guardar(negocioId);
    });
  }

  Future<void> _guardar(
    String negocioId, {
    bool? incluirIva,
    bool? alertaStock,
  }) async {
    try {
      await ref.read(negocioRepositoryProvider).actualizarAjustes(
            negocioId,
            nombre: _nombre.text.trim().isEmpty ? null : _nombre.text.trim(),
            reciboMensaje: _reciboMensaje.text.trim(),
            metaMensualUsd: double.tryParse(_meta.text.replaceAll(',', '.')) ?? 0,
            proveedorWhatsapp: _proveedor.text.trim(),
            incluirIva: incluirIva,
            alertaStockActiva: alertaStock,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar los ajustes: $e'),
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
              Container(
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
            ],

            const SizedBox(height: 18),

            // --- Negocio ---
            _Seccion(
              titulo: '🏪 Negocio',
              child: Column(
                children: [
                  NeuListTile(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre del negocio',
                          style: TextStyle(fontSize: 12, color: t.textSec),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nombre,
                          enabled: esDueno,
                          onChanged: (_) => _guardarConRetardo(negocio.id),
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
                    divider: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rubro',
                          style: TextStyle(fontSize: 13, color: t.textSec),
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
                ],
              ),
            ),
            const SizedBox(height: 18),

            // --- Recibos e impuestos ---
            _Seccion(
              titulo: '🧾 Recibos e impuestos',
              child: Column(
                children: [
                  NeuListTile(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Incluir IVA en recibos',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sumamos el 16% automáticamente al total',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        NeuToggle(
                          value: negocio.incluirIva,
                          onChanged: esDueno
                              ? (v) => _guardar(negocio.id, incluirIva: v)
                              : (_) {},
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
                          onChanged: (_) => _guardarConRetardo(negocio.id),
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
            const SizedBox(height: 18),

            // --- Preferencias ---
            _Seccion(
              titulo: '⚡ Preferencias',
              child: Column(
                children: [
                  NeuListTile(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Avísame si baja el stock',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Te avisamos antes de que se agote algo',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        NeuToggle(
                          value: negocio.alertaStockActiva,
                          onChanged: esDueno
                              ? (v) => _guardar(negocio.id, alertaStock: v)
                              : (_) {},
                        ),
                      ],
                    ),
                  ),
                  NeuListTile(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo oscuro 🌙',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: t.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Más cómodo para tus ojos de noche',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: t.textSec,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Es preferencia del dispositivo, no del negocio: la
                        // puede cambiar cualquiera.
                        NeuToggle(
                          value: modoOscuro,
                          onChanged: (_) =>
                              ref.read(themeModeProvider.notifier).alternar(),
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
                          onChanged: (_) => _guardarConRetardo(negocio.id),
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
                          'Para pedir reabastecimiento cuando el stock esté bajo',
                          style: TextStyle(fontSize: 11.5, color: t.textSec),
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
                          onChanged: (_) => _guardarConRetardo(negocio.id),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const AvisosTasaSeccion(),

            const SizedBox(height: 18),
            Text(
              'La foto del negocio, la impresora de tickets, el lector externo '
              'y el PIN de seguridad llegan cuando se active Cloud Storage y el '
              'soporte de hardware.',
              style: TextStyle(fontSize: 12, color: t.muted),
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
