import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/notificaciones/luz_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../data/cronograma_repository.dart';
import '../domain/cronograma_luz.dart';

/// Ajustes de los avisos de corte de luz.
///
/// Vive dentro de la sección «Avisos» y no en una pantalla aparte: es una
/// preferencia de notificación como las demás, y sacarla a su propia pantalla
/// la escondería.
///
/// **Viene apagado.** Solo sirve si vives donde hay cronograma cargado; un
/// aviso sobre Barinas a alguien de Maracaibo es ruido, y el ruido acaba con
/// el dueño apagando TODAS las notificaciones de la app.
class CortesLuzSeccion extends ConsumerStatefulWidget {
  const CortesLuzSeccion({super.key});

  @override
  ConsumerState<CortesLuzSeccion> createState() => _CortesLuzSeccionState();
}

class _CortesLuzSeccionState extends ConsumerState<CortesLuzSeccion> {
  CronogramaLuz? _cronograma;
  bool _cargando = true;
  bool _verSectores = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final repo = ref.read(cronogramaRepositoryProvider);
    final c = await repo.vigente();
    if (!mounted) return;
    setState(() {
      _cronograma = c;
      _cargando = false;
    });
  }

  Future<void> _cambiarActivo(bool valor) async {
    final repo = ref.read(cronogramaRepositoryProvider);
    await repo.guardarActivo(valor);
    // Reprograma en el acto: encender el interruptor y que no pase nada hasta
    // el siguiente arranque es la clase de detalle que hace desconfiar.
    await ref.read(luzServiceProvider).sincronizar();
    if (mounted) setState(() {});
  }

  /// Enseña cómo se verá el aviso. No prueba la entrega —de eso se encarga el
  /// Worker— sino el canal, el permiso y el aspecto.
  Future<void> _probar() async {
    await ref.read(luzServiceProvider).probar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Así se verá. Los avisos de verdad llegan solos, '
            'aunque tengas la app cerrada.'),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _elegirBloque(String bloque) async {
    final repo = ref.read(cronogramaRepositoryProvider);
    await repo.guardarBloque(repo.bloque == bloque ? null : bloque);
    await ref.read(luzServiceProvider).sincronizar();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final repo = ref.watch(cronogramaRepositoryProvider);
    final cronograma = _cronograma;
    final bloque = repo.bloque;

    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    // Sin cronograma no se ofrece nada: prometer un aviso que no va a llegar
    // es peor que no ofrecerlo.
    if (cronograma == null) {
      return _Nota(
        texto: 'Todavía no tenemos el cronograma de cortes de tu zona. '
            'Cuando lo tengamos, aquí podrás activar el aviso.',
      );
    }

    final hoy = DateTime.now();
    final vigente = cronograma.cubre(hoy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CORTES DE LUZ',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: t.textoMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Te avisamos media hora antes de que se vaya la luz en tu bloque, '
          'y a qué hora debería volver.',
          style: TextStyle(fontSize: 12.5, height: 1.35, color: t.textoMuted),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: Text(
                '¿Cuál es tu bloque?',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: t.textoFuerte,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _verSectores = !_verSectores),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text(
                  _verSectores ? 'Ocultar sectores' : 'Ver sectores',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: LibretaColors.verde,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final b in cronograma.bloques) ...[
              Expanded(
                child: _BotonBloque(
                  letra: b,
                  elegido: bloque == b,
                  onTap: () => _elegirBloque(b),
                ),
              ),
              if (b != cronograma.bloques.last) const SizedBox(width: 8),
            ],
          ],
        ),

        if (_verSectores) ...[
          const SizedBox(height: 10),
          for (final b in cronograma.bloques)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontSize: 12, color: t.textoMuted),
                  children: [
                    TextSpan(
                      text: 'Bloque $b: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: t.textoFuerte,
                      ),
                    ),
                    TextSpan(text: cronograma.sectores[b]!.join(', ')),
                  ],
                ),
              ),
            ),
        ],

        if (bloque != null) ...[
          const SizedBox(height: 12),
          _ResumenBloque(cronograma: cronograma, bloque: bloque, hoy: hoy),
          const SizedBox(height: 4),
          _FilaSwitch(
            titulo: 'Avísame antes del corte',
            detalle: vigente
                ? 'Media hora antes, y cuando debería volver'
                : 'El cronograma que tenemos ya venció',
            valor: repo.activo,
            onChanged: vigente ? _cambiarActivo : null,
          ),
          if (repo.activo)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _probar,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Mándame uno de prueba',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: LibretaColors.verde,
                    ),
                  ),
                ),
              ),
            ),
        ],

        if (!vigente)
          _Nota(
            texto: 'El cronograma que tenemos llega hasta el '
                '${_fechaCorta(cronograma.hasta)}. Mientras no publiquemos el '
                'siguiente no te vamos a avisar: preferimos callarnos antes '
                'que darte una hora que no es.',
          ),
      ],
    );
  }
}

String _fechaCorta(DateTime d) {
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${d.day} de ${meses[d.month - 1]}';
}

/// Lo que le toca al bloque elegido hoy y mañana.
class _ResumenBloque extends StatelessWidget {
  const _ResumenBloque({
    required this.cronograma,
    required this.bloque,
    required this.hoy,
  });

  final CronogramaLuz cronograma;
  final String bloque;
  final DateTime hoy;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final deHoy = cronograma.franja(hoy, bloque);
    final manana = DateTime(hoy.year, hoy.month, hoy.day + 1);
    final deManana = cronograma.franja(manana, bloque);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.papel,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deHoy == null
                ? 'Hoy no te toca corte'
                : 'Hoy: ${deHoy.comoTexto}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: t.textoFuerte,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            deManana == null
                ? 'Mañana no hay corte en el cronograma'
                : 'Mañana: ${deManana.comoTexto}',
            style: TextStyle(fontSize: 12.5, color: t.textoMuted),
          ),
        ],
      ),
    );
  }
}

class _BotonBloque extends StatelessWidget {
  const _BotonBloque({
    required this.letra,
    required this.elegido,
    required this.onTap,
  });

  final String letra;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Semantics(
      button: true,
      selected: elegido,
      label: 'Bloque $letra',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: elegido
                ? LibretaColors.verde.withValues(alpha: .12)
                : t.superficie,
            border: Border.all(
              color: elegido ? LibretaColors.verde : t.bordeSuave,
              width: elegido ? 1.6 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            letra,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: elegido ? LibretaColors.verde : t.textoFuerte,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaSwitch extends StatelessWidget {
  const _FilaSwitch({
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String detalle;
  final bool valor;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: t.textoFuerte,
                ),
              ),
              Text(
                detalle,
                style: TextStyle(fontSize: 12, color: t.textoMuted),
              ),
            ],
          ),
        ),
        Switch(
          value: valor,
          onChanged: onChanged,
          activeColor: LibretaColors.verde,
        ),
      ],
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LibretaColors.aviso.withValues(alpha: 0.10),
        border: Border.all(color: LibretaColors.aviso),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: context.libreta.textoFuerte,
        ),
      ),
    );
  }
}
