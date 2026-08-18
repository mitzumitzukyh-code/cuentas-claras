import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/confianza.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/utils/numero_ve.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/errores.dart';
import '../../auth/data/auth_repository.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/fiado_repository.dart';
import '../domain/fiado_leido.dart';

/// Pasar al libro las deudas que ya están escritas en el cuaderno de papel.
///
/// Es la puerta de entrada de quien viene usando una libreta: sin esto, para
/// empezar a llevar los fiados en la app había que teclear cliente por cliente
/// lo que ya estaba anotado, y esa es exactamente la tarde de trabajo que hace
/// que la libreta gane.
///
/// **La moneda se pregunta antes de la foto y no se deduce.** Ver
/// [MonedaCuaderno]: un «150» manuscrito puede ser Bs o \$, las dos cosas son
/// verosímiles, y errar multiplica la deuda por setecientos y pico.
class ImportarFiadosScreen extends ConsumerStatefulWidget {
  const ImportarFiadosScreen({super.key});

  @override
  ConsumerState<ImportarFiadosScreen> createState() =>
      _ImportarFiadosScreenState();
}

class _ImportarFiadosScreenState extends ConsumerState<ImportarFiadosScreen> {
  MonedaCuaderno? _moneda;
  List<FiadoLeido> _filas = [];
  bool _leyendo = false;
  bool _guardando = false;

  /// Nombres que ya tienen ficha, en minúscula. Un renglón que casa con uno de
  /// estos no crea un cliente nuevo: le **suma** a su deuda, y eso hay que
  /// decirlo antes de guardar, no después.
  Set<String> _yaTienenCuenta = const {};

