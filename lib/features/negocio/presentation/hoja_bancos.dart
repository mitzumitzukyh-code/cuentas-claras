import 'package:flutter/material.dart';

import '../../../core/constants/bancos_venezuela.dart';
import '../../../shared/presentation/libreta/libreta.dart';

/// Abre la lista de bancos en una hoja inferior y devuelve el elegido.
///
/// La lista no se pinta en la pantalla: 25 bancos empujarían fuera de vista
/// los campos que vienen después, y el banco se elige una vez en la vida.
/// Sirve igual para pago móvil y para transferencia.
Future<BancoVenezuela?> elegirBanco(
  BuildContext context, {
  String? codigoActual,
}) {
  return showModalBottomSheet<BancoVenezuela>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.libreta.papel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaBancos(seleccionado: codigoActual),
  );
}

/// Campo que muestra el banco elegido y abre la lista al tocarlo.
///
/// Se ve como un campo de texto para que encaje entre los demás datos del
/// método de pago, pero no se escribe: escribir el código SUDEBAN a mano es
/// justo donde la gente se equivoca.
class CampoBanco extends StatelessWidget {
  const CampoBanco({
    super.key,
    required this.valor,
    required this.onElegir,
    this.etiqueta = 'Banco',
    this.habilitado = true,
  });

  /// Nombre del banco ya guardado, o vacío.
  final String valor;
  final String etiqueta;
  final bool habilitado;
  final ValueChanged<BancoVenezuela> onElegir;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final vacio = valor.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.textoMuted,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: !habilitado
              ? null
              : () async {
                  final elegido = await elegirBanco(context);
                  if (elegido != null) onElegir(elegido);
                },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: t.superficie,
              border: Border.all(color: t.bordeSuave, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vacio ? 'Toca para elegirlo' : valor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: vacio ? FontWeight.w500 : FontWeight.w700,
                      color: vacio ? t.textoMuted : t.textoFuerte,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 19,
                  color: t.textoMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HojaBancos extends StatefulWidget {
  const _HojaBancos({required this.seleccionado});

  final String? seleccionado;

  @override
  State<_HojaBancos> createState() => _HojaBancosState();
}

class _HojaBancosState extends State<_HojaBancos> {
  final _buscador = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  List<BancoVenezuela> get _lista {
    final q = _filtro.trim().toLowerCase();
    if (q.isEmpty) return BancoVenezuela.todos;
    return BancoVenezuela.todos
        .where((b) => b.nombre.toLowerCase().contains(q) || b.codigo.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final lista = _lista;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.bordeSuave,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Elige tu banco',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: t.textoFuerte,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: t.textoMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LibretaInput(
                    controller: _buscador,
                    hint: 'Buscar banco…',
                    height: 44,
                    leading: Icon(Icons.search, size: 17, color: t.textoMuted),
                    onChanged: (v) => setState(() => _filtro = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? Center(
                      child: Text(
                        'Ningún banco coincide.',
                        style: TextStyle(fontSize: 13.5, color: t.textoMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: lista.length,
                      itemBuilder: (_, i) => _FilaBanco(
                        banco: lista[i],
                        activo: lista[i].codigo == widget.seleccionado,
                        onTap: () => Navigator.of(context).pop(lista[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaBanco extends StatelessWidget {
  const _FilaBanco({
    required this.banco,
    required this.activo,
    required this.onTap,
  });

  final BancoVenezuela banco;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: activo ? const Color(0x140E9F6E) : t.superficie,
          border: Border.all(
            color: activo ? LibretaColors.verde : t.renglon,
            width: activo ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                banco.etiqueta,
                style: TextStyle(
                  fontSize: 14,
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
