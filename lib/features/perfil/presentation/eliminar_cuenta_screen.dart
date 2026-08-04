import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../../shared/utils/errores.dart';

/// Eliminar cuenta (réplica visual de `P5 · ELIMINAR CUENTA`, `Lote E ·
/// Negocio y Perfil`).
///
/// Requisito de Google Play: toda app con cuentas debe ofrecer una vía DENTRO
/// de la app para pedir el borrado de la cuenta y sus datos.
///
/// Tres caminos según quién eres:
/// - Empleado: sales del negocio y se borra tu cuenta de acceso.
/// - Dueño con empleados activos: bloqueado — hay que quitarlos primero.
/// - Dueño sin empleados: se borra el negocio completo y tu cuenta. Las
///   VENTAS no se borran — CLAUDE.md §6 y las reglas de Firestore lo prohíben
///   a propósito (auditoría/fiscal).
class EliminarCuentaScreen extends ConsumerStatefulWidget {
  const EliminarCuentaScreen({super.key});

  @override
  ConsumerState<EliminarCuentaScreen> createState() =>
      _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends ConsumerState<EliminarCuentaScreen> {
  final _contrasena = TextEditingController();
  bool _confirmado = false;
  bool _eliminando = false;

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _eliminar({
    required bool esDueno,
    required bool negocioSolo,
    required String negocioId,
    required String membresiaId,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    final negocioRepo = ref.read(negocioRepositoryProvider);
    final contrasena = _contrasena.text;

    setState(() => _eliminando = true);
    try {
      if (esDueno && negocioSolo) {
        await negocioRepo.eliminarNegocioCompleto(negocioId, membresiaId);
      } else if (!esDueno) {
        await negocioRepo.quitarMiembro(membresiaId);
      }
      await auth.eliminarCuenta(
        contrasenaActual: contrasena.isEmpty ? null : contrasena,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensajeError(e)),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  String _mensajeError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'falta-contrasena':
          return 'Escribe tu contraseña para confirmar.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'La contraseña no es correcta.';
        case 'reautenticacion-cancelada':
          return 'Cancelaste la confirmación.';
        default:
          return 'No se pudo confirmar: ${e.message ?? e.code}';
      }
    }
    return mensajeDeError(e, accion: 'eliminar la cuenta');
  }

  @override
  Widget build(BuildContext context) {
    final membresia = ref.watch(membresiaActivaProvider);
    final esDueno = ref.watch(esDuenoProvider);
    final esGoogle = ref.read(authRepositoryProvider).sesionEsGoogle;

    if (membresia == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final miembros =
        esDueno
            ? ref.watch(miembrosNegocioProvider).valueOrNull
            : const <Object>[];
    final cargandoMiembros = esDueno && miembros == null;
    final bloqueado = esDueno && (miembros?.length ?? 0) > 1;
    final negocioSolo = esDueno && (miembros?.length ?? 0) <= 1;

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Eliminar cuenta',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (cargandoMiembros)
                const Center(child: CircularProgressIndicator())
              else if (bloqueado)
                _AvisoBloqueado(
                  onIrAEmpleados: () => context.push(Routes.empleados),
                )
              else ...[
                Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: LibretaColors.ambarSuperficie.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const LibretaIcono(AppAssets.accAlerta,
                        size: 32,
                        color: LibretaColors.aviso,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '¿Seguro que quieres eliminar tu cuenta?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.libreta.textoFuerte,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Esta acción es permanente y no se puede deshacer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: context.libreta.textoMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: context.libreta.renglon),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SE BORRARÁ PARA SIEMPRE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: context.libreta.textoFuerte,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FilaBorrado(texto: 'Todas tus ventas y gastos'),
                      _FilaBorrado(texto: 'Tu inventario y catálogo'),
                      _FilaBorrado(texto: 'Los accesos de tus empleados'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (!esGoogle) ...[
                  Text(
                    'Escribe tu contraseña para confirmar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LibretaInput(
                    controller: _contrasena,
                    hint: 'Contraseña',
                    obscure: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                ],

                InkWell(
                  onTap: () => setState(() => _confirmado = !_confirmado),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _confirmado,
                          onChanged: (v) => setState(() => _confirmado = v ?? false),
                          activeColor: LibretaColors.peligro,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Entiendo que esta acción no se puede deshacer',
                              style: TextStyle(fontSize: 13, color: context.libreta.textoFuerte),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_confirmado &&
                            !_eliminando &&
                            (esGoogle || _contrasena.text.isNotEmpty))
                        ? () => _eliminar(
                              esDueno: esDueno,
                              negocioSolo: negocioSolo,
                              negocioId: membresia.negocioId,
                              membresiaId: membresia.id,
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LibretaColors.peligro,
                      disabledBackgroundColor: LibretaColors.peligro.withValues(alpha: .5),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _eliminando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Eliminar mi cuenta',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaBorrado extends StatelessWidget {
  const _FilaBorrado({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const LibretaIcono(AppAssets.accCerrar, size: 15, color: LibretaColors.aviso),
          const SizedBox(width: 10),
          Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.libreta.textoFuerte,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoBloqueado extends StatelessWidget {
  const _AvisoBloqueado({required this.onIrAEmpleados});

  final VoidCallback onIrAEmpleados;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LibretaColors.ambarSuperficie.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Todavía tienes empleados en el negocio',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: LibretaColors.aviso,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No se puede borrar un negocio con gente todavía adentro. '
                'Quítalos primero desde Empleados y vuelve aquí.',
                style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LibretaSecondaryButton(
          label: 'Ir a Empleados',
          height: 48,
          onPressed: onIrAEmpleados,
        ),
      ],
    );
  }
}
