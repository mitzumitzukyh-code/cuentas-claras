import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un dispositivo emparejado tal como lo reporta Android, con su clase.
class _DispositivoBt {
  const _DispositivoBt({
    required this.nombre,
    required this.mac,
    required this.claseMayor,
  });

  factory _DispositivoBt.desdeMapa(Map<Object?, Object?> m) => _DispositivoBt(
    nombre: (m['nombre'] as String?) ?? '',
    mac: (m['mac'] as String?) ?? '',
    claseMayor: (m['claseMayor'] as int?) ?? 0,
  );

  final String nombre;
  final String mac;

  /// Clase mayor de Android (`BluetoothClass.Device.Major`).
  final int claseMayor;

  /// Clases que SÍ pueden ser una impresora térmica.
  ///
  /// Se filtra por lista blanca corta en vez de excluir solo el audio: las
  /// térmicas baratas se anuncian como `imaging` (lo correcto), pero muchas
  /// se declaran `uncategorized` o `misc` porque el fabricante no rellenó el
  /// campo. Lo que nunca es una impresora —audio, teléfonos, computadoras,
  /// teclados, relojes— queda fuera.
  static const _clasesDeImpresora = {
    0x0000, // misc
    0x0600, // imaging (impresoras, escáneres)
    0x1F00, // uncategorized
  };

  bool get esImpresora => _clasesDeImpresora.contains(claseMayor);
}

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
    this.imprimirLogo = true,
    this.imprimirAlCobrar = false,
  });

  final TipoImpresora tipo;
  final String ip;
  final int puerto;
  final String macBluetooth;
  final String nombreBluetooth;

  /// `false` = rollo de 58 mm, el más común en las térmicas económicas.
  final bool papel80mm;

  /// Encabezar el ticket con el logo del negocio.
  final bool imprimirLogo;

  /// Sacar el ticket solo, en cuanto se registra la venta. Apagado por
  /// defecto: en una bodega la mayoría de los clientes no lo pide, y gastar
  /// rollo en cada venta es plata.
  final bool imprimirAlCobrar;

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
    bool? imprimirLogo,
    bool? imprimirAlCobrar,
  }) {
    return ImpresoraConfig(
      tipo: tipo ?? this.tipo,
      ip: ip ?? this.ip,
      puerto: puerto ?? this.puerto,
      macBluetooth: macBluetooth ?? this.macBluetooth,
      nombreBluetooth: nombreBluetooth ?? this.nombreBluetooth,
      papel80mm: papel80mm ?? this.papel80mm,
      imprimirLogo: imprimirLogo ?? this.imprimirLogo,
      imprimirAlCobrar: imprimirAlCobrar ?? this.imprimirAlCobrar,
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
  static const _kLogo = 'impresora_logo';
  static const _kAuto = 'impresora_auto';

  Future<ImpresoraConfig> cargar() async {
    final p = await SharedPreferences.getInstance();
    return ImpresoraConfig(
      tipo: TipoImpresora.fromId(p.getString(_kTipo)),
      ip: p.getString(_kIp) ?? '',
      puerto: p.getInt(_kPuerto) ?? 9100,
      macBluetooth: p.getString(_kMac) ?? '',
      nombreBluetooth: p.getString(_kNombre) ?? '',
      papel80mm: p.getBool(_kPapel) ?? false,
      imprimirLogo: p.getBool(_kLogo) ?? true,
      imprimirAlCobrar: p.getBool(_kAuto) ?? false,
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
    await p.setBool(_kLogo, config.imprimirLogo);
    await p.setBool(_kAuto, config.imprimirAlCobrar);
  }

  /// Impresoras Bluetooth ya emparejadas en los ajustes del teléfono.
  ///
  /// No se escanean dispositivos nuevos a propósito: emparejar se hace una vez
  /// desde Android, y así evitamos pedir permisos de ubicación.
  ///
  /// [todos] salta el filtro por clase, para el caso raro de una impresora que
  /// se anuncia con una clase inesperada. Ver [_esImpresora].
  Future<List<BluetoothInfo>> bluetoothEmparejadas({bool todos = false}) async {
    await _pedirPermiso();

    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const ImpresoraException(
        'El Bluetooth de tu teléfono está apagado. Enciéndelo y vuelve a '
        'intentar.',
      );
    }

    // El plugin no expone la clase de dispositivo (`BluetoothInfo` solo trae
    // nombre y MAC), así que la lista se pide por el canal nativo para poder
    // dejar fuera lo que no es una impresora. Si el canal falla —iOS, o una
    // versión vieja del APK— se cae a la lista sin filtrar del plugin: es
    // preferible mostrar de más que dejar al dueño sin poder elegir nada.
    try {
      final crudo = await _canal.invokeListMethod<Map<Object?, Object?>>(
        'emparejados',
      );
      if (crudo != null) {
        final dispositivos = crudo.map(_DispositivoBt.desdeMapa).toList();
        final utiles =
            todos
                ? dispositivos
                : dispositivos.where((d) => d.esImpresora).toList();
        return [
          for (final d in utiles)
            BluetoothInfo(name: d.nombre, macAdress: d.mac),
        ];
      }
    } on PlatformException {
      // Sin canal nativo: se sigue con la lista del plugin.
    } on MissingPluginException {
      // Idem (iOS).
    }

    return PrintBluetoothThermal.pairedBluetooths;
  }

  static const _canal = MethodChannel('cuentaclara/bluetooth');

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
