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
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;

    final nombre =
        usuario?.displayName?.trim().isNotEmpty == true
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
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Perfil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: LibretaColors.tarjetaOscura,
                    shape: BoxShape.circle,
                  ),
                  child:
                      usuario?.photoURL != null &&
                              usuario!.photoURL!.isNotEmpty
                          ? FotoRed(
                            usuario.photoURL!,
                            width: 88,
                            height: 88,
                            alError: Text(inicial, style: _estiloInicial),
                          )
                          : Text(inicial, style: _estiloInicial),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: t.textoFuerte,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1F0E9F6E),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    (membresia?.rol.etiqueta ?? '').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: LibretaColors.verde,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: t.superficie,
                  border: Border.all(color: t.renglon),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _FilaDato(
                      etiqueta: 'Negocio',
                      valor: negocio?.nombre ?? '—',
                      divisor: true,
                    ),
                    _FilaDato(
                      etiqueta: usuario?.email != null ? 'Correo' : 'Teléfono',
                      valor: contacto,
                      divisor: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LibretaButton(
                label: 'Editar perfil',
                onPressed: () => context.push(Routes.ajustes),
              ),
              const SizedBox(height: 12),
              // Eliminar cuenta vive solo aquí: es una acción de cuenta, no un
              // documento legal. Estaba también en Ajustes › Legal, donde no
              // pinta nada.
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
    required this.etiqueta,
    required this.valor,
    required this.divisor,
  });

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: t.textoMuted,
                  ),
                ),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: t.textoFuerte,
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

const _estiloInicial = TextStyle(
  fontSize: 30,
  fontWeight: FontWeight.w800,
  color: Colors.white,
);
