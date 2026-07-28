import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../shared/presentation/foto_red.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';

/// Mi perfil (réplica visual de la fila "Perfil" del cajón `P2 · MÁS`,
/// `Lote N · Reportes y Más`).
///
/// Datos de la cuenta personal (nombre, contacto, rol) — distinto de
/// Ajustes, que edita el negocio.
class MiPerfilScreen extends ConsumerWidget {
  const MiPerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.libreta;
    final usuario = ref.watch(authStateProvider).valueOrNull;
    final membresia = ref.watch(membresiaActivaProvider);
    final esDueno = ref.watch(esDuenoProvider);

    final nombre = usuario?.displayName?.trim().isNotEmpty == true
        ? usuario!.displayName!
        : (membresia?.nombreVisible ?? 'Sin nombre');
    final contacto = usuario?.email ?? usuario?.phoneNumber ?? '—';
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();

    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(oscuro: true, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Text(
                    'Perfil',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: t.textoFuerte, letterSpacing: -0.4),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(color: LibretaColors.verde, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: usuario?.photoURL != null && usuario!.photoURL!.isNotEmpty
                      ? ClipOval(
                          child: FotoRed(
                            usuario.photoURL!,
                            width: 76,
                            height: 76,
                            alError: Text(inicial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        )
                      : Text(inicial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  nombre,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: t.textoFuerte),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0x1F0E9F6E), borderRadius: BorderRadius.circular(100)),
                  child: Text(
                    esDueno ? 'DUEÑO' : 'VENDEDOR',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: LibretaColors.verde),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                decoration: BoxDecoration(
                  color: t.superficie,
                  border: Border.all(color: t.bordeSuave),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _FilaDato(
                      icono: usuario?.email != null ? Icons.email_outlined : Icons.phone_outlined,
                      etiqueta: usuario?.email != null ? 'Correo' : 'Teléfono',
                      valor: contacto,
                      divisor: true,
                    ),
                    _FilaDato(
                      icono: Icons.storefront_outlined,
                      etiqueta: 'Negocio actual',
                      valor: membresia == null ? '—' : (esDueno ? 'Dueño' : 'Vendedor'),
                      divisor: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LibretaSecondaryButton(
                label: 'Eliminar cuenta',
                onPressed: () => context.push(Routes.eliminarCuenta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.divisor,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool divisor;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: divisor ? Border(bottom: BorderSide(color: t.renglon)) : null,
      ),
      child: Row(
        children: [
          Icon(icono, size: 19, color: t.textoMuted),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.textoMuted)),
                Text(valor, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.textoFuerte)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
