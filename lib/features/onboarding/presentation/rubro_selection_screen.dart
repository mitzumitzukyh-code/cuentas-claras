import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/bcv/bcv_rate_service.dart';
import '../../../shared/presentation/neu.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/rubro.dart';
import 'unirse_codigo_screen.dart';

/// Pantalla 3 — Onboarding (bloque `isOnboarding` del diseño).
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
  String _moneda = 'USD';
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
      await ref.read(negocioRepositoryProvider).crearNegocio(
            usuarioId: user.uid,
            nombre: _nombre.text.trim(),
            rubro: _rubro!,
            nombreUsuario: user.displayName,
            correoUsuario: user.email,
          );
      // Al crearse la membresía, `sesionProvider` pasa a `listo` y el router
      // redirige al Dashboard automáticamente.
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo crear el negocio: $e'),
          backgroundColor: AppColors.peligro,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BarraPasos(
                paso: _paso,
                total: _totalPasos,
                onAtras: _paso == 0 ? null : _atras,
              ),
              const SizedBox(height: 20),
              // Cada paso usa `Spacer` para empujar el botón al pie. Al subir
              // el teclado la altura disponible se reduce, así que el contenido
              // tiene que poder desplazarse en vez de desbordar.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight),
                      child: IntrinsicHeight(
                        child: switch (_paso) {
                  0 => _PasoNegocio(
                      nombre: _nombre,
                      rubro: _rubro,
                      onRubro: (r) => setState(() => _rubro = r),
                      onCambio: () => setState(() {}),
                      onSiguiente: _siguiente,
                    ),
                  1 => _PasoMoneda(
                      moneda: _moneda,
                      onMoneda: (m) => setState(() => _moneda = m),
                      onSiguiente: _siguiente,
                    ),
                          _ => _PasoResumen(
                              nombreNegocio: _nombre.text.trim(),
                              rubro: _rubro,
                              moneda: _moneda,
                              cargando: _cargando,
                              onEmpezar: _crearNegocio,
                            ),
                        },
                      ),
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
    final t = context.tokens;
    return Row(
      children: [
        SizedBox(
          width: 36,
          child: onAtras == null
              ? null
              : NeuIconBtn(icon: Icons.arrow_back, onTap: onAtras),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == paso ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= paso ? AppColors.marca : t.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
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
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          paso,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.marca,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: t.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitulo, style: TextStyle(fontSize: 14, color: t.textSec)),
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
    final t = context.tokens;
    final listo = nombre.text.trim().isNotEmpty && rubro != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Encabezado(
          paso: 'PASO 1 DE 3',
          titulo: '¿Cómo se llama tu negocio?',
          subtitulo: 'Así lo verán tus recibos y tu equipo.',
        ),
        const SizedBox(height: 22),
        NeuInput(
          controller: nombre,
          hint: 'Ej: Abasto La Esquina',
          height: 52,
          onChanged: (_) => onCambio(),
        ),
        const SizedBox(height: 22),
        Text(
          'Rubro de tu negocio',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: t.textSec,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in Rubro.values)
              NeuChip(
                label: r.etiqueta,
                selected: rubro == r,
                onTap: () => onRubro(r),
              ),
          ],
        ),
        const Spacer(),
        NeuButton(
          label: 'Continuar',
          onPressed: listo ? onSiguiente : null,
        ),
        const SizedBox(height: 12),
        // Salida para quien fue invitado y no viene a crear su propio negocio.
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const UnirseCodigoScreen(),
              ),
            ),
            child: Text.rich(
              TextSpan(
                text: '¿Te invitaron? ',
                style: TextStyle(fontSize: 13, color: t.textSec),
                children: const [
                  TextSpan(
                    text: 'Entra con tu código',
                    style: TextStyle(
                      color: AppColors.marca,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paso 2 — moneda base y tasa BCV del día.
class _PasoMoneda extends ConsumerWidget {
  const _PasoMoneda({
    required this.moneda,
    required this.onMoneda,
    required this.onSiguiente,
  });

  final String moneda;
  final ValueChanged<String> onMoneda;
  final VoidCallback onSiguiente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasaAsync = ref.watch(bcvRateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Encabezado(
          paso: 'PASO 2 DE 3',
          titulo: '¿En qué moneda manejas tus precios?',
          subtitulo: 'Podrás cobrar y ver todo en ambas monedas.',
        ),
        const SizedBox(height: 22),
        _OpcionMoneda(
          titulo: 'Dólares (USD)',
          detalle: 'Precios base en \$, conversión automática',
          seleccionado: moneda == 'USD',
          onTap: () => onMoneda('USD'),
        ),
        const SizedBox(height: 10),
        _OpcionMoneda(
          titulo: 'Bolívares (Bs)',
          detalle: 'Precios base en Bs, referencia en \$',
          seleccionado: moneda == 'Bs',
          onTap: () => onMoneda('Bs'),
        ),
        const SizedBox(height: 22),
        _TarjetaTasa(
          tasaAsync: tasaAsync,
          onRefrescar: () => ref.invalidate(bcvRateProvider),
        ),
        const Spacer(),
        NeuButton(label: 'Continuar', onPressed: onSiguiente),
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
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado ? t.tint : t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? AppColors.marca : t.border,
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
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 13, color: t.textSec),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seleccionado ? AppColors.marca : Colors.transparent,
                border: Border.all(
                  color: seleccionado ? AppColors.marca : t.border,
                  width: 2,
                ),
              ),
            ),
          ],
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
    final t = context.tokens;
    return NeuCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                  color: t.textSec,
                ),
              ),
              GestureDetector(
                onTap: onRefrescar,
                child: Icon(Icons.refresh, size: 18, color: t.textSec),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Bs', style: TextStyle(fontSize: 15, color: t.textSec)),
              const SizedBox(width: 8),
              Expanded(
                child: tasaAsync.when(
                  loading: () => Text(
                    '—',
                    style: AppTypography.money(
                      fontSize: 20,
                      color: AppColors.marca,
                    ),
                  ),
                  error: (_, __) => Text(
                    'sin conexión',
                    style: TextStyle(fontSize: 14, color: t.textSec),
                  ),
                  data: (r) => Text(
                    MoneyFormatter.bs(r.tasa).replaceFirst('Bs ', ''),
                    style: AppTypography.money(
                      fontSize: 20,
                      color: AppColors.marca,
                    ),
                  ),
                ),
              ),
              Text(
                'por \$1',
                style: TextStyle(fontSize: 13, color: t.textSec),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Se actualiza automáticamente con la publicada por el BCV',
            style: TextStyle(fontSize: 11.5, color: t.textSec),
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
    required this.moneda,
    required this.cargando,
    required this.onEmpezar,
  });

  final String nombreNegocio;
  final Rubro? rubro;
  final String moneda;
  final bool cargando;
  final VoidCallback onEmpezar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tasa = ref.watch(bcvRateProvider).valueOrNull;

    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(color: t.tint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Text('✓', style: TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 18),
        const Text(
          'PASO 3 DE 3',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.marca,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¡Todo listo, $nombreNegocio!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: t.text,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 260,
          child: Text(
            'Configuramos tu cuenta para empezar a vender hoy mismo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: t.textSec),
          ),
        ),
        const SizedBox(height: 18),
        NeuCard(
          radius: 20,
          clip: true,
          child: Column(
            children: [
              _FilaResumen(
                etiqueta: 'Rubro',
                valor: rubro?.etiqueta ?? '—',
              ),
              _FilaResumen(etiqueta: 'Moneda principal', valor: moneda),
              _FilaResumen(
                etiqueta: 'Tasa BCV',
                valor: tasa == null ? '—' : MoneyFormatter.bs(tasa.tasa),
                ultima: true,
              ),
            ],
          ),
        ),
        const Spacer(),
        NeuButton(
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
    final t = context.tokens;
    return NeuListTile(
      divider: !ultima,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 13, color: t.textSec)),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}
