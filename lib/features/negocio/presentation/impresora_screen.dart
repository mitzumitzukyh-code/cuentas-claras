import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/theme/app_assets.dart';
import '../../../services/impresora/impresora_service.dart';
import '../../../services/impresora/ticket_esc_pos.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../ventas/domain/venta.dart';
import '../data/negocio_repository.dart';

/// Opción de conexión con su explicación en lenguaje llano.
class _OpcionConexion extends StatelessWidget {
  const _OpcionConexion({
    required this.titulo,
    required this.detalle,
    required this.seleccionada,
    required this.onTap,
  });

  final String titulo;
  final String detalle;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              seleccionada
                  ? const Color(0x140E9F6E)
                  : context.libreta.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                seleccionada ? LibretaColors.verde : context.libreta.bordeSuave,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seleccionada ? LibretaColors.verde : Colors.transparent,
                border: Border.all(
                  color:
                      seleccionada
                          ? LibretaColors.verde
                          : context.libreta.bordeSuave,
                  width: 2,
                ),
              ),
              child:
                  seleccionada
                      ? const LibretaIcono(
                        AppAssets.accConfirmar,
                        size: 13,
                        color: Colors.white,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista numerada de instrucciones.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.titulo, required this.pasos});

  final String titulo;
  final List<String> pasos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.libreta.superficie,
        border: Border.all(color: const Color(0x141E2A38)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.libreta.textoFuerte,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < pasos.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == pasos.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0x1F0E9F6E),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: LibretaColors.verde,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pasos[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: context.libreta.textoMuted,
                      ),
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

/// Configuración de la impresora de tickets (réplica visual de
/// `P2 · IMPRESORA`, `Lote E · Negocio y Perfil`).
///
/// Cubre las dos formas de conectarla: por WiFi (la impresora tiene su propia
/// IP en la red del local) o por Bluetooth (emparejada con este teléfono).
class ImpresoraScreen extends ConsumerStatefulWidget {
  const ImpresoraScreen({super.key});

  @override
  ConsumerState<ImpresoraScreen> createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends ConsumerState<ImpresoraScreen> {
  final _ip = TextEditingController();

  ImpresoraConfig _config = const ImpresoraConfig();
  List<BluetoothInfo> _emparejadas = [];

  /// Ya se buscó al menos una vez (para no ofrecer "ver todos" de entrada).
  bool _busco = false;

  /// La lista actual viene sin filtrar por clase de dispositivo.
  bool _verTodos = false;
  bool _cargando = true;
  bool _buscando = false;
  bool _probando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final config = await ref.read(impresoraServiceProvider).cargar();
    if (!mounted) return;
    setState(() {
      _config = config;
      _ip.text = config.ip;
      _cargando = false;
    });
  }

  Future<void> _guardar(ImpresoraConfig nueva) async {
    setState(() => _config = nueva);
    await ref.read(impresoraServiceProvider).guardar(nueva);
    ref.invalidate(impresoraConfigProvider);
  }

