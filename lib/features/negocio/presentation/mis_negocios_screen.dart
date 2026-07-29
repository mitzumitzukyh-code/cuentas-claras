import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/negocio_repository.dart';
import '../domain/membresia.dart';

/// Mis negocios (`Lote N · P4`).
///
/// Separa los negocios propios de aquellos donde a uno lo invitaron: no es lo
/// mismo tener una sucursal que trabajar en el negocio de otro, y la lista
/// mezclada obligaba a leer el rol de cada renglón para entender qué se está
/// viendo.
class MisNegociosScreen extends ConsumerWidget {
  const MisNegociosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final membresias = ref.watch(misMembresiasProvider).valueOrNull ?? const [];
    final activa = ref.watch(membresiaActivaProvider);

    final propios =
        membresias.where((m) => m.rol == RolMembresia.dueno).toList();
    final invitado =
        membresias.where((m) => m.rol != RolMembresia.dueno).toList();

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
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
                          'Mis negocios',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: t.textoFuerte,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          membresias.length == 1
                              ? '1 negocio'
                              : '${membresias.length} negocios',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: t.textoMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (propios.isNotEmpty) ...[
                _Rotulo(texto: propios.length == 1 ? 'MI NEGOCIO' : 'MIS SUCURSALES'),
                for (final m in propios)
                  _FilaNegocio(
                    membresia: m,
                    activo: m.negocioId == activa?.negocioId,
                  ),
                const SizedBox(height: 18),
              ],

              if (invitado.isNotEmpty) ...[
                const _Rotulo(texto: 'DONDE TE INVITARON'),
                for (final m in invitado)
                  _FilaNegocio(
                    membresia: m,
                    activo: m.negocioId == activa?.negocioId,
                  ),
                const SizedBox(height: 18),
              ],

              GestureDetector(
                onTap: () => context.push(Routes.onboarding),
                child: DottedBorderBox(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18, color: t.textoMuted),
                        const SizedBox(width: 8),
                        Text(
                          'Agregar otra sucursal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.textoFuerte,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Cada sucursal lleva su propio inventario, sus ventas y su '
                'caja. Los empleados se invitan por separado.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: t.textoMuted,
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
  const _Rotulo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.libreta.textoMuted,
        ),
      ),
    );
  }
}

class _FilaNegocio extends ConsumerWidget {
  const _FilaNegocio({required this.membresia, required this.activo});

  final Membresia membresia;
  final bool activo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final negocio =
        ref.watch(negocioPorIdProvider(membresia.negocioId)).valueOrNull;
    final nombre = negocio?.nombre ?? 'Negocio';

    return GestureDetector(
      onTap: activo
          ? null
          : () {
              ref
                  .read(negocioSeleccionadoProvider.notifier)
                  .state = membresia.negocioId;
              // Al Dashboard: quedarse en una pantalla que puede no existir
              // en el otro negocio (o para la que no se tenga permiso) sería
              // aterrizar en un error.
              context.go(Routes.dashboard);
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(
            color: activo ? const Color(0x4D0E9F6E) : t.renglon,
            width: activo ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: LibretaColors.tarjetaOscura,
                shape: BoxShape.circle,
              ),
              child: Text(
                nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textoFuerte,
                    ),
                  ),
                  Text(
                    membresia.rol.etiqueta,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (activo)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1F0E9F6E),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Activo',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.verde,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}
