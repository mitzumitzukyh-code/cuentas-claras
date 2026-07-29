import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../../../app/router/routes.dart';
import '../../ventas/domain/venta.dart';
import '../data/negocio_repository.dart';
import '../domain/metodo_pago_config.dart';

/// Métodos de pago (réplica visual de `P1 · MÉTODOS DE PAGO`, `Lote E ·
/// Negocio y Perfil`).
///
/// Cada método se activa con un interruptor y, al activarlo, despliega los
/// datos que hay que darle al cliente (teléfono de Pago Móvil, correo de
/// Zelle…). Los interruptores guardan al toque; los campos de texto NO se
/// guardan solos mientras escribes — se guardan todos juntos al tocar
/// "Guardar cambios".
class MetodosPagoScreen extends ConsumerStatefulWidget {
  const MetodosPagoScreen({super.key});

  @override
  ConsumerState<MetodosPagoScreen> createState() => _MetodosPagoScreenState();
}

class _MetodosPagoScreenState extends ConsumerState<MetodosPagoScreen> {
  /// Copia editable local; se sincroniza con Firestore al guardar.
  List<MetodoPagoConfig> _metodos = [];
  bool _inicializado = false;
  bool _sucio = false;
  bool _guardando = false;

  void _sembrar(List<MetodoPagoConfig> desdeNegocio) {
    if (_inicializado) return;
    _inicializado = true;
    _metodos = List<MetodoPagoConfig>.from(desdeNegocio);
  }

  Future<void> _guardar(String negocioId, {bool avisar = false}) async {
    if (avisar) setState(() => _guardando = true);
    try {
      await ref
          .read(negocioRepositoryProvider)
          .guardarMetodosPago(negocioId, _metodos);
      if (!mounted) return;
      if (avisar) {
        setState(() {
          _sucio = false;
          _guardando = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cambios guardados ✓')));
      }
    } catch (e) {
      if (!mounted) return;
      if (avisar) setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar: $e'),
          backgroundColor: LibretaColors.peligro,
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

  void _editarCampo(MetodoPago metodo, String clave, String valor) {
    setState(() {
      _sucio = true;
      _metodos = [
        for (final m in _metodos)
          if (m.metodo == metodo)
            m.copyWith(datos: {...m.datos, clave: valor})
          else
            m,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final esDueno = ref.watch(esDuenoProvider);

    if (negocio == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _sembrar(negocio.metodosPago);

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
                      'Métodos de pago',
                      style: TextStyle(
                        fontSize: 20,
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      'Elige qué formas de pago aparecen al cobrar.',
                      style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                    ),

                    if (!esDueno) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0x21F2A93C),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Solo el dueño puede cambiar los métodos de pago.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: LibretaColors.aviso,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    for (final config in _metodos)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TarjetaMetodo(
                          config: config,
                          editable: esDueno,
                          onAlternar:
                              (v) => _alternar(negocio.id, config.metodo, v),
                          onCampo:
                              (clave, valor) =>
                                  _editarCampo(config.metodo, clave, valor),
                        ),
                      ),

                    const SizedBox(height: 8),
                    Text(
                      'Los datos que escribas aquí son los que verá tu cliente al '
                      'pagar y los que se incluirán en el recibo.',
                      style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                    ),
                  ],
                ),
              ),

              if (_sucio && esDueno)
                _BarraGuardar(
                  guardando: _guardando,
                  onGuardar: () => _guardar(negocio.id, avisar: true),
                ),
            ],
          ),
        ),
      ),
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

/// Quita el emoji de `MetodoPago.etiqueta` — el ícono ya se dibuja aparte.
String _sinEmoji(String etiqueta) =>
    etiqueta.replaceFirst(RegExp(r'^\S+\s'), '');

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

  IconData get _icono => switch (widget.config.metodo) {
        MetodoPago.efectivo => Icons.payments_outlined,
        MetodoPago.pagoMovil => Icons.smartphone,
        MetodoPago.transferencia => Icons.account_balance_outlined,
        MetodoPago.zelle => Icons.attach_money,
        MetodoPago.biopago => Icons.fingerprint,
        MetodoPago.puntoDeVenta => Icons.point_of_sale,
      };

  /// El pago móvil tiene pantalla propia (`Lote E · P7`): banco, teléfono y
  /// cédula se dictan de corrido, así que el diseño los junta ahí en vez de
  /// dejarlos sueltos dentro de esta tarjeta.
  bool get _tieneDetalle => widget.config.metodo == MetodoPago.pagoMovil;

  /// Lo que el diseño muestra bajo el nombre del método.
  String? get _subtitulo {
    final d = widget.config.datos;
    switch (widget.config.metodo) {
      case MetodoPago.efectivo:
        return 'Bs y USD';
      case MetodoPago.puntoDeVenta:
        return 'Débito y crédito';
      case MetodoPago.pagoMovil:
        final banco = d['banco'];
        final cedula = d['cedula'];
        if (banco == null || banco.isEmpty) return 'Toca para configurarlo';
        final codigo = d['codigoBanco'];
        final izq = codigo == null || codigo.isEmpty
            ? banco
            : '$banco ($codigo)';
        return cedula == null || cedula.isEmpty ? izq : '$izq · $cedula';
      default:
        final resumen = d.values.where((v) => v.trim().isNotEmpty).join(' · ');
        return resumen.isEmpty ? null : resumen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final campos = MetodoPagoConfig.camposDe(widget.config.metodo);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.libreta.superficie,
        border: Border.all(color: const Color(0x141E2A38)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x1F0E9F6E),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(_icono, size: 18, color: LibretaColors.verde),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _tieneDetalle
                      ? () => context.push(Routes.selectorBanco)
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sinEmoji(widget.config.metodo.etiqueta),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.libreta.textoFuerte,
                        ),
                      ),
                      if (_subtitulo != null)
                        Text(
                          _subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.libreta.textoMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_tieneDetalle)
                GestureDetector(
                  onTap: () => context.push(Routes.selectorBanco),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ),
              LibretaToggle(
                value: widget.config.activo,
                onChanged: widget.editable ? widget.onAlternar : (_) {},
              ),
            ],
          ),

          if (widget.config.activo && campos.isNotEmpty && !_tieneDetalle) ...[
            const SizedBox(height: 12),
            for (final campo in campos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LibretaInput(
                  controller: _controles[campo.clave],
                  label: campo.etiqueta,
                  hint: campo.ejemplo,
                  height: 42,
                  enabled: widget.editable,
                  onChanged: (v) => widget.onCampo(campo.clave, v),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
