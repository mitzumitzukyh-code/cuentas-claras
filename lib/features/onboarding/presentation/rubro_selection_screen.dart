import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../../negocio/domain/modo_precio.dart';
import '../domain/rubro.dart';
import 'unirse_codigo_screen.dart';

/// Pantalla 3 — Onboarding (réplica visual de `P0 · RUBRO`, `Lote F ·
/// Onboarding y Sistema`).
///
/// El prototipo lo plantea en 4 pasos; aquí se implementan los que aplican a un
/// usuario ya autenticado: **negocio + rubro**, **moneda + tasa BCV** y el
/// **resumen** final. El paso de credenciales vive en el login.
class RubroSelectionScreen extends ConsumerStatefulWidget {
  const RubroSelectionScreen({super.key});

  @override
  ConsumerState<RubroSelectionScreen> createState() =>
      _RubroSelectionScreenState();
}

class _RubroSelectionScreenState extends ConsumerState<RubroSelectionScreen> {
  final _nombre = TextEditingController();

  int _paso = 0;
  Rubro? _rubro;
  ModoPrecio _modoPrecio = ModoPrecio.usd;
  bool _cargando = false;

  static const _totalPasos = 3;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  void _siguiente() => setState(() => _paso++);

  void _atras() {
    if (_paso == 0) return;
    setState(() => _paso--);
  }

  Future<void> _crearNegocio() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || _rubro == null) return;

    setState(() => _cargando = true);
    try {
      final negocio = await ref
          .read(negocioRepositoryProvider)
          .crearNegocio(
            usuarioId: user.uid,
            nombre: _nombre.text.trim(),
            rubro: _rubro!,
            modoPrecio: _modoPrecio,
            nombreUsuario: user.displayName,
            correoUsuario: user.email,
          );
      if (!mounted) return;

      // El negocio recién creado pasa a ser el activo. Sin esto, quien abre
      // una segunda sucursal aterriza en el Dashboard de la anterior: la
      // membresía activa cae en `membresias.first`, que sigue siendo la vieja.
      ref.read(negocioSeleccionadoProvider.notifier).state = negocio.id;

      // La salida se navega aquí y no se deja al redirect del router: con
      // sesión ya activa (segunda sucursal) el estado no cambia al terminar,
      // así que no habría ningún redirect que disparara y la pantalla se
      // quedaría puesta. Ver el comentario en `app_router.dart`.
      if (!mounted) return;
      context.go(Routes.dashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeError(e, accion: 'crear el negocio')),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        spiral: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraPasos(
                  paso: _paso,
                  total: _totalPasos,
                  onAtras: _paso == 0 ? null : _atras,
                ),
                const SizedBox(height: 20),
                // Solo el contenido scrollea; el botón del paso queda anclado
                // abajo, como en el diseño. Antes el paso entero iba dentro de
                // un `SingleChildScrollView` con un `Spacer()` al final: el
                // Spacer se come el espacio sobrante y, cuando el contenido
                // pasaba del alto de pantalla, el botón quedaba fuera y la
                // lista no se dejaba desplazar.
                Expanded(
                  child: switch (_paso) {
                    0 => _PasoNegocio(
                      nombre: _nombre,
                      rubro: _rubro,
                      onRubro: (r) => setState(() => _rubro = r),
                      onCambio: () => setState(() {}),
                      onSiguiente: _siguiente,
                    ),
                    1 => _PasoMoneda(
                      modo: _modoPrecio,
                      onModo: (m) => setState(() => _modoPrecio = m),
                      onSiguiente: _siguiente,
                    ),
                    _ => _PasoResumen(
                      nombreNegocio: _nombre.text.trim(),
                      rubro: _rubro,
                      modo: _modoPrecio,
                      cargando: _cargando,
                      onEmpezar: _crearNegocio,
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "atrás" + los puntos de progreso (el activo es más ancho).
class _BarraPasos extends StatelessWidget {
  const _BarraPasos({
    required this.paso,
    required this.total,
    required this.onAtras,
  });

  final int paso;
  final int total;
  final VoidCallback? onAtras;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 36,
          child:
              onAtras == null
                  ? null
                  : LibretaBackButton(oscuro: true, onTap: onAtras),
        ),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          i <= paso
                              ? LibretaColors.verde
                              : context.libreta.bordeSuave,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 36),
      ],
    );
  }
}