  Future<void> _elegirFuente() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HojaFuente(),
    );
    if (fuente == null || !mounted) return;
    await _leerFoto(fuente);
  }

  Future<void> _leerFoto(ImageSource fuente) async {
    // Más resolución que en el resto de la app: aquí lo que se fotografía es
    // bolígrafo sobre renglón, muchas veces de noche y con la letra pequeña de
    // un bloque de seis prendas. A 1600 px de ancho un «6» y un «5» se
    // confunden, y el techo del Worker son 6 MB — un JPEG de 2000 px no llega
    // ni a medio.
    final x = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (x == null || !mounted) return;

    setState(() => _leyendo = true);
    try {
      final leidas =
          await ref.read(lectorEtiquetaServiceProvider).leerFiados(File(x.path));

      // Los nombres que ya existen se piden ahora y no al guardar: el aviso de
      // "esto se le suma a lo que ya debe" solo sirve si se ve mientras se
      // revisa la tabla.
      final membresia = ref.read(membresiaActivaProvider);
      var existentes = <String>{};
      if (membresia != null) {
        try {
          final mapa = await ref
              .read(fiadoRepositoryProvider)
              .nombresExistentes(membresia.negocioId);
          existentes = mapa.keys.toSet();
        } catch (_) {
          // Si falla, se pierde el aviso pero no la importación.
        }
      }

      if (!mounted) return;
      setState(() {
        _filas = leidas;
        _yaTienenCuenta = existentes;
        _leyendo = false;
      });
      // Página leída pero sin deudas: lo normal es que estén todas tachadas o
      // con un "pagó" al lado, y eso no se copia a propósito. Decirlo evita
      // que el dueño repita la foto cuatro veces creyendo que falló la
      // cámara.
      if (leidas.isEmpty) {
        _avisar(
          'Leímos la página pero no vimos deudas pendientes. Lo tachado o '
          'marcado «pagó» no se copia.',
        );
      }
    } on SinReconocer {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar(
        'No reconocimos deudas en la foto. Prueba con más luz y una sola '
        'página, de frente y completa.',
      );
    } on LimiteDiarioIA {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar('Se agotaron las lecturas con IA por hoy. Vuelve mañana.');
    } on LectorOcupado {
      // Saturado, no roto: la foto y la conexión están bien y lo
      // único que hace falta es esperar.
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar(
        'El lector está ocupado ahora mismo. Espera un momento y vuelve a intentarlo.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar(mensajeDeError(e, accion: 'leer la foto'));
    }
  }

  /// Las filas que se pueden guardar: las que tienen monto convertible a USD.
  ///
  /// La tasa entra por parámetro —la que la pantalla está observando— y no se
  /// lee aquí dentro: leerla con `read` en pleno `build` significa que si
  /// llega la tasa del día mientras la tabla está abierta, el botón sigue
  /// diciendo lo que decía antes.
  List<({String nombre, double montoUSD, String concepto})> _listas(
    double? tasa,
  ) {
    final moneda = _moneda;
    if (moneda == null) return const [];
    final out = <({String nombre, double montoUSD, String concepto})>[];
    for (final f in _filas) {
      final usd = f.montoUSD(moneda: moneda, tasa: tasa);
      if (usd == null || usd <= 0) continue;
      out.add((
        nombre: f.nombre,
        montoUSD: usd,
        // Queda escrito en el libro mayor de dónde salió: dentro de un mes,
        // "Del cuaderno" es la diferencia entre una deuda que se puede
        // defender delante del cliente y una cifra sin origen.
        concepto: (f.concepto ?? '').trim().isEmpty
            ? 'Del cuaderno'
            : 'Del cuaderno · ${f.concepto!.trim()}',
      ));
    }
    return out;
  }

  Future<void> _importar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final user = ref.read(authStateProvider).valueOrNull;
    final filas = _listas(ref.read(tasaActivaValorProvider));
    if (membresia == null || user == null || filas.isEmpty) return;

    setState(() => _guardando = true);
    try {
      final guardados = await ref
          .read(fiadoRepositoryProvider)
          .importarDesdeCuaderno(
            membresia.negocioId,
            filas: filas,
            registradoPor: user.uid,
          );
      if (!mounted) return;
      final sinMonto = _filas.length - filas.length;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sinMonto == 0
                ? '$guardados ${guardados == 1 ? "deuda anotada" : "deudas anotadas"}'
                : '$guardados anotadas · $sinMonto sin monto se quedaron fuera',
          ),
          duration: Duration(seconds: sinMonto == 0 ? 4 : 7),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar(mensajeDeError(e, accion: 'anotar las deudas'));
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final tasa = ref.watch(tasaActivaValorProvider);
    final moneda = _moneda;
    // Un cuaderno en bolívares sin tasa no se puede pasar a dólares, que es
    // como la app guarda las deudas. Se dice y se bloquea: importar con una
    // tasa inventada es peor que no importar.
    final faltaTasa = moneda == MonedaCuaderno.bs && (tasa == null || tasa <= 0);
    final listas = _listas(tasa);

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pasar tu cuaderno',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: t.textoFuerte,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Fotografía la página y anotamos las deudas.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: t.textoMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Paso 1: la moneda, antes de la cámara ---
              Text(
                '1 · ¿EN QUÉ ANOTAS LOS MONTOS?',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: t.textoMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final m in MonedaCuaderno.values) ...[
                    Expanded(
                      child: _TarjetaMoneda(
                        moneda: m,
                        elegida: _moneda == m,
                        onTap: () => setState(() => _moneda = m),
                      ),
                    ),
                    if (m != MonedaCuaderno.values.last)
                      const SizedBox(width: 10),
                  ],
                ],
              ),
              if (faltaTasa)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: _Aviso(
                    texto: 'Todavía no tenemos la tasa del día, y sin ella no '
                        'podemos pasar bolívares a dólares. Conéctate un '
                        'momento o anota las deudas en dólares.',
                  ),
                ),

              const SizedBox(height: 18),

              // --- Paso 2: la foto ---
              Opacity(
                opacity: moneda == null ? 0.45 : 1,
                child: IgnorePointer(
                  ignoring: moneda == null,
                  child: _FilaOpcion(
                    icono: Icons.photo_camera_outlined,
                    titulo: '2 · Foto de la página',
                    detalle: _leyendo
                        ? 'Leyendo tu cuaderno…'
                        : moneda == null
                            ? 'Elige primero la moneda'
                            : 'Una página a la vez, con buena luz',
                    cargando: _leyendo,
                    onTap: _leyendo ? null : _elegirFuente,
                  ),
                ),
              ),

              if (_filas.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Aviso(
                  texto: 'Las deudas tachadas ya pagadas no se copian. Si ves '
                      'alguna aquí, quítala antes de guardar.',
                ),
                _TablaRevision(
                  filas: _filas,
                  moneda: moneda!,
                  tasa: tasa,
                  yaTienenCuenta: _yaTienenCuenta,
                  onCambio: (nuevas) => setState(() => _filas = nuevas),
                ),
                const SizedBox(height: 16),
                LibretaButton(
                  label: _guardando
                      ? 'Anotando…'
                      : 'Anotar ${listas.length} '
                          '${listas.length == 1 ? "deuda" : "deudas"}',
                  loading: _guardando,
                  onPressed:
                      _guardando || listas.isEmpty || faltaTasa ? null : _importar,
                ),
                if (listas.length < _filas.length)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_filas.length - listas.length} sin monto se quedan '
                      'fuera. Escríbelo arriba para incluirlas.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LibretaColors.aviso,
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

