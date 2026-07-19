import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';
import '../../ventas/domain/venta.dart';
import '../data/negocio_repository.dart';
import '../domain/metodo_pago_config.dart';

/// Métodos de pago (bloque `isMetodosPago` del diseño).
///
/// Cada método se activa con un interruptor y, al activarlo, despliega los
/// datos que hay que darle al cliente (teléfono de Pago Móvil, correo de
/// Zelle…). Se guardan con retardo para no escribir en cada tecla.
class MetodosPagoScreen extends ConsumerStatefulWidget {
  const MetodosPagoScreen({super.key});

  @override
  ConsumerState<MetodosPagoScreen> createState() => _MetodosPagoScreenState();
}

class _MetodosPagoScreenState extends ConsumerState<MetodosPagoScreen> {
  /// Copia editable local; se sincroniza con Firestore al guardar.
  List<MetodoPagoConfig> _metodos = [];
  bool _inicializado = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _sembrar(List<MetodoPagoConfig> desdeNegocio) {
    if (_inicializado) return;
    _inicializado = true;
    _metodos = List<MetodoPagoConfig>.from(desdeNegocio);
  }

  void _guardarConRetardo(String negocioId) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _guardar(negocioId);
    });
  }

  Future<void> _guardar(String negocioId) async {
    try {
      await ref
          .read(negocioRepositoryProvider)
          .guardarMetodosPago(negocioId, _metodos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar: $e'),
          backgroundColor: AppColors.peligro,
        ),
      );
    }
  }

  void _alternar(String negocioId, MetodoPago metodo, bool activo) {
    setState(() {
      _metodos = [
        for (final m in _metodos)
          m.metodo == metodo ? m.copyWith(activo: activo) : m,
      ];
    });
    _guardar(negocioId);
  }

  void _editarCampo(
    String negocioId,
    MetodoPago metodo,
    String clave,
    String valor,
  ) {
    setState(() {
      _metodos = [
        for (final m in _metodos)
          if (m.metodo == metodo)
            m.copyWith(datos: {...m.datos, clave: valor})
          else
            m,
      ];
    });
    _guardarConRetardo(negocioId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final esDueno = ref.watch(esDuenoProvider);

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _sembrar(negocio.metodosPago);

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
                  'Métodos de pago',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Activa los que aceptas al cobrar',
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
                  'Solo el dueño puede cambiar los métodos de pago.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.aviso,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 18),
            for (final config in _metodos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TarjetaMetodo(
                  config: config,
                  editable: esDueno,
                  onAlternar: (v) => _alternar(negocio.id, config.metodo, v),
                  onCampo: (clave, valor) =>
                      _editarCampo(negocio.id, config.metodo, clave, valor),
                ),
              ),

            const SizedBox(height: 12),
            Text(
              'Los datos que escribas aquí son los que verá tu cliente al '
              'pagar y los que se incluirán en el recibo.',
              style: TextStyle(fontSize: 12, color: t.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un método: interruptor y, si está activo, sus campos.
class _TarjetaMetodo extends StatefulWidget {
  const _TarjetaMetodo({
    required this.config,
    required this.editable,
    required this.onAlternar,
    required this.onCampo,
  });

  final MetodoPagoConfig config;
  final bool editable;
  final ValueChanged<bool> onAlternar;
  final void Function(String clave, String valor) onCampo;

  @override
  State<_TarjetaMetodo> createState() => _TarjetaMetodoState();
}

class _TarjetaMetodoState extends State<_TarjetaMetodo> {
  final Map<String, TextEditingController> _controles = {};

  @override
  void initState() {
    super.initState();
    for (final campo in MetodoPagoConfig.camposDe(widget.config.metodo)) {
      _controles[campo.clave] = TextEditingController(
        text: widget.config.datos[campo.clave] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final campos = MetodoPagoConfig.camposDe(widget.config.metodo);

    return NeuCard(
      small: true,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.config.metodo.etiqueta,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              NeuToggle(
                value: widget.config.activo,
                onChanged: widget.editable ? widget.onAlternar : (_) {},
              ),
            ],
          ),

          // Los campos solo aparecen si el método está activo — el efectivo
          // no pide ninguno.
          if (widget.config.activo && campos.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final campo in campos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campo.etiqueta,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: t.textSec,
                      ),
                    ),
                    const SizedBox(height: 4),
                    NeuInput(
                      controller: _controles[campo.clave],
                      hint: campo.ejemplo,
                      height: 42,
                      radius: 14,
                      fillWithPageBg: true,
                      enabled: widget.editable,
                      onChanged: (v) => widget.onCampo(campo.clave, v),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
