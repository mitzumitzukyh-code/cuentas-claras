import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../planes/data/plan_repository.dart';
import '../../planes/domain/plan.dart';
import '../../auth/data/auth_repository.dart';
import '../data/negocio_repository.dart';
import '../domain/invitacion.dart';
import '../domain/membresia.dart';

/// Empleados (réplica visual de `P0 · EMPLEADOS`, `Lote E · Negocio y
/// Perfil`).
///
/// Lista los miembros del negocio, permite cambiarles el rol, quitarlos y
/// generar un código de invitación de 24 h para sumar a alguien.
class EmpleadosScreen extends ConsumerStatefulWidget {
  const EmpleadosScreen({super.key});

  @override
  ConsumerState<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends ConsumerState<EmpleadosScreen> {
  bool _generando = false;

  Future<void> _invitar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (membresia == null || negocio == null) return;

    // El tope de personas es del plan del dueño del negocio, y se cuenta
    // incluyéndolo a él. En gratis eso deja sitio para uno solo, así que no
    // hay invitación que generar.
    final limite = LimitePlan.cabeUnoMas(
      actuales: ref.read(miembrosNegocioProvider).valueOrNull?.length ?? 1,
      tope: ref.read(planDelNegocioProvider).maxUsuarios,
      mensaje: 'El plan gratis es para una sola persona. Pásate a Plan Plus '
          'para sumar a tu equipo.',
    );
    if (!limite.permitido) {
      _mostrar(limite.mensaje!);
      return;
    }

    setState(() => _generando = true);
    try {
      final invitacion = await ref.read(negocioRepositoryProvider).crearInvitacion(
            negocioId: negocio.id,
            negocioNombre: negocio.nombre,
            rol: RolMembresia.empleado,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DialogoCodigo(
          invitacion: invitacion,
          negocioNombre: negocio.nombre,
        ),
      );
    } catch (e) {
      if (mounted) _mostrar(mensajeDeError(e, accion: 'crear la invitación'));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _cambiarRol(Membresia m) async {
    final nuevo =
        m.rol.esDueno ? RolMembresia.empleado : RolMembresia.dueno;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Cambiar a ${nuevo.etiqueta.toLowerCase()}?'),
        content: Text(
          nuevo.esDueno
              ? '${m.nombreVisible} podrá ver los reportes, anular ventas y '
                  'eliminar productos.'
              : '${m.nombreVisible} solo podrá cobrar y ver el inventario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await ref.read(negocioRepositoryProvider).cambiarRol(m.id, nuevo);
    } catch (e) {
      _mostrar(mensajeDeError(e, accion: 'cambiar el rol'));
    }
  }

  Future<void> _quitar(Membresia m) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('¿Quitar a ${m.nombreVisible}?'),
        content: const Text(
          'Perderá el acceso al negocio. Las ventas que registró se conservan '
          'en el historial.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: TextButton.styleFrom(foregroundColor: LibretaColors.peligro),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await ref.read(negocioRepositoryProvider).quitarMiembro(m.id);
    } catch (e) {
      _mostrar(mensajeDeError(e, accion: 'quitar a esta persona'));
    }
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final miembros = ref.watch(miembrosNegocioProvider);
    final yo = ref.watch(authStateProvider).valueOrNull?.uid;
    final esDueno = ref.watch(esDuenoProvider);

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
                      'Empleados',
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    miembros.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudo cargar el equipo.\n$e',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.libreta.textoMuted),
                        ),
                      ),
                      data: (lista) {
                        if (lista.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                LibretaIcono(AppAssets.navClientes,
                                  size: 30,
                                  color: context.libreta.textoMuted,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Todavía trabajas solo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.libreta.textoMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Invita a alguien con el botón de abajo',
                                  style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EQUIPO · ${lista.length} '
                              '${lista.length == 1 ? "persona" : "personas"}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: context.libreta.superficie,
                                border: Border.all(color: context.libreta.renglon),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < lista.length; i++)
                                      _FilaMiembro(
                                        miembro: lista[i],
                                        esYo: lista[i].usuarioId == yo,
                                        ultima: i == lista.length - 1,
                                        onTap: esDueno
                                            ? () => context.push(
                                                  Routes.detalleEmpleado,
                                                  extra: lista[i],
                                                )
                                            : null,
                                        onRol: () => _cambiarRol(lista[i]),
                                        onQuitar: () => _quitar(lista[i]),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'INVITACIÓN PENDIENTE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: context.libreta.textoMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Genera un código y compártelo con quien quieras sumar '
                      'al equipo. Vence en 24 horas.',
                      style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: LibretaButton(
                  label: 'Invitar empleado',
                  loading: _generando,
                  onPressed: _generando ? null : _invitar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de un miembro del equipo.
class _FilaMiembro extends StatelessWidget {
  const _FilaMiembro({
    required this.miembro,
    required this.esYo,
    required this.ultima,
    this.onTap,
    required this.onRol,
    required this.onQuitar,
  });

  final Membresia miembro;

  /// El dueño no puede degradarse ni expulsarse a sí mismo: se quedaría el
  /// negocio sin nadie que lo administre.
  final bool esYo;
  final bool ultima;

  final VoidCallback? onTap;
  final VoidCallback onRol;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final esDueno = miembro.rol.esDueno;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: ultima
              ? null
              : Border(bottom: BorderSide(color: context.libreta.renglon)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: esDueno
                    ? LibretaColors.tarjetaOscura
                    : t.textoFuerte.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                miembro.iniciales,
                style: TextStyle(
                  color: esDueno ? Colors.white : t.textoFuerte,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esYo ? '${miembro.nombreVisible} (tú)' : miembro.nombreVisible,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    esDueno
                        ? (miembro.correo ?? 'tú')
                        : miembro.rol.etiqueta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (esDueno)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: LibretaColors.verde.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'DUEÑO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: LibretaColors.verde,
                ),
              ),
            ),
            if (!esYo) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onQuitar,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: LibretaIcono(AppAssets.accCerrar, size: 18, color: context.libreta.textoMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Muestra el código recién generado y permite compartirlo.
class _DialogoCodigo extends StatelessWidget {
  const _DialogoCodigo({
    required this.invitacion,
    required this.negocioNombre,
  });

  final Invitacion invitacion;
  final String negocioNombre;

  @override
  Widget build(BuildContext context) {
    final mensaje =
        '¡Te invito a manejar "$negocioNombre" conmigo en Cuenta Clara!\n\n'
        'Tu código es: ${invitacion.codigo}\n\n'
        'Instala la app, crea tu cuenta y escribe el código cuando te lo pida. '
        'Vence en 24 horas.';

    return AlertDialog(
      title: const Text('Código de invitación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: LibretaColors.verde.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              invitacion.codigo,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: LibretaColors.verde,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vence en 24 horas y solo sirve una vez.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
        TextButton(
          onPressed: () {
            Share.share(mensaje, subject: 'Invitación a $negocioNombre');
          },
          child: const Text('Compartir'),
        ),
      ],
    );
  }
}