/// Encabezado "PASO N DE M" + título + subtítulo.
class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.paso,
    required this.titulo,
    required this.subtitulo,
  });

  final String paso;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paso,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: LibretaColors.verde,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.libreta.textoFuerte,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: TextStyle(fontSize: 14, color: context.libreta.textoMuted),
        ),
      ],
    );
  }
}

/// Paso 1 — nombre del negocio y rubro.
class _PasoNegocio extends StatelessWidget {
  const _PasoNegocio({
    required this.nombre,
    required this.rubro,
    required this.onRubro,
    required this.onCambio,
    required this.onSiguiente,
  });

  final TextEditingController nombre;
  final Rubro? rubro;
  final ValueChanged<Rubro> onRubro;
  final VoidCallback onCambio;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context) {
    final listo = nombre.text.trim().isNotEmpty && rubro != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Encabezado(
                  paso: 'PASO 1 DE 3',
                  titulo: '¿Cómo se llama tu negocio?',
                  subtitulo: 'Así lo verán tus recibos y tu equipo.',
                ),
                const SizedBox(height: 16),
                LibretaSecondaryButton(
                  label: '¿Te invitaron? Entra con tu código',
                  height: 46,
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const UnirseCodigoScreen(),
                        ),
                      ),
                ),
                const SizedBox(height: 22),
                LibretaInput(
                  controller: nombre,
                  hint: 'Ej: Abasto La Esquina',
                  height: 52,
                  // Este nombre va al título del paso 3, a los recibos y al
                  // catálogo. Sin tope, solo se validaba que no estuviera
                  // vacío.
                  maxLength: 40,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => onCambio(),
                ),
                const SizedBox(height: 22),
                Text(
                  'Rubro de tu negocio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.libreta.textoMuted,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [
                    for (final r in Rubro.values)
                      _TarjetaRubro(
                        rubro: r,
                        seleccionado: rubro == r,
                        onTap: () => onRubro(r),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LibretaButton(
          label: 'Continuar',
          onPressed: listo ? onSiguiente : null,
        ),
      ],
    );
  }
}

class _TarjetaRubro extends StatelessWidget {
  const _TarjetaRubro({
    required this.rubro,
    required this.seleccionado,
    required this.onTap,
  });

  final Rubro rubro;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // La etiqueta la pone el propio texto de la tarjeta y la acción de toque
    // el `GestureDetector`; aquí solo se añaden el rol y el estado, y se funde
    // todo en un nodo. Sin esto, un lector de pantalla recorría la cuadrícula
    // sin decir nunca cuál rubro está elegido.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: seleccionado,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: seleccionado
                  ? LibretaColors.verde.withValues(alpha: .06)
                  : context.libreta.superficie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: seleccionado
                    ? LibretaColors.verde
                    : context.libreta.bordeSuave,
                width: seleccionado ? 2 : 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pastilla con el color propio del rubro: la cuadrícula se
                // recorre por color antes que por texto.
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rubro.color,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: LibretaIcono(
                    rubro.icono,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  rubro.etiqueta,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.libreta.textoFuerte,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paso 2 — moneda base y tasa BCV del día.
class _PasoMoneda extends ConsumerWidget {
  const _PasoMoneda({
    required this.modo,
    required this.onModo,
    required this.onSiguiente,
  });

  final ModoPrecio modo;
  final ValueChanged<ModoPrecio> onModo;
  final VoidCallback onSiguiente;

  /// Las dos opciones que pinta este paso. `ModoPrecio.ambas` existe pero no
  /// entra aquí: el diseño del onboarding plantea una elección binaria, y ese
  /// tercer modo está pensado para Ajustes.
  static const _opciones = [ModoPrecio.usd, ModoPrecio.ves];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasaAsync = ref.watch(bcvRateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Encabezado(
                  paso: 'PASO 2 DE 3',
                  titulo: '¿En qué moneda manejas tus precios?',
                  subtitulo: 'Podrás cobrar y ver todo en ambas monedas.',
                ),
                const SizedBox(height: 22),
                // Los textos salen del enum y no de literales copiados aquí:
                // eran los mismos, y así Ajustes y el onboarding no pueden
                // acabar describiendo lo mismo con palabras distintas.
                for (final opcion in _opciones) ...[
                  if (opcion != _opciones.first) const SizedBox(height: 10),
                  _OpcionMoneda(
                    titulo: opcion.etiqueta,
                    detalle: opcion.detalle,
                    seleccionado: modo == opcion,
                    onTap: () => onModo(opcion),
                  ),
                ],
                const SizedBox(height: 22),
                _TarjetaTasa(
                  tasaAsync: tasaAsync,
                  onRefrescar: () => ref.invalidate(bcvRateProvider),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LibretaButton(label: 'Continuar', onPressed: onSiguiente),
      ],
    );
  }
}

class _OpcionMoneda extends StatelessWidget {
  const _OpcionMoneda({
    required this.titulo,
    required this.detalle,
    required this.seleccionado,
    required this.onTap,
  });

