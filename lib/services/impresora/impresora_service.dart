import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo está conectada la impresora de tickets.
enum TipoImpresora {
  ninguna,
  wifi,
  bluetooth;

  String get id => name;

  static TipoImpresora fromId(String? id) => TipoImpresora.values.firstWhere(
        (t) => t.id == id,
        orElse: () => TipoImpresora.ninguna,
      );

  String get etiqueta => switch (this) {
        TipoImpresora.ninguna => 'No uso impresora',
        TipoImpresora.wifi => 'Por WiFi',
        TipoImpresora.bluetooth => 'Por Bluetooth',
      };

  /// Explicación en lenguaje llano, para quien nunca configuró una impresora.
  String get explicacion => switch (this) {
        TipoImpresora.ninguna => 'Doy el recibo por WhatsApp o de palabra',
        TipoImpresora.wifi =>
          'La impresora se conecta al WiFi, o crea su propia red WiFi',
        TipoImpresora.bluetooth =>
          'La impresora se empareja con este teléfono, como unos audífonos',
      };
}

/// Ajustes de la impresora, guardados en el dispositivo.
///
/// No van a Firestore a propósito: la impresora es física y propia de cada
/// teléfono/local, no del negocio en la nube.
class ImpresoraConfig {
  const ImpresoraConfig({
    this.tipo = TipoImpresora.ninguna,
    this.ip = '',
    this.puerto = 9100,
    this.macBluetooth = '',
    this.nombreBluetooth = '',
    this.papel80mm = false,
  });

  final TipoImpresora tipo;
  final String ip;
  final int puerto;
  final String macBluetooth;
  final String nombreBluetooth;

  /// `false` = rollo de 58 mm, el más común en las térmicas económicas.
  final bool papel80mm;

  PaperSize get tamanoPapel => papel80mm ? PaperSize.mm80 : PaperSize.mm58;

  bool get configurada => switch (tipo) {
        TipoImpresora.ninguna => false,
        TipoImpresora.wifi => ip.trim().isNotEmpty,
        TipoImpresora.bluetooth => macBluetooth.isNotEmpty,
      };

  ImpresoraConfig copyWith({
    TipoImpresora? tipo,
    String? ip,
    int? puerto,
    String? macBluetooth,
    String? nombreBluetooth,
    bool? papel80mm,
  }) {
    return ImpresoraConfig(
      tipo: tipo ?? this.tipo,
      ip: ip ?? this.ip,
      puerto: puerto ?? this.puerto,
      macBluetooth: macBluetooth ?? this.macBluetooth,
      nombreBluetooth: nombreBluetooth ?? this.nombreBluetooth,
      papel80mm: papel80mm ?? this.papel80mm,
    );
  }
}

/// Error de impresión con un mensaje ya legible para el usuario.
class ImpresoraException implements Exception {
  const ImpresoraException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Envía los bytes ESC/POS a la impresora configurada.
class ImpresoraService {
  const ImpresoraService();

  static const _kTipo = 'impresora_tipo';
  static const _kIp = 'impresora_ip';
  static const _kPuerto = 'impresora_puerto';
  static const _kMac = 'impresora_mac';
  static const _kNombre = 'impresora_nombre';
  static const _kPapel = 'impresora_papel80';

  Future<ImpresoraConfig> cargar() async {
    final p = await SharedPreferences.getInstance();
    return ImpresoraConfig(
      tipo: TipoImpresora.fromId(p.getString(_kTipo)),
      ip: p.getString(_kIp) ?? '',
      puerto: p.getInt(_kPuerto) ?? 9100,
      macBluetooth: p.getString(_kMac) ?? '',
      nombreBluetooth: p.getString(_kNombre) ?? '',
      papel80mm: p.getBool(_kPapel) ?? false,
    );
  }

  Future<void> guardar(ImpresoraConfig config) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTipo, config.tipo.id);
    await p.setString(_kIp, config.ip.trim());
    await p.setInt(_kPuerto, config.puerto);
    await p.setString(_kMac, config.macBluetooth);
    await p.setString(_kNombre, config.nombreBluetooth);
    await p.setBool(_kPapel, config.papel80mm);
  }

  /// Impresoras Bluetooth ya emparejadas en los ajustes del teléfono.
  ///
  /// No se escanean dispositivos nuevos a propósito: emparejar se hace una vez
  /// desde Android, y así evitamos pedir permisos de ubicación.
  Future<List<BluetoothInfo>> bluetoothEmparejadas() async {
    await _pedirPermiso();

    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ImpresoraException(
        'El Bluetooth de tu teléfono está apagado. Enciéndelo y vuelve a '
        'intentar.',
      );
    }
    return PrintBluetoothThermal.pairedBluetooths;
  }

  /// En Android 12+ hay que pedir `BLUETOOTH_CONNECT` en caliente: declararlo
  /// en el manifiesto no basta. Sin él la lista de emparejadas vuelve vacía
  /// sin dar ningún error, que es justo lo que despista.
  Future<void> _pedirPermiso() async {
    if (!Platform.isAndroid) return;

    final estado = await Permission.bluetoothConnect.request();
    if (estado.isPermanentlyDenied) {
      throw const ImpresoraException(
        'Diste "No permitir" al Bluetooth. Actívalo desde los ajustes del '
        'teléfono para poder usar la impresora.',
      );
    }
    if (!estado.isGranted) {
      throw const ImpresoraException(
        'Necesitamos permiso de Bluetooth para ver tu impresora.',
      );
    }
  }

  Future<void> imprimir(ImpresoraConfig config, List<int> bytes) {
    return switch (config.tipo) {
      TipoImpresora.ninguna =>
        throw const ImpresoraException('No hay impresora configurada.'),
      TipoImpresora.wifi => _porWifi(config, bytes),
      TipoImpresora.bluetooth => _porBluetooth(config, bytes),
    };
  }

  /// Las térmicas de red escuchan ESC/POS crudo en el puerto 9100 (RAW/JetDirect).
  Future<void> _porWifi(ImpresoraConfig config, List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        config.ip.trim(),
        config.puerto,
        timeout: const Duration(seconds: 6),
      );
      socket.add(bytes);
      await socket.flush();
    } on SocketException {
      throw ImpresoraException(
        'No se pudo conectar con ${config.ip}. Revisa que la impresora esté '
        'encendida y en la misma red WiFi.',
      );
    } finally {
      await socket?.close();
    }
  }

  Future<void> _porBluetooth(ImpresoraConfig config, List<int> bytes) async {
    await _pedirPermiso();

    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ImpresoraException(
        'El Bluetooth de tu teléfono está apagado. Enciéndelo y vuelve a '
        'intentar.',
      );
    }

    final conectado = await PrintBluetoothThermal.connect(
      macPrinterAddress: config.macBluetooth,
    );
    if (!conectado) {
      throw ImpresoraException(
        'No se pudo conectar con ${config.nombreBluetooth.isEmpty ? "la "
            "impresora" : config.nombreBluetooth}. Revisa que esté encendida '
        'y emparejada.',
      );
    }

    try {
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) {
        throw const ImpresoraException('La impresora rechazó el ticket.');
      }
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }
}

final impresoraServiceProvider = Provider<ImpresoraService>((ref) {
  return const ImpresoraService();
});

/// Configuración actual de la impresora en este dispositivo.
final impresoraConfigProvider = FutureProvider<ImpresoraConfig>((ref) {
  return ref.watch(impresoraServiceProvider).cargar();
});
