import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/impresora/impresora_service.dart';
import '../../../services/impresora/ticket_esc_pos.dart';
import '../../../shared/presentation/neu.dart';
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
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: seleccionada ? t.tint : t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: seleccionada ? AppColors.marca : t.border,
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
                color: seleccionada ? AppColors.marca : Colors.transparent,
                border: Border.all(
                  color: seleccionada ? AppColors.marca : t.border,
                  width: 2,
                ),
              ),
              child: seleccionada
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
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
                      color: t.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 12, color: t.textSec),
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
    final t = context.tokens;
    return NeuCard(
      small: true,
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.text,
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
                    decoration: BoxDecoration(
                      color: t.tint,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.marca,
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
                        color: t.textSec,
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

/// Configuración de la impresora de tickets.
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

  Future<void> _buscarBluetooth() async {
    setState(() => _buscando = true);
    try {
      final lista = await ref.read(impresoraServiceProvider).bluetoothEmparejadas();
      if (mounted) setState(() => _emparejadas = lista);
      if (mounted && lista.isEmpty) {
        _mostrar(
          'No hay impresoras emparejadas. Empareja la tuya desde los ajustes '
          'de Bluetooth del teléfono y vuelve aquí.',
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
                  'Impresora de tickets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: t.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Para darle recibo impreso a tus clientes',
              style: TextStyle(fontSize: 13, color: t.textSec),
            ),
            const SizedBox(height: 18),

            Text(
              '¿Cómo se conecta tu impresora?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.text,
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
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Número de la impresora',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'El que salió en la hoja que imprimió',
                      style: TextStyle(fontSize: 11.5, color: t.textSec),
                    ),
                    const SizedBox(height: 10),
                    NeuInput(
                      controller: _ip,
                      hint: '192.168.1.87',
                      height: 46,
                      radius: 14,
                      fillWithPageBg: true,
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
              NeuButton(
                label: _buscando ? 'Buscando…' : 'Ver mis impresoras',
                height: 48,
                onPressed: _buscando ? null : _buscarBluetooth,
              ),
              const SizedBox(height: 12),
              if (_config.macBluetooth.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Seleccionada: ${_config.nombreBluetooth}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.marca,
                    ),
                  ),
                ),
              for (final bt in _emparejadas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeuCard(
                    small: true,
                    radius: 16,
                    onTap: () => _guardar(_config.copyWith(
                      macBluetooth: bt.macAdress,
                      nombreBluetooth: bt.name,
                    )),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, size: 20, color: t.textSec),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            bt.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: t.text,
                            ),
                          ),
                        ),
                        if (_config.macBluetooth == bt.macAdress)
                          const Icon(
                            Icons.check_circle,
                            size: 20,
                            color: AppColors.marca,
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
            ],

            // --- Tamaño de papel ---
            if (_config.tipo != TipoImpresora.ninguna) ...[
              NeuCard(
                small: true,
                radius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
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
                              color: t.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _config.papel80mm
                                ? 'Rollo grande, de mostrador (80 mm)'
                                : 'Rollo pequeño, el más común (58 mm)',
                            style: TextStyle(fontSize: 11.5, color: t.textSec),
                          ),
                        ],
                      ),
                    ),
                    NeuToggle(
                      value: _config.papel80mm,
                      onChanged: (v) =>
                          _guardar(_config.copyWith(papel80mm: v)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              NeuButton(
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
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