/// Tarjeta de moneda del paso 1.
class _TarjetaMoneda extends StatelessWidget {
  const _TarjetaMoneda({
    required this.moneda,
    required this.elegida,
    required this.onTap,
  });

  final MonedaCuaderno moneda;
  final bool elegida;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: elegida,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: elegida
                  ? LibretaColors.verde.withValues(alpha: .10)
                  : t.superficie,
              border: Border.all(
                color: elegida ? LibretaColors.verde : t.bordeSuave,
                width: elegida ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moneda.etiqueta,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: elegida ? LibretaColors.verde : t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  moneda.ejemplo,
                  style: TextStyle(fontSize: 11.5, color: t.textoMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tabla de revisión: nada se guarda sin pasar por aquí.
class _TablaRevision extends StatelessWidget {
  const _TablaRevision({
    required this.filas,
    required this.moneda,
    required this.tasa,
    required this.yaTienenCuenta,
    required this.onCambio,
  });

  final List<FiadoLeido> filas;
  final MonedaCuaderno moneda;
  final double? tasa;
  final Set<String> yaTienenCuenta;
  final ValueChanged<List<FiadoLeido>> onCambio;

  void _editar(
    int i, {
    String? nombre,
    double? monto,
    bool sinMonto = false,
    bool quitar = false,
  }) {
    final copia = [...filas];
    if (quitar) {
      copia.removeAt(i);
    } else {
      copia[i] = copia[i].copyWith(
        nombre: nombre,
        montoEscrito: monto,
        sinMonto: sinMonto,
      );
    }
    onCambio(copia);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final dudosas = filas.where((f) => f.dudoso).length;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3 · REVISA ANTES DE ANOTAR',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: t.textoMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            dudosas == 0
                ? '${filas.length} ${filas.length == 1 ? "deuda leída" : "deudas leídas"}'
                : '${filas.length} leídas · $dudosas por revisar',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: dudosas == 0 ? t.textoMuted : LibretaColors.aviso,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < filas.length; i++)
            _RenglonRevision(
              key: ValueKey(filas[i].idLocal),
              fila: filas[i],
              moneda: moneda,
              tasa: tasa,
              yaTeniaCuenta:
                  yaTienenCuenta.contains(filas[i].nombre.toLowerCase().trim()),
              onNombre: (v) => _editar(i, nombre: v),
              onMonto: (v) => _editar(i, monto: v, sinMonto: v == null),
              onQuitar: () => _editar(i, quitar: true),
            ),
        ],
      ),
    );
  }
}

class _RenglonRevision extends StatefulWidget {
  const _RenglonRevision({
    super.key,
    required this.fila,
    required this.moneda,
    required this.tasa,
    required this.yaTeniaCuenta,
    required this.onNombre,
    required this.onMonto,
    required this.onQuitar,
  });

