import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../productos/data/producto_repository.dart';
import '../../ventas/data/venta_repository.dart';

/// Un empujón dentro de la app: qué proponer, con qué icono y a dónde lleva.
typedef _Sugerencia = ({
  String clave,
  String icono,
  String titulo,
  String detalle,
  String accion,
  String ruta,
});

/// Tarjeta que sugiere la siguiente función que al dueño le conviene usar.
///
/// No es publicidad ni un carrusel de novedades: mira el estado real del
/// negocio y propone lo único que falta para que la app le sirva de verdad
/// (sin productos no se puede cobrar; sin cobrar no hay reportes; con
/// mercancía cargada, lo que trae plata es mandar el catálogo). Se descarta
/// con la X y no vuelve a salir esa sugerencia.
class SugerenciaUso extends ConsumerStatefulWidget {
  const SugerenciaUso({super.key});

  @override
  ConsumerState<SugerenciaUso> createState() => _SugerenciaUsoState();
}

class _SugerenciaUsoState extends ConsumerState<SugerenciaUso> {
  static const _prefijoDescartada = 'sugerencia_descartada_';

  Future<void> _descartar(String clave) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('$_prefijoDescartada$clave', true);
    if (mounted) setState(() {});
  }

  bool _descartada(String clave) =>
      ref.read(sharedPreferencesProvider).getBool('$_prefijoDescartada$clave') ??
      false;

  /// La primera sugerencia que aplique y no esté descartada. El orden importa:
  /// es la secuencia en que la app se vuelve útil.
  _Sugerencia? _elegir(int productos, int ventasHoy) {
    final candidatas = <_Sugerencia>[
      if (productos == 0)
        (
          clave: 'primer_producto',
          icono: AppAssets.accAgregar,
          titulo: 'Carga tu mercancía',
          detalle: 'Con tus productos adentro, cobrar es tocar y listo.',
          accion: 'Agregar producto',
          ruta: Routes.nuevoProducto,
        ),
      if (productos > 0 && ventasHoy == 0)
        (
          clave: 'primera_venta',
          icono: AppAssets.accEfectivo,
          titulo: 'Anota tu primera venta del día',
          detalle: 'La app descuenta el inventario y saca la cuenta en Bs.',
          accion: 'Cobrar',
          ruta: Routes.cobrar,
        ),
      if (productos > 0)
        (
          clave: 'compartir_catalogo',
          icono: AppAssets.accMensaje,
          titulo: 'Manda tus precios por WhatsApp',
          detalle: 'Tus clientes ven qué tienes y a cómo, sin preguntarte.',
          accion: 'Ver catálogo',
          ruta: Routes.catalogo,
        ),
      if (productos > 0)
        (
          clave: 'fiados',
          icono: AppAssets.navClientes,
          titulo: '¿Fías?',
          detalle: 'Lleva quién te debe y cuánto, sin pelear con nadie.',
          accion: 'Ver fiados',
          ruta: Routes.fiados,
        ),
    ];

    for (final c in candidatas) {
      if (!_descartada(c.clave)) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final productos = ref.watch(productosProvider).valueOrNull ?? const [];
    final ventasHoy = ref.watch(ventasDelDiaProvider).valueOrNull ?? const [];

    final sugerencia = _elegir(productos.length, ventasHoy.length);
    // Descartadas todas, no queda nada que proponer: se vuelve al "todo en
    // orden" de siempre, sin flecha porque no lleva a ninguna parte.
    if (sugerencia == null) return const _TodoAlDia();

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0x140E9F6E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x330E9F6E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x290E9F6E),
              borderRadius: BorderRadius.circular(11),
            ),
            child: LibretaIcono(sugerencia.icono,
                size: 18, color: LibretaColors.verde),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sugerencia.titulo,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sugerencia.detalle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: LibretaColors.textoMuted,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push(sugerencia.ruta),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sugerencia.accion,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: LibretaColors.verde,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward,
                          size: 14, color: LibretaColors.verde),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _descartar(sugerencia.clave),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: LibretaIcono(AppAssets.accCerrar,
                  size: 16, color: LibretaColors.textoMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que se muestra cuando no hay pendientes ni queda ninguna sugerencia sin
/// descartar: el negocio está al día y no hay nada que empujar.
class _TodoAlDia extends StatelessWidget {
  const _TodoAlDia();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x171E2A38)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x121E2A38),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const LibretaIcono(AppAssets.accConfirmar,
                size: 18, color: LibretaColors.verde),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Todo al día',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.textoFuerte,
                  ),
                ),
                Text(
                  'sin novedades',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.textoMuted,
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
