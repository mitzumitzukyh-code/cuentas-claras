import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_assets.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/invitacion.dart';
import '../../../shared/utils/errores.dart';

/// Unirse a un negocio con un código de invitación (réplica visual de
/// `P2 · UNIRSE`, `Lote F · Onboarding y Sistema`).
///
/// Es la otra mitad de la pantalla de Empleados: el dueño genera el código y
/// quien lo recibe entra por aquí. Valida antes de aceptar para poder decir a
/// qué negocio se está uniendo.
class UnirseCodigoScreen extends ConsumerStatefulWidget {
  const UnirseCodigoScreen({super.key});

  @override
  ConsumerState<UnirseCodigoScreen> createState() => _UnirseCodigoScreenState();
}

class _UnirseCodigoScreenState extends ConsumerState<UnirseCodigoScreen> {
  final _codigo = TextEditingController();

  bool _verificando = false;
  bool _uniendo = false;
  String? _error;
  Invitacion? _encontrada;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _verificar() async {
    setState(() {
      _verificando = true;
      _error = null;
      _encontrada = null;
    });
    try {
      final inv = await ref
          .read(negocioRepositoryProvider)
          .buscarInvitacion(_codigo.text);

      if (!mounted) return;
      if (inv == null) {
        setState(() => _error = 'Ese código no existe. Revísalo con el dueño.');
      } else if (inv.usado) {
        setState(() => _error = 'Ese código ya se usó. Pide uno nuevo.');
      } else if (inv.vencida) {
        setState(() => _error = 'Ese código venció. Pide uno nuevo.');
      } else {
        setState(() => _encontrada = inv);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = mensajeDeError(e, accion: 'verificar el código'));
      }
    } finally {
      if (mounted) setState(() => _verificando = false);
    }
  }

  Future<void> _unirse() async {
    final inv = _encontrada;
    final user = ref.read(authStateProvider).valueOrNull;
    if (inv == null || user == null) return;

    setState(() => _uniendo = true);
    try {
      await ref.read(negocioRepositoryProvider).aceptarInvitacion(
            invitacion: inv,
            usuarioId: user.uid,
            nombre: user.displayName,
            correo: user.email,
          );
      // Al crearse la membresía el router lleva solo al Dashboard.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uniendo = false;
        _error = mensajeDeError(e, accion: 'unirte al negocio');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _encontrada;

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: LibretaBackButton(
                  oscuro: true,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 20),
              // Solo el contenido scrollea y el botón queda anclado abajo. Con
              // un `Spacer()` al final, al abrirse el teclado el Scaffold
              // encoge el cuerpo, el Spacer se colapsa a cero y lo que sobra
              // desborda — con la tarjeta de confirmación a la vista, unos
              // 180 px de sobra. Es el mismo fallo que ya se corrigió en la
              // pantalla de rubro.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: LibretaColors.verde.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const LibretaIcono(AppAssets.navClientes, size: 30, color: LibretaColors.verde),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Unirme a un negocio',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.libreta.textoFuerte,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pídele al dueño el código de invitación que aparece en su app.',
                        style: TextStyle(fontSize: 14, color: context.libreta.textoMuted),
                      ),
                      const SizedBox(height: 22),

                      LibretaInput(
                        controller: _codigo,
                        hint: 'ABC123',
                        height: 56,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        // El código se guarda en mayúsculas y la pista las enseña; sin
                        // esto se escribía en minúsculas y no coincidía con lo que el
                        // dueño está leyendo en su pantalla. La búsqueda ya normaliza,
                        // así que es cosa de que se vea igual.
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (_codigo.text.trim().length == 6) _verificar();
                        },
                        onChanged: (_) => setState(() {
                          _encontrada = null;
                          _error = null;
                        }),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        LibretaBannerError(mensaje: _error!),
                      ],

                      // Confirmación antes de aceptar: que sepa a dónde entra.
                      if (inv != null) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: context.libreta.superficie,
                            border: Border.all(color: context.libreta.renglon),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: LibretaColors.verde.withValues(alpha: .10),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const LibretaIcono(AppAssets.catBodega,
                                  size: 28,
                                  color: LibretaColors.verde,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                inv.negocioNombre,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: context.libreta.textoFuerte,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Entrarás como ${inv.rol.etiqueta.toLowerCase()}',
                                style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (inv == null)
                LibretaButton(
                  label: 'Verificar código',
                  loading: _verificando,
                  onPressed:
                      _codigo.text.trim().length == 6 ? _verificar : null,
                )
              else
                LibretaButton(
                  label: 'Unirme a ${inv.negocioNombre}',
                  loading: _uniendo,
                  onPressed: _unirse,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
