import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/presentation/permiso_requerido.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/gasto_repository.dart';
import '../domain/gasto.dart';
import 'registrar_gasto_screen.dart';

/// Detalle de un gasto: lo que se gastó, cuándo, en qué, y el recibo.
///
/// Existía la carencia más grande de la pantalla de Gastos: se podía registrar
/// pero no abrir, ni corregir, ni borrar. Un gasto con la fecha mal —lo que
/// pasa cuando la IA lee la del proveedor— solo se arreglaba desde la consola
/// de Firebase, que un bodeguero no tiene.
class GastoDetalleScreen extends ConsumerWidget {
  const GastoDetalleScreen({super.key, required this.gastoInicial});

  /// El del `extra` de la ruta, congelado al navegar. Solo arranca la pantalla:
  /// se pinta el gasto vivo, porque se puede editar sin salir de aquí
  /// (`CLAUDE.md` §8.c).
  final Gasto gastoInicial;

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  String _fechaLarga(DateTime f) => '${f.day} de ${_meses[f.month - 1]} ${f.year}';

  Future<void> _editar(BuildContext context, Gasto gasto) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RegistrarGastoScreen(gasto: gasto)),
    );
  }

  Future<void> _eliminar(
    BuildContext context,
    WidgetRef ref,
    Gasto gasto,
  ) async {
    // El diálogo dice el monto y la descripción: confirmar "¿eliminar este
    // gasto?" a secas no le dice a nadie cuál está a punto de irse.
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Eliminar este gasto?'),
        content: Text(
          '${MoneyFormatter.usd(gasto.monto)}'
          '${gasto.descripcion.isEmpty ? '' : ' · ${gasto.descripcion}'}\n'
          '${gasto.categoriaLabel}, ${_fechaLarga(gasto.fecha)}.\n\n'
          'Deja de contar en tus reportes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: TextButton.styleFrom(foregroundColor: LibretaColors.peligro),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final membresia = ref.read(membresiaActivaProvider);
    if (membresia == null) return;
    try {
      final ok = await ref
          .read(gastoRepositoryProvider)
          .eliminar(membresia.negocioId, gasto.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Gasto eliminado.'
                : 'Eliminado sin señal. Se sincroniza al volver la conexión.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('[gasto] no se pudo eliminar: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar. Intenta de nuevo.')),
      );
    }
  }

  void _verRecibo(BuildContext context, String url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Recibo'),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: FotoRed(
                url,
                alError: const Text(
                  'No se pudo cargar el recibo.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gasto = ref.watch(gastoPorIdProvider(gastoInicial.id)) ?? gastoInicial;
    final t = context.libreta;
    final puedeEditar = ref.watch(puedeProvider(Permisos.registrarGastos));

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Detalle del gasto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: t.textoFuerte,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Monto ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: t.superficie,
                  border: Border.all(color: t.renglon),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Text(
                      '−${MoneyFormatter.usd(gasto.monto)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: t.textoFuerte,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // La tasa es la del día en que se registró, no la de hoy:
                    // si no, el monto en Bs de un gasto viejo cambiaría solo
                    // cada mañana y no serviría para auditar nada.
                    Text(
                      gasto.montoBs == null
                          ? 'sin tasa guardada · solo en dólares'
                          : '${MoneyFormatter.bs(gasto.montoBs!)} · a la tasa '
                              'de ese día',
                      style: TextStyle(fontSize: 12.5, color: t.textoMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _Fila(etiqueta: 'Categoría', valor: gasto.categoriaLabel),
              _Fila(etiqueta: 'Fecha', valor: _fechaLarga(gasto.fecha)),
              if (gasto.descripcion.isNotEmpty)
                _Fila(etiqueta: 'Descripción', valor: gasto.descripcion),

              // --- Recibo ---
              if (gasto.fotoReciboUrl != null) ...[
                const SizedBox(height: 18),
                Text(
                  'RECIBO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: t.textoMuted,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _verRecibo(context, gasto.fotoReciboUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: FotoRed(
                        gasto.fotoReciboUrl!,
                        alError: Container(
                          color: t.superficie,
                          alignment: Alignment.center,
                          child: Text(
                            'No se pudo cargar el recibo.',
                            style: TextStyle(color: t.textoMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              if (puedeEditar) ...[
                const SizedBox(height: 24),
                LibretaButton(
                  label: 'Editar',
                  icon: const LibretaIcono(
                    AppAssets.accEditar,
                    size: 18,
                    color: Colors.white,
                  ),
                  onPressed: () => _editar(context, gasto),
                ),
                const SizedBox(height: 10),
                LibretaSecondaryButton(
                  label: 'Eliminar gasto',
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: LibretaColors.peligro,
                  ),
                  onPressed: () => _eliminar(context, ref, gasto),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              etiqueta,
              style: TextStyle(fontSize: 13, color: t.textoMuted),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: t.textoFuerte,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
