import 'package:cloud_firestore/cloud_firestore.dart';

import '../../onboarding/domain/rubro.dart';
import 'metodo_pago_config.dart';

/// Un negocio del usuario (CLAUDE.md §4: `negocios/{negocioId}`).
class Negocio {
  const Negocio({
    required this.id,
    required this.nombre,
    required this.rubro,
    this.moneda = 'USD',
    this.monedaSecundaria = 'VES',
    required this.configuracion,
    this.incluirIva = false,
    this.reciboMensaje = 'Gracias por su compra',
    this.alertaStockActiva = true,
    this.metaMensualUsd = 0,
    this.proveedorWhatsapp,
    this.fotoUrl,
    this.fotoComoFondo = false,
    this.bancoCodigo,
    this.bancoNombre,
    this.metodosPago = const [],
    this.creadoPor,
  });

  final String id;
  final String nombre;
  final Rubro rubro;
  final String moneda;
  final String? monedaSecundaria;
  final RubroConfig configuracion;

  // --- Ajustes de la cuenta (pantalla `isAjustes` del diseño) ---

  /// Suma el 16 % de IVA al total de los recibos.
  final bool incluirIva;

  /// Frase que cierra el recibo.
  final String reciboMensaje;

  /// Avisar cuando un producto baje de su umbral.
  final bool alertaStockActiva;

  /// Meta de ventas del mes en USD. `0` = sin meta.
  final double metaMensualUsd;

  /// Teléfono del proveedor para pedir reabastecimiento por WhatsApp.
  final String? proveedorWhatsapp;

  /// Código SUDEBAN del banco principal (para pago móvil).
  final String? bancoCodigo;

  /// Nombre del banco principal (denormalizado para mostrar sin lookup).
  final String? bancoNombre;

  /// Logo/foto del negocio. Se muestra como avatar en Perfil y en el
  /// Dashboard.
  final String? fotoUrl;

  /// `true` = además de avatar, se usa esta misma foto de fondo en el
  /// Dashboard (con un velo encima para que el texto siga siendo legible).
  final bool fotoComoFondo;

  /// Formas de pago aceptadas y sus datos (pantalla Métodos de pago).
  final List<MetodoPagoConfig> metodosPago;

  /// UID de quien fundó el negocio.
  ///
  /// No es decorativo: las reglas de Firestore lo usan para decidir quién puede
  /// crearse a sí mismo la membresía de dueño. Sin este campo, cualquier usuario
  /// autenticado podría declararse dueño de un negocio ajeno.
  final String? creadoPor;

  /// Solo las activas, que son las que se ofrecen al cobrar.
  List<MetodoPagoConfig> get metodosActivos =>
      metodosPago.where((m) => m.activo).toList();

  /// IVA venezolano, fijo en 16 % (CLAUDE.md §6).
  static const double tasaIva = 0.16;

  factory Negocio.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rubro = Rubro.fromId(data['rubro'] as String?);
    final cfg = (data['configuracion'] as Map<String, dynamic>?) ?? const {};
    return Negocio(
      id: doc.id,
      nombre: (data['nombre'] as String?) ?? '',
      rubro: rubro,
      moneda: (data['moneda'] as String?) ?? 'USD',
      monedaSecundaria: data['monedaSecundaria'] as String?,
      incluirIva: (data['incluirIva'] as bool?) ?? false,
      reciboMensaje:
          (data['reciboMensaje'] as String?) ?? 'Gracias por su compra',
      alertaStockActiva: (data['alertaStockActiva'] as bool?) ?? true,
      metaMensualUsd: (data['metaMensualUsd'] as num?)?.toDouble() ?? 0,
      proveedorWhatsapp: data['proveedorWhatsapp'] as String?,
      bancoCodigo: data['bancoCodigo'] as String?,
      bancoNombre: data['bancoNombre'] as String?,
      fotoUrl: data['fotoUrl'] as String?,
      fotoComoFondo: (data['fotoComoFondo'] as bool?) ?? false,
      creadoPor: data['creadoPor'] as String?,
      metodosPago: MetodoPagoConfig.listaDesdeMapa(
        data['metodosPago'] as Map<String, dynamic>?,
      ),
      configuracion: RubroConfig(
        usaVariantes: (cfg['usaVariantes'] as bool?) ?? false,
        usaFechaVencimiento: (cfg['usaFechaVencimiento'] as bool?) ?? false,
        usaUnidadMedida: (cfg['usaUnidadMedida'] as bool?) ?? false,
        usaReceta: rubro.config.usaReceta,
        fotoObligatoria: rubro.config.fotoObligatoria,
        etiquetasVariante: List<String>.from(
          (cfg['etiquetasVariante'] as List?) ?? const [],
        ),
        categoriasSugeridas: rubro.config.categoriasSugeridas,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'rubro': rubro.id,
    'moneda': moneda,
    'monedaSecundaria': monedaSecundaria,
    'configuracion': configuracion.toMap(),
    'incluirIva': incluirIva,
    'reciboMensaje': reciboMensaje,
    'alertaStockActiva': alertaStockActiva,
    'metaMensualUsd': metaMensualUsd,
    'proveedorWhatsapp': proveedorWhatsapp,
    'bancoCodigo': bancoCodigo,
    'bancoNombre': bancoNombre,
    'fotoUrl': fotoUrl,
    'fotoComoFondo': fotoComoFondo,
    'creadoPor': creadoPor,
    'metodosPago': MetodoPagoConfig.listaAMapa(metodosPago),
  };
}
