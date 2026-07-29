import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/bancos_venezuela.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/negocio_repository.dart';
import '../../ventas/domain/venta.dart';

/// Pago móvil (`Lote E · P7`).
///
/// Los tres datos que el cliente necesita para pagarte viven juntos: banco,
/// teléfono y cédula. El diseño no los reparte entre pantallas porque se
/// dictan de corrido cuando alguien va a hacer la transferencia.
///
/// El banco se elige de una lista y no se escribe: el código SUDEBAN se
/// completa solo, que es donde más se equivoca la gente.
class SelectorBancoScreen extends ConsumerStatefulWidget {
  const SelectorBancoScreen({super.key});

  @override
  ConsumerState<SelectorBancoScreen> createState() =>
      _SelectorBancoScreenState();
}

class _SelectorBancoScreenState extends ConsumerState<SelectorBancoScreen> {
  final _buscador = TextEditingController();
  final _telefono = TextEditingController();
  final _cedula = TextEditingController();

  String _filtro = '';
  bool _sembrado = false;
  bool _guardando = false;
  bool _sucio = false;

  @override
  void dispose() {
    _buscador.dispose();
    _telefono.dispose();
    _cedula.dispose();
    super.dispose();
  }

  List<BancoVenezuela> get _lista {
    final q = _filtro.trim().toLowerCase();
    if (q.isEmpty) return BancoVenezuela.todos;
    return BancoVenezuela.todos
        .where((b) =>
            b.nombre.toLowerCase().contains(q) || b.codigo.contains(q))
        .toList();
  }

  Future<void> _elegirBanco(BancoVenezuela banco) async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (negocio == null) return;
    await ref.read(negocioRepositoryProvider).actualizarAjustes(
          negocio.id,
          bancoCodigo: banco.codigo,
          bancoNombre: banco.nombre,
        );
  }

  /// Guarda teléfono y cédula dentro de `metodosPago.pagomovil.datos`, que es
  /// de donde Cobrar y el catálogo los leen.
  Future<void> _guardarDatos() async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (negocio == null) return;

    setState(() => _guardando = true);
    final metodos = [
      for (final c in negocio.metodosPago)
        if (c.metodo == MetodoPago.pagoMovil)
          c.copyWith(datos: {
            ...c.datos,
            'telefono': _telefono.text.trim(),
            'cedula': _cedula.text.trim(),
            if (negocio.bancoCodigo != null) 'codigoBanco': negocio.bancoCodigo!,
            if (negocio.bancoNombre != null) 'banco': negocio.bancoNombre!,
          })
        else
          c,
    ];
    try {
      await ref
          .read(negocioRepositoryProvider)
          .guardarMetodosPago(negocio.id, metodos);
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _sucio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos de pago móvil guardados.'),
          backgroundColor: AppColors.marca,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.peligro),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final seleccionado = negocio?.bancoCodigo;

    if (negocio != null && !_sembrado) {
      _sembrado = true;
      final movil = negocio.metodosPago
          .where((c) => c.metodo == MetodoPago.pagoMovil)
          .firstOrNull;
      _telefono.text = movil?.telefonoAsociado ?? '';
      _cedula.text = movil?.cedulaRif ?? '';
    }

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        spiral: false,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.renglon)),
                ),
                child: Row(
                  children: [
                    LibretaBackButton(
                      oscuro: true,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pago móvil',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: t.textoFuerte,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _Rotulo('Banco'),
                    LibretaInput(
                      controller: _buscador,
                      hint: 'Buscar banco…',
                      height: 44,
                      leading: Icon(Icons.search, size: 17, color: t.textoMuted),
                      onChanged: (v) => setState(() => _filtro = v),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: t.superficie,
                        border: Border.all(color: t.renglon),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _lista.length; i++)
                            _FilaBanco(
                              banco: _lista[i],
                              activo: _lista[i].codigo == seleccionado,
                              ultima: i == _lista.length - 1,
                              onTap: () => _elegirBanco(_lista[i]),
                            ),
                          if (_lista.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 22),
                              child: Text(
                                'Ningún banco coincide.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: t.textoMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Selecciona el banco de la lista — el código se completa '
                      'solo, sin que tengas que escribirlo.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: t.textoMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _Rotulo('Teléfono asociado'),
                    LibretaInput(
                      controller: _telefono,
                      hint: '0414-987 6543',
                      keyboardType: TextInputType.phone,
                      onChanged: (_) {
                        if (!_sucio) setState(() => _sucio = true);
                      },
                    ),
                    const SizedBox(height: 16),

                    _Rotulo('Cédula / RIF'),
                    LibretaInput(
                      controller: _cedula,
                      hint: 'V-12.345.678',
                      onChanged: (_) {
                        if (!_sucio) setState(() => _sucio = true);
                      },
                    ),
                    const SizedBox(height: 20),

                    LibretaButton(
                      label: 'Guardar datos',
                      loading: _guardando,
                      onPressed: _sucio ? _guardarDatos : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.libreta.textoMuted,
        ),
      ),
    );
  }
}

class _FilaBanco extends StatelessWidget {
  const _FilaBanco({
    required this.banco,
    required this.activo,
    required this.ultima,
    required this.onTap,
  });

  final BancoVenezuela banco;
  final bool activo;
  final bool ultima;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: activo ? const Color(0x0F0E9F6E) : Colors.transparent,
          border: ultima
              ? null
              : Border(bottom: BorderSide(color: t.renglon)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                banco.etiqueta,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                  color: t.textoFuerte,
                ),
              ),
            ),
            if (activo) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check, size: 16, color: LibretaColors.verde),
            ],
          ],
        ),
      ),
    );
  }
}
