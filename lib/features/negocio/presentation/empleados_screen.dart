import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';
import '../../auth/data/auth_repository.dart';
import '../data/negocio_repository.dart';
import '../domain/invitacion.dart';
import '../domain/membresia.dart';

/// Empleados (bloque `isEmpleados` del diseño).
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
      if (mounted) _mostrar('No se pudo crear la invitación: $e');
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
      _mostrar('No se pudo cambiar el rol: $e');
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
            style: TextButton.styleFrom(foregroundColor: AppColors.peligro),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    try {
      await ref.read(negocioRepositoryProvider).quitarMiembro(m.id);
    } catch (e) {
      _mostrar('No se pudo quitar: $e');
    }
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final miembros = ref.watch(miembrosNegocioProvider);
    final yo = ref.watch(authStateProvider).valueOrNull?.uid;

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
                Expanded(
                  child: Text(
                    'Empleados',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: t.text,
                    ),
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.marca,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: t.shadowBtn,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _generando ? null : _invitar,
                      child: _generando
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

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
                  style: TextStyle(color: t.textSec),
                ),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Text('👥', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 10),
                        Text(
                          'Todavía trabajas solo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: t.textSec,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toca + para invitar a alguien',
                          style: TextStyle(fontSize: 13, color: t.textSec),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final m in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FilaMiembro(
                          miembro: m,
                          esYo: m.usuarioId == yo,
                          onRol: () => _cambiarRol(m),
                          onQuitar: () => _quitar(m),
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),
            Text(
              'Dueño: acceso total. Vendedor: solo puede cobrar y ver '
              'productos, sin reportes ni anulaciones.',
              style: TextStyle(fontSize: 12, color: t.textSec),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de un miembro del equipo.
class _FilaMiembro extends StatelessWidget {
  const _FilaMiembro({
    required this.miembro,
    required this.esYo,
    required this.onRol,
    required this.onQuitar,
  });

  final Membresia miembro;

  /// El dueño no puede degradarse ni expulsarse a sí mismo: se quedaría el
  /// negocio sin nadie que lo administre.
  final bool esYo;

  final VoidCallback onRol;
  final VoidCallback onQuitar;

  static const _colores = [
    Color(0xFF0F6B5C),
    Color(0xFF3D6CA8),
    Color(0xFFC9852B),
    Color(0xFF8A5FB0),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color =
        _colores[miembro.usuarioId.hashCode.abs() % _colores.length];

    return NeuCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              miembro.iniciales,
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
              children: [
                Text(
                  esYo ? '${miembro.nombreVisible} (tú)' : miembro.nombreVisible,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  miembro.correo ?? miembro.rol.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: t.textSec),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: esYo ? null : onRol,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: miembro.rol.esDueno ? t.tint : t.chip,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                miembro.rol.etiqueta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: miembro.rol.esDueno ? AppColors.marca : t.textSec,
                ),
              ),
            ),
          ),
          if (!esYo) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onQuitar,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18, color: t.muted),
              ),
            ),
          ],
        ],
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
    final t = context.tokens;
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
              color: t.tint,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              invitacion.codigo,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: AppColors.marca,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Vence en 24 horas y solo sirve una vez.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: t.textSec),
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
