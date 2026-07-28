import '../../ventas/domain/venta.dart';

/// Un dato que hay que pedirle al dueño para poder cobrar por ese método.
class CampoMetodoPago {
  const CampoMetodoPago({
    required this.clave,
    required this.etiqueta,
    this.ejemplo,
  });

  final String clave;
  final String etiqueta;
  final String? ejemplo;
}

/// Configuración de un método de pago dentro del negocio
/// (bloque `isMetodosPago` del diseño).
///
/// Se guarda en `negocios/{id}.metodosPago` como
/// `{ pagomovil: { activo: true, datos: {telefono: "...", ...} } }`.
class MetodoPagoConfig {
  const MetodoPagoConfig({
    required this.metodo,
    this.activo = false,
    this.datos = const {},
  });

  final MetodoPago metodo;
  final bool activo;
  final Map<String, String> datos;

  MetodoPagoConfig copyWith({bool? activo, Map<String, String>? datos}) {
    return MetodoPagoConfig(
      metodo: metodo,
      activo: activo ?? this.activo,
      datos: datos ?? this.datos,
    );
  }

  /// Campos que pide cada método. El efectivo no necesita ninguno.
  static List<CampoMetodoPago> camposDe(MetodoPago m) => switch (m) {
        MetodoPago.efectivo => const [],
        MetodoPago.pagoMovil => const [
            CampoMetodoPago(
              clave: 'telefono',
              etiqueta: 'Teléfono',
              ejemplo: '0412-1234567',
            ),
            CampoMetodoPago(clave: 'banco', etiqueta: 'Banco', ejemplo: 'Banesco'),
            CampoMetodoPago(
              clave: 'cedula',
              etiqueta: 'Cédula o RIF',
              ejemplo: 'V-12345678',
            ),
          ],
        MetodoPago.transferencia => const [
            CampoMetodoPago(
              clave: 'cuenta',
              etiqueta: 'Número de cuenta',
              ejemplo: '0102-0000-0000000000',
            ),
            CampoMetodoPago(clave: 'banco', etiqueta: 'Banco', ejemplo: 'Banesco'),
            CampoMetodoPago(
              clave: 'cedula',
              etiqueta: 'Cédula o RIF',
              ejemplo: 'V-12345678',
            ),
          ],
        MetodoPago.zelle => const [
            CampoMetodoPago(
              clave: 'correo',
              etiqueta: 'Correo',
              ejemplo: 'pagos@negocio.com',
            ),
            CampoMetodoPago(clave: 'titular', etiqueta: 'Titular'),
          ],
        // BioPago y Punto de venta se resuelven con el terminal físico: al
        // cliente solo hay que anunciarle que se aceptan, no darle datos.
        MetodoPago.biopago => const [],
        MetodoPago.puntoDeVenta => const [],
      };

  /// Código del banco (0102, 0134…) para pago móvil.
  String? get codigoBanco => datos['codigoBanco'];

  /// Teléfono asociado al banco.
  String? get telefonoAsociado => datos['telefono'];

  /// Cédula o RIF registrado.
  String? get cedulaRif => datos['cedula'];

  /// Texto listo para pegar en un recibo o mensaje de WhatsApp.
  String get resumen {
    if (datos.isEmpty) return metodo.etiqueta;
    final partes = camposDe(metodo)
        .map((c) => datos[c.clave])
        .where((v) => v != null && v.trim().isNotEmpty);
    return '${metodo.etiqueta}: ${partes.join(' · ')}';
  }

  factory MetodoPagoConfig.fromMap(MetodoPago metodo, Map<String, dynamic> map) {
    final crudos = (map['datos'] as Map?) ?? const {};
    return MetodoPagoConfig(
      metodo: metodo,
      // El efectivo viene activo por defecto: toda bodega lo acepta.
      activo: (map['activo'] as bool?) ?? (metodo == MetodoPago.efectivo),
      datos: {
        for (final e in crudos.entries)
          e.key.toString(): (e.value ?? '').toString(),
      },
    );
  }

  Map<String, dynamic> toMap() => {'activo': activo, 'datos': datos};

  /// Lee el mapa completo del negocio, rellenando los métodos que falten.
  static List<MetodoPagoConfig> listaDesdeMapa(Map<String, dynamic>? mapa) {
    return [
      for (final m in MetodoPago.values)
        MetodoPagoConfig.fromMap(
          m,
          ((mapa?[m.id]) as Map<String, dynamic>?) ?? const {},
        ),
    ];
  }

  static Map<String, dynamic> listaAMapa(List<MetodoPagoConfig> lista) => {
        for (final c in lista) c.metodo.id: c.toMap(),
      };
}