  Future<void> _buscarBluetooth({bool todos = false}) async {
    setState(() => _buscando = true);
    try {
      final lista = await ref
          .read(impresoraServiceProvider)
          .bluetoothEmparejadas(todos: todos);
      if (mounted) {
        setState(() {
          _emparejadas = lista;
          _busco = true;
          _verTodos = todos;
        });
      }
      if (mounted && lista.isEmpty) {
        _mostrar(
          todos
              ? 'No tienes ningún dispositivo Bluetooth emparejado con este '
                  'teléfono.'
              : 'No encontramos ninguna impresora emparejada. Empárejala desde '
                  'los ajustes de Bluetooth del teléfono y vuelve aquí.',
        );
      }
    } on ImpresoraException catch (e) {
      _mostrar(e.mensaje);
    } catch (e) {
      _mostrar('No se pudo buscar: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  /// Imprime un ticket de ejemplo para comprobar la conexión sin gastar una
  /// venta real.
  Future<void> _probar() async {
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (negocio == null) return;

    setState(() => _probando = true);
    try {
      final ejemplo = Venta(
        id: 'PRUEBA',
        items: const [
          ItemVenta(
            productoId: '',
            nombre: 'Ticket de prueba',
            cantidad: 1,
            precioUnitario: 1,
          ),
        ],
        totalUSD: 1,
        totalBs: 0,
        tasaBcvUsada: 0,
        vendidoPor: '',
        fecha: DateTime.now(),
      );

      final bytes = await TicketEscPos.generar(
        venta: ejemplo,
        negocio: negocio,
        ancho: _config.tamanoPapel,
      );
      await ref.read(impresoraServiceProvider).imprimir(_config, bytes);
      _mostrar('Ticket enviado a la impresora');
    } on ImpresoraException catch (e) {
      _mostrar(e.mensaje);
    } catch (e) {
      _mostrar('No se pudo imprimir: $e');
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                    'Impresora',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.libreta.textoFuerte,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: 52),
                child: Text(
                  'Para darle recibo impreso a tus clientes',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.libreta.textoMuted,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                '¿Cómo se conecta tu impresora?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.libreta.textoFuerte,
                ),
              ),
              const SizedBox(height: 10),

              // --- Tipo de conexión ---
              for (final tipo in TipoImpresora.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _OpcionConexion(
                    titulo: tipo.etiqueta,
                    detalle: tipo.explicacion,
                    seleccionada: _config.tipo == tipo,
                    onTap: () => _guardar(_config.copyWith(tipo: tipo)),
                  ),
                ),
              const SizedBox(height: 14),

              // --- WiFi ---
              if (_config.tipo == TipoImpresora.wifi) ...[
                const _Pasos(
                  titulo: 'Antes de empezar',
                  pasos: [
                    'Enciende la impresora.',
                    'Si la impresora crea su propia red WiFi, conéctate a ella '
                        'desde los ajustes del teléfono. Si va conectada al WiFi '
                        'del local, asegúrate de que tu teléfono esté en ese '
                        'mismo WiFi.',
                    'Mantén pulsado el botón de avance de papel: la impresora '
                        'imprimirá una hoja con sus datos. Ahí sale un número '
                        'como 192.168.1.87.',
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: const Color(0x141E2A38)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Número de la impresora',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.libreta.textoFuerte,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'El que salió en la hoja que imprimió',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      LibretaInput(
                        controller: _ip,
                        hint: '192.168.1.87',
                        height: 46,
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _guardar(_config.copyWith(ip: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // --- Bluetooth ---
              if (_config.tipo == TipoImpresora.bluetooth) ...[
                const _Pasos(
                  titulo: 'Antes de empezar',
                  pasos: [
                    'Enciende la impresora y el Bluetooth del teléfono.',
                    'Ve a los ajustes de Bluetooth de tu teléfono y empareja la '
                        'impresora. Suele aparecer con un nombre tipo "PT-210" o '
                        '"BlueTooth Printer".',
                    'Vuelve aquí y toca el botón de abajo.',
                  ],
                ),
                const SizedBox(height: 12),
                LibretaButton(
                  label: _buscando ? 'Buscando…' : 'Ver mis impresoras',
                  height: 48,
                  onPressed: _buscando ? null : _buscarBluetooth,
                ),
                const SizedBox(height: 12),
                if (_config.macBluetooth.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seleccionada: ${_config.nombreBluetooth}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: LibretaColors.verde,
                            ),
                          ),
                        ),
                        // Sin esto, una selección equivocada se quedaba puesta
                        // para siempre: no había forma de volver a "ninguna".
                        GestureDetector(
                          onTap:
                              () => _guardar(
                                _config.copyWith(
                                  macBluetooth: '',
                                  nombreBluetooth: '',
                                ),
                              ),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Quitar',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: LibretaColors.peligro,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final bt in _emparejadas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap:
                          () => _guardar(
                            _config.copyWith(
                              macBluetooth: bt.macAdress,
                              nombreBluetooth: bt.name,
                            ),
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.libreta.superficie,
                          border: Border.all(color: const Color(0x141E2A38)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.print_outlined,
                              size: 20,
                              color: context.libreta.textoMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                bt.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.libreta.textoFuerte,
                                ),
                              ),
                            ),
                            if (_config.macBluetooth == bt.macAdress)
                              const Icon(
                                Icons.check_circle,
                                size: 20,
                                color: LibretaColors.verde,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Salida de emergencia: la lista se filtra por clase de
                // dispositivo, y una térmica que se anuncie con una clase
                // rara quedaría escondida. Solo se ofrece después de buscar,
                // para no invitar a saltarse el filtro de entrada.
                if (_busco && !_verTodos)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () => _buscarBluetooth(todos: true),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        _emparejadas.isEmpty
                            ? '¿No aparece tu impresora? Ver todos los '
                                'dispositivos emparejados'
                            : 'Ver todos los dispositivos emparejados',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: LibretaColors.verde,
                        ),
                      ),
                    ),
                  ),
                if (_verTodos)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Estás viendo todo lo emparejado con el teléfono, '
                      'incluidos audífonos y cornetas. Elige solo tu '
                      'impresora.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.libreta.textoMuted,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],

              // --- Tamaño de papel ---
              if (_config.tipo != TipoImpresora.ninguna) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: context.libreta.superficie,
                    border: Border.all(color: const Color(0x141E2A38)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uso papel ancho',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: context.libreta.textoFuerte,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _config.papel80mm
                                  ? 'Rollo grande, de mostrador (80 mm)'
                                  : 'Rollo pequeño, el más común (58 mm)',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.libreta.textoMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LibretaToggle(
                        value: _config.papel80mm,
                        onChanged:
                            (v) => _guardar(_config.copyWith(papel80mm: v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _FilaFormato(
                  titulo: 'Imprimir logo',
                  detalle: 'Encabeza el ticket con el logo del negocio',
                  valor: _config.imprimirLogo,
                  onChanged: (v) => _guardar(_config.copyWith(imprimirLogo: v)),
                ),
                const SizedBox(height: 10),
                _FilaFormato(
                  titulo: 'Imprimir automático al cobrar',
                  detalle: 'Saca el ticket solo, sin que tengas que pedirlo',
                  valor: _config.imprimirAlCobrar,
                  onChanged:
                      (v) => _guardar(_config.copyWith(imprimirAlCobrar: v)),
                ),
                const SizedBox(height: 18),
                LibretaButton(
                  label: 'Imprimir ticket de prueba',
                  loading: _probando,
                  onPressed: _config.configurada ? _probar : null,
                ),
                if (!_config.configurada) ...[
                  const SizedBox(height: 10),
                  Text(
                    _config.tipo == TipoImpresora.wifi
                        ? 'Escribe el número de la impresora para poder probar.'
                        : 'Elige tu impresora de la lista para poder probar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.libreta.textoMuted,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Una fila del bloque "Formato del ticket" (`Lote E · P2`).
class _FilaFormato extends StatelessWidget {
  const _FilaFormato({
    required this.titulo,
    required this.detalle,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String detalle;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.superficie,
        border: Border.all(color: t.renglon),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.textoFuerte,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TextStyle(fontSize: 11.5, color: t.textoMuted),
                ),
              ],
            ),
          ),
          LibretaToggle(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
