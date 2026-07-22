import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/presentation/neu.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/presentation/empleados_screen.dart';

/// Eliminar cuenta (requisito de Google Play: toda app con cuentas debe
/// ofrecer una vía DENTRO de la app para pedir el borrado de la cuenta y sus
/// datos — https://cuenta-clara-tasa.mitzumitzukyhs.workers.dev/legal/eliminar-cuenta
/// es la vía equivalente fuera de la app).
///
/// Tres caminos según quién eres:
/// - Empleado: sales del negocio y se borra tu cuenta de acceso.
/// - Dueño con empleados activos: bloqueado — hay que quitarlos primero, no
///   se puede borrar un negocio con gente todavía adentro.
/// - Dueño sin empleados: se borra el negocio completo (productos, insumos,
///   gastos) y tu cuenta. Las VENTAS no se borran — CLAUDE.md §6 y las
///   reglas de Firestore lo prohíben a propósito (auditoría/fiscal); ya no
///   tienen nada personal, solo un uid, así que no queda dato personal atrás.
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
      // A partir de aquí el widget puede desmontarse en cualquier momento
      // (el router reacciona solo al cambio de sesión/membresías) — `auth` y
      // `negocioRepo` ya están capturados, así que seguir sin `ref` es
      // seguro.
      await auth.eliminarCuenta(
        contrasenaActual: contrasena.isEmpty ? null : contrasena,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mensajeError(e)),
          backgroundColor: AppColors.peligro,
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
    return 'No se pudo eliminar la cuenta: $e';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
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
                Text(
                  'Eliminar cuenta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (cargandoMiembros)
              const Center(child: CircularProgressIndicator())
            else if (bloqueado)
              _AvisoBloqueado(
                onIrAEmpleados:
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EmpleadosScreen(),
                      ),
                    ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.peligroSuave,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esDueno
                          ? 'Esto va a borrar tu negocio completo'
                          : 'Esto va a borrar tu cuenta',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.peligro,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      esDueno
                          ? 'Se borran tus productos, gastos y tu cuenta de '
                              'acceso. No se puede deshacer.'
                          : 'Sales del negocio y se borra tu cuenta de '
                              'acceso. No se puede deshacer.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.peligro,
                      ),
                    ),
                    if (esDueno) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Las ventas que ya registraste NO se borran — la ley '
                        'exige conservarlas para fines fiscales. Ya no '
                        'tienen tu nombre ni tu correo, así que no queda '
                        'nada personal ahí.',
                        style: TextStyle(fontSize: 12, color: t.textSec),
                      ),
                    ],
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
                    color: t.textSec,
                  ),
                ),
                const SizedBox(height: 8),
                NeuInput(
                  controller: _contrasena,
                  hint: 'Contraseña',
                  height: 48,
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
                        onChanged:
                            (v) => setState(() => _confirmado = v ?? false),
                        activeColor: AppColors.peligro,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Entiendo que esta acción no se puede deshacer',
                            style: TextStyle(fontSize: 13, color: t.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              NeuButton(
                label: _eliminando ? 'Eliminando…' : 'Eliminar mi cuenta',
                height: 50,
                color: AppColors.peligro,
                loading: _eliminando,
                onPressed:
                    (_confirmado &&
                            !_eliminando &&
                            (esGoogle || _contrasena.text.isNotEmpty))
                        ? () => _eliminar(
                          esDueno: esDueno,
                          negocioSolo: negocioSolo,
                          negocioId: membresia.negocioId,
                          membresiaId: membresia.id,
                        )
                        : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvisoBloqueado extends StatelessWidget {
  const _AvisoBloqueado({required this.onIrAEmpleados});

  final VoidCallback onIrAEmpleados;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.avisoSuave,
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
                  color: AppColors.aviso,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No se puede borrar un negocio con gente todavía adentro. '
                'Quítalos primero desde Empleados y vuelve aquí.',
                style: TextStyle(fontSize: 13, color: t.textSec),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NeuSecondaryButton(
          label: 'Ir a Empleados',
          height: 48,
          onPressed: onIrAEmpleados,
        ),
      ],
    );
  }
}