  final FiadoLeido fila;
  final MonedaCuaderno moneda;
  final double? tasa;
  final bool yaTeniaCuenta;
  final ValueChanged<String> onNombre;
  final ValueChanged<double?> onMonto;
  final VoidCallback onQuitar;

  @override
  State<_RenglonRevision> createState() => _RenglonRevisionState();
}

class _RenglonRevisionState extends State<_RenglonRevision> {
  late final _nombre = TextEditingController(text: widget.fila.nombre);
  late final _monto = TextEditingController(
    text: widget.fila.montoEscrito == null
        ? ''
        : widget.fila.montoEscrito!
            .toStringAsFixed(widget.moneda == MonedaCuaderno.bs ? 0 : 2),
  );

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final f = widget.fila;
    final usd = f.montoUSD(moneda: widget.moneda, tasa: widget.tasa);
    final faltaMonto = f.montoEscrito == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: f.dudoso
            ? LibretaColors.aviso.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border.all(color: f.dudoso ? LibretaColors.aviso : t.renglon),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LibretaInput(
                  controller: _nombre,
                  label: 'Cliente',
                  hint: 'Nombre',
                  height: 42,
                  onChanged: widget.onNombre,
                ),
              ),
              Semantics(
                button: true,
                label: 'Quitar a ${f.nombre}',
                child: GestureDetector(
                  onTap: widget.onQuitar,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Icon(Icons.close, size: 18),
                  ),
                ),
              ),
            ],
          ),
          // Lo que se llevó, tal como lo leyó la IA. No se edita: está aquí
          // para que el dueño reconozca el bloque en su cuaderno. Con una
          // página escrita por bloques —el nombre arriba, las prendas debajo,
          // un monto a la derecha— «Rosa E. · $3» a secas no se puede
          // contrastar con nada; «1 suéter, 1 pantalón» sí.
          if ((f.concepto ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                f.concepto!.trim(),
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: t.textoMuted,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: LibretaInput(
                  controller: _monto,
                  label: widget.moneda == MonedaCuaderno.bs
                      ? 'Debe (Bs)'
                      : 'Debe (USD)',
                  hint: faltaMonto ? 'no se leyó' : '0',
                  height: 42,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) => widget.onMonto(normalizarPositivoVE(v)),
                ),
              ),
              const SizedBox(width: 10),
              // El equivalente en dólares se enseña siempre que el cuaderno
              // esté en bolívares: es la cifra que va a quedar guardada, y
              // verla ahora es la única oportunidad de cazar un cero de más.
              if (widget.moneda == MonedaCuaderno.bs)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Text(
                      usd == null ? '—' : 'Son ${MoneyFormatter.usd(usd)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: usd == null ? t.textoMuted : t.textoFuerte,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (widget.yaTeniaCuenta)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Ya tiene cuenta abierta: esto se le SUMA a lo que ya debe.',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: LibretaColors.aviso,
                ),
              ),
            ),
          if (f.confianzaNombre == Confianza.baja ||
              f.confianzaMonto == Confianza.baja)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Letra difícil de leer, compáralo con tu cuaderno.',
                style: TextStyle(fontSize: 11.5, color: t.textoMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Franja ámbar de aviso.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LibretaColors.aviso.withValues(alpha: 0.12),
        border: Border.all(color: LibretaColors.aviso),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 17, color: LibretaColors.aviso),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: context.libreta.textoFuerte,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir cámara o galería.
class _HojaFuente extends StatelessWidget {
  const _HojaFuente();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: LibretaIcono(AppAssets.accCamara, color: t.textoFuerte),
              title: Text(
                'Cámara',
                style: TextStyle(
                  color: t.textoFuerte,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: t.textoFuerte),
              title: Text(
                'Galería',
                style: TextStyle(
                  color: t.textoFuerte,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila-tarjeta de una acción, como en Importar inventario.
class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.cargando = false,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final bool cargando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.bordeSuave),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LibretaColors.verde.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icono, size: 22, color: LibretaColors.verde),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: t.textoFuerte,
                    ),
                  ),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.textoMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (cargando)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else
              Icon(Icons.chevron_right, size: 18, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}