  final String titulo;
  final String detalle;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `inMutuallyExclusiveGroup`: son opciones excluyentes, y así el lector de
    // pantalla las anuncia como el grupo de radio que son en vez de como dos
    // botones sueltos.
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: seleccionado,
        child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado
              ? LibretaColors.verde.withValues(alpha: .06)
              : context.libreta.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                seleccionado ? LibretaColors.verde : context.libreta.bordeSuave,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seleccionado ? LibretaColors.verde : Colors.transparent,
                border: Border.all(
                  color:
                      seleccionado
                          ? LibretaColors.verde
                          : context.libreta.bordeSuave,
                  width: 2,
                ),
              ),
              child: seleccionado
                  ? const LibretaIcono(
                      AppAssets.accConfirmar,
                      size: 13,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}

/// Tarjeta "Tasa BCV oficial de hoy" con botón de refresco.
class _TarjetaTasa extends StatelessWidget {
  const _TarjetaTasa({required this.tasaAsync, required this.onRefrescar});

  final AsyncValue<BcvRate> tasaAsync;
  final VoidCallback onRefrescar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.libreta.superficie,
        border: Border.all(color: context.libreta.renglon),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tasa BCV oficial de hoy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.libreta.textoMuted,
                ),
              ),
              // Icono de 18 px con caja de 48: crece lo que se puede pulsar,
              // no lo que se ve. El `centerRight` lo deja en su sitio.
              Semantics(
                button: true,
                label: 'Actualizar la tasa',
                child: GestureDetector(
                  onTap: onRefrescar,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: context.libreta.textoMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Bs',
                style: TextStyle(
                  fontSize: 15,
                  color: context.libreta.textoMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: tasaAsync.when(
                  loading:
                      () => const Text(
                        '—',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: LibretaColors.verde,
                        ),
                      ),
                  error:
                      (_, __) => Text(
                        'sin conexión',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                  data:
                      (r) => Text(
                        MoneyFormatter.bs(r.tasa).replaceFirst('Bs ', ''),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: LibretaColors.verde,
                        ),
                      ),
                ),
              ),
              Text(
                'por \$1',
                style: TextStyle(
                  fontSize: 13,
                  color: context.libreta.textoMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Se actualiza automáticamente con la publicada por el BCV',
            style: TextStyle(fontSize: 11.5, color: context.libreta.textoMuted),
          ),
        ],
      ),
    );
  }
}

/// Paso 3 — resumen y creación del negocio.
class _PasoResumen extends ConsumerWidget {
  const _PasoResumen({
    required this.nombreNegocio,
    required this.rubro,
    required this.modo,
    required this.cargando,
    required this.onEmpezar,
  });

  final String nombreNegocio;
  final Rubro? rubro;
  final ModoPrecio modo;
  final bool cargando;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasa = ref.watch(bcvRateProvider).valueOrNull;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: LibretaColors.verde.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const LibretaIcono(AppAssets.accConfirmar,
                    size: 40,
                    color: LibretaColors.verde,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'PASO 3 DE 3',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¡Todo listo, $nombreNegocio!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.libreta.textoFuerte,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 260,
                  child: Text(
                    'Configuramos tu cuenta para empezar a vender hoy mismo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: context.libreta.renglon),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _FilaResumen(
                        etiqueta: 'Rubro',
                        valor: rubro?.etiqueta ?? '—',
                      ),
                      _FilaResumen(
                        etiqueta: 'Moneda principal',
                        valor: modo.etiquetaCorta,
                      ),
                      _FilaResumen(
                        etiqueta: 'Tasa BCV',
                        valor:
                            tasa == null ? '—' : MoneyFormatter.bs(tasa.tasa),
                        ultima: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        LibretaButton(
          label: 'Empezar a vender',
          loading: cargando,
          onPressed: onEmpezar,
        ),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.etiqueta,
    required this.valor,
    this.ultima = false,
  });

  final String etiqueta;
  final String valor;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border:
            ultima
                ? null
                : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 13, color: context.libreta.textoMuted),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.libreta.textoFuerte,
            ),
          ),
        ],
      ),
    );
  }
}
