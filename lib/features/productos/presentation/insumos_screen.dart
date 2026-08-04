import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/numero_ve.dart';
import '../../../shared/presentation/estado_carga.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/insumo_repository.dart';
import '../domain/insumo.dart';

/// Insumos del negocio: la materia prima que consumen las recetas
/// (`Lote C · P3` — la tarjeta "Receta / insumos" los elige de aquí).
///
/// Es una pantalla de inventario aparte y no un tipo de producto: la harina
/// no se vende, se gasta. Mezclarlos haría que apareciera en el catálogo y
/// en Cobrar.
class InsumosScreen extends ConsumerWidget {
  const InsumosScreen({super.key});

  Future<void> _editar(
    BuildContext context,
    WidgetRef ref, {
    Insumo? insumo,
  }) async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;

    final resultado = await showModalBottomSheet<Insumo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaInsumo(insumo: insumo),
    );
    if (resultado == null || !context.mounted) return;

    // Con `try`: sin él, un rechazo de Firestore o una caída de red se iban al
    // vacío con la hoja ya cerrada, y el dueño se quedaba creyendo que su
    // insumo estaba guardado.
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(insumoRepositoryProvider);
      if (insumo == null) {
        await repo.crear(membresia.negocioId, resultado);
      } else {
        await repo.actualizar(membresia.negocioId, resultado);
      }
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'guardar el insumo')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Insumo insumo,
  ) async {
    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;

    final seguro = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar ${insumo.nombre}?'),
        content: const Text(
          'Los productos que lo tengan en su receta dejarán de descontarlo. '
          'Las ventas ya registradas no cambian.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: LibretaColors.peligro)),
          ),
        ],
      ),
    );
    if (seguro != true || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(insumoRepositoryProvider)
          .eliminar(membresia.negocioId, insumo.id);
    } catch (e) {
      mensajero.showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'eliminar el insumo')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    // Cargando, error y vacío son tres estados distintos. Con
    // `valueOrNull ?? const []` un fallo de permisos o de red pintaba
    // "Todavía no cargas insumos" con su botón de agregar: el dueño tiene sus
    // insumos y la pantalla le dice que no, invitándolo a cargarlos otra vez.
    final insumosAsync = ref.watch(insumosProvider);
    final insumos = insumosAsync.valueOrNull ?? const <Insumo>[];
    final bajos = insumos.where((i) => i.stockBajo).length;

    return Scaffold(
      backgroundColor: t.papel,
      floatingActionButton: FloatingActionButton(
        backgroundColor: LibretaColors.verde,
        shape: const CircleBorder(),
        onPressed: () => _editar(context, ref),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 100),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insumos',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: t.textoFuerte,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          // Mientras carga o si falló, el subtítulo no cuenta
                          // insumos: contaría cero, que es justo lo que no se
                          // sabe.
                          !insumosAsync.hasValue
                              ? 'lo que gastan tus recetas'
                              : insumos.isEmpty
                                  ? 'lo que gastan tus recetas'
                                  : bajos > 0
                                      ? '${insumos.length} insumos · $bajos por acabarse'
                                      : '${insumos.length} insumos',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: bajos > 0 ? LibretaColors.aviso : t.textoMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ...insumosAsync.when(
                loading: () => const [LibretaCargando()],
                error: (e, _) => [
                  LibretaErrorCarga(
                    mensaje: mensajeDeError(e, accion: 'cargar tus insumos'),
                    detalleTecnico: e,
                    onReintentar: () => ref.invalidate(insumosProvider),
                  ),
                ],
                data: (lista) => lista.isEmpty
                    ? [
                        LibretaEstadoVacio(
                          ilustracion: Ilustracion.sinProductos,
                          titulo: 'Todavía no cargas insumos',
                          detalle:
                              'Carga la harina, los huevos, el aceite… Después '
                              'los pones en la receta de cada producto y se '
                              'descuentan solos al vender.',
                          tagline: 'lo que se gasta también se cuenta',
                          boton: LibretaButton(
                            label: 'Agregar insumo',
                            onPressed: () => _editar(context, ref),
                          ),
                        ),
                      ]
                    : [
                        for (final i in lista)
                          _FilaInsumo(
                            insumo: i,
                            onEditar: () => _editar(context, ref, insumo: i),
                            onEliminar: () => _eliminar(context, ref, i),
                          ),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaInsumo extends StatelessWidget {
  const _FilaInsumo({
    required this.insumo,
    required this.onEditar,
    required this.onEliminar,
  });

  final Insumo insumo;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return InkWell(
      onTap: onEditar,
      onLongPress: onEliminar,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.renglon)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    insumo.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.textoFuerte,
                    ),
                  ),
                  Text(
                    insumo.unidad.etiqueta.toLowerCase(),
                    style: TextStyle(fontSize: 12, color: t.textoMuted),
                  ),
                ],
              ),
            ),
            if (insumo.stockBajo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: LibretaColors.ambarSuperficie.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'quedan ${insumo.cantidadLabel}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.aviso,
                  ),
                ),
              )
            else
              Text(
                'quedan ${insumo.cantidadLabel}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: t.textoMuted,
                ),
              ),
            // Eliminar era solo pulsación larga sobre la fila: nada en
            // pantalla decía que se pudiera hacer, así que en la práctica no
            // se podía quitar un insumo. La pulsación larga sigue funcionando
            // para quien ya la conocía.
            Semantics(
              button: true,
              label: 'Eliminar ${insumo.nombre}',
              child: GestureDetector(
                onTap: onEliminar,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 48,
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 19,
                    color: t.textoMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta y edición de un insumo.
class _HojaInsumo extends StatefulWidget {
  const _HojaInsumo({this.insumo});

  final Insumo? insumo;

  @override
  State<_HojaInsumo> createState() => _HojaInsumoState();
}

class _HojaInsumoState extends State<_HojaInsumo> {
  late final _nombre = TextEditingController(text: widget.insumo?.nombre ?? '');
  late final _cantidad = TextEditingController(
    text: widget.insumo == null ? '' : Insumo.numero(widget.insumo!.cantidad),
  );
  late final _alerta = TextEditingController(
    text: widget.insumo?.alertaEn == null
        ? ''
        : Insumo.numero(widget.insumo!.alertaEn!),
  );
  late UnidadInsumo _unidad = widget.insumo?.unidad ?? UnidadInsumo.gramo;

  @override
  void dispose() {
    _nombre.dispose();
    _cantidad.dispose();
    _alerta.dispose();
    super.dispose();
  }

  /// `true` cuando hay nombre y una cantidad legible.
  bool get _valido =>
      _nombre.text.trim().isNotEmpty && normalizarNumeroVE(_cantidad.text) != null;

  void _guardar() {
    final cantidad = normalizarNumeroVE(_cantidad.text);
    if (!_valido || cantidad == null) return;
    Navigator.of(context).pop(
      Insumo(
        id: widget.insumo?.id ?? '',
        nombre: _nombre.text.trim(),
        cantidad: cantidad,
        unidad: _unidad,
        // Por `normalizarNumeroVE` y no por `replaceAll(',', '.')`: con el
        // apaño viejo, "1.500" gramos de harina se leían como 1,5 —el punto se
        // tomaba por decimal— y el insumo quedaba con mil veces menos, sin que
        // nada fallara ni avisara.
        alertaEn: normalizarNumeroVE(_alerta.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: t.bordeSuave,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.insumo == null ? 'Nuevo insumo' : 'Editar insumo',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: t.textoFuerte,
              ),
            ),
            const SizedBox(height: 16),
            LibretaInput(
              controller: _nombre,
              hint: 'Nombre (harina, huevos…)',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: LibretaInput(
                    controller: _cantidad,
                    hint: 'Cantidad',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<UnidadInsumo>(
                    value: _unidad,
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      filled: true,
                      fillColor: t.superficie,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: t.bordeSuave),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: t.bordeSuave),
                      ),
                    ),
                    items: [
                      for (final u in UnidadInsumo.values)
                        DropdownMenuItem(
                          value: u,
                          child: Text(u.etiqueta,
                              style: const TextStyle(fontSize: 14)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _unidad = v ?? _unidad),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LibretaInput(
              controller: _alerta,
              hint: 'Avisarme cuando baje de… (opcional)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 18),
            // Deshabilitado mientras falte algo, en vez de aceptar el toque y
            // no hacer nada: `_guardar` volvía en silencio si el nombre estaba
            // vacío o la cantidad no se podía leer, y el botón parecía roto.
            LibretaButton(
              label: 'Guardar',
              onPressed: _valido ? _guardar : null,
            ),
          ],
        ),
      ),
    );
  }
}
