import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/bancos_venezuela.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/negocio_repository.dart';

/// Selector de banco principal del negocio. Lote E · P1 del diseño.
///
/// Muestra el listado completo de 26 bancos venezolanos con buscador.
/// Al seleccionar, guarda el código y nombre en el documento del negocio.
class SelectorBancoScreen extends ConsumerStatefulWidget {
  const SelectorBancoScreen({super.key});

  @override
  ConsumerState<SelectorBancoScreen> createState() =>
      _SelectorBancoScreenState();
}

class _SelectorBancoScreenState extends ConsumerState<SelectorBancoScreen> {
  final _buscador = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  List<BancoVenezuela> get _lista {
    if (_filtro.isEmpty) return BancoVenezuela.todos;
    return BancoVenezuela.todos
        .where(
          (b) =>
              b.nombre.toLowerCase().contains(_filtro.toLowerCase()) ||
              b.codigo.contains(_filtro),
        )
        .toList();
  }

  Future<void> _seleccionar(BancoVenezuela banco) async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (negocio == null) return;
    await ref.read(negocioRepositoryProvider).actualizarAjustes(
          negocio.id,
          bancoCodigo: banco.codigo,
          bancoNombre: banco.nombre,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final seleccionado = negocio?.bancoCodigo;

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
                    Expanded(
                      child: Text(
                        'Banco principal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.libreta.textoFuerte,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.libreta.renglon),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: TextField(
                  controller: _buscador,
                  onChanged: (v) => setState(() => _filtro = v),
                  style: TextStyle(
                    fontSize: 14,
                    color: context.libreta.textoFuerte,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar banco…',
                    hintStyle: TextStyle(color: context.libreta.textoMuted),
                    prefixIcon: Icon(
                      Icons.search,
                      color: context.libreta.textoMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: context.libreta.superficie,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: _lista.length,
                  itemBuilder: (_, i) {
                    final banco = _lista[i];
                    final esSeleccionado = banco.codigo == seleccionado;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: context.libreta.superficie,
                        border: Border.all(
                          color: esSeleccionado
                              ? LibretaColors.verde
                              : const Color(0x141E2A38),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        title: Text(
                          banco.nombre,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.libreta.textoFuerte,
                          ),
                        ),
                        subtitle: Text(
                          'Código ${banco.codigo}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.libreta.textoMuted,
                          ),
                        ),
                        trailing: esSeleccionado
                            ? const Icon(
                                Icons.check_circle,
                                color: LibretaColors.verde,
                                size: 22,
                              )
                            : null,
                        onTap: () => _seleccionar(banco),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
