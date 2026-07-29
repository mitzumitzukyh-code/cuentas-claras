import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/negocio/data/negocio_repository.dart';
import 'libreta/libreta.dart';

// Las claves y el provider viajan juntos: quien pregunta por un permiso
// necesita ambos, y separarlos obliga a importar el repositorio de negocio
// en pantallas que no tienen otro motivo para conocerlo.
export '../../features/negocio/data/negocio_repository.dart'
    show puedeProvider, esDuenoProvider;

/// Nombres de los permisos, para no repetir literales por toda la app.
abstract final class Permisos {
  const Permisos._();

  static const String cobrar = 'cobrar';
  static const String verReportes = 'verReportes';
  static const String editarInventario = 'editarInventario';
  static const String registrarGastos = 'registrarGastos';
  static const String cerrarCaja = 'cerrarCaja';
  static const String gestionarEmpleados = 'gestionarEmpleados';
}

/// Envuelve una pantalla que exige un permiso concreto.
///
/// Si el usuario no lo tiene, no se pinta el contenido: se explica qué falta
/// y a quién pedírselo. Va en la **pantalla**, no solo en el botón que lleva
/// a ella — un empleado puede llegar por un enlace, por el historial de
/// navegación o por una notificación, no solo tocando el acceso directo.
///
/// Esto es comodidad y claridad, no seguridad: quien manda son las reglas de
/// Firestore. Un cliente modificado puede saltarse este widget; no puede
/// saltarse el servidor.
class PermisoRequerido extends ConsumerWidget {
  const PermisoRequerido({
    super.key,
    required this.permiso,
    required this.child,
    this.titulo,
    this.detalle,
  });

  final String permiso;
  final Widget child;

  /// Qué se estaba intentando ver, en palabras del dueño del negocio.
  final String? titulo;
  final String? detalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(puedeProvider(permiso))) return child;

    final t = context.libreta;
    return Scaffold(
      backgroundColor: t.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                child: Row(
                  children: [
                    LibretaBackButton(
                      oscuro: true,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0x24F2A93C),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 28,
                            color: LibretaColors.aviso,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          titulo ?? 'Esta sección es del dueño',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: t.textoFuerte,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detalle ??
                              'Tu cuenta no tiene este permiso todavía. Pídele '
                                  'al dueño del negocio que te lo active desde '
                                  'Ajustes › Empleados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: t.textoMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
