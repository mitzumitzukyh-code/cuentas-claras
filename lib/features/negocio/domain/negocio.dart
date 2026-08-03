import 'package:cloud_firestore/cloud_firestore.dart';

import '../../onboarding/domain/rubro.dart';
import '../../ventas/domain/venta.dart' show MetodoPago;
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
    this.haceDelivery = false,
    this.fotoUrl,
    this.fotoComoFondo = false,
    this.bancoCodigo,
    this.bancoNombre,
    this.metodosPago = const [],
    this.creadoPor,
  });

  final String id;
  final String nombre;
  /// El rubro es la única fuente del perfil de negocio: `businessPresets` tiene
  /// una entrada por rubro. No hay un segundo campo que mantener sincronizado.
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

  /// `true` si el negocio hace delivery. Se anuncia en el Estado.
  final bool haceDelivery;

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

  /// Teléfono que se muestra al cliente en el catálogo y en el Estado.
  ///
  /// Se toma del Pago Móvil ya cargado en Métodos de pago: pedirlo aparte en
  /// Ajustes era duplicar un dato que el dueño ya tenía que llenar para
  /// cobrar. Si no activó Pago Móvil, no hay teléfono que mostrar.
  String? get telefonoParaCliente {
    final pagoMovil = metodosActivos
        .where((m) => m.metodo == MetodoPago.pagoMovil)
        .firstOrNull;
    final telefono = pagoMovil?.telefonoAsociado?.trim();
    return (telefono == null || telefono.isEmpty) ? null : telefono;
  }

  /// IVA venezolano, fijo en 16 % (CLAUDE.md §6).
  static const double tasaIva = 0.16;

  factory Negocio.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final rubro = Rubro.fromId(data['rubro'] as String?);
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
      haceDelivery: (data['haceDelivery'] as bool?) ?? false,
      bancoCodigo: data['bancoCodigo'] as String?,
      bancoNombre: data['bancoNombre'] as String?,
      fotoUrl: data['fotoUrl'] as String?,
      fotoComoFondo: (data['fotoComoFondo'] as bool?) ?? false,
      creadoPor: data['creadoPor'] as String?,
      metodosPago: MetodoPagoConfig.listaDesdeMapa(
        data['metodosPago'] as Map<String, dynamic>?,
      ),
      // `configuracion` NO se lee del documento: sale entera del preset del
      // rubro. Antes se mezclaban las dos fuentes —tres banderas del doc y el
      // resto del preset— y el doc siempre perdía en cuanto el preset cambiaba,
      // así que la mezcla solo servía para hacer creer que el negocio guardaba
      // una configuración propia. Lo que sí es editable por el usuario es
      // `perfilNegocio`, y eso vive en su propio campo.
      configuracion: rubro.config,
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
    'haceDelivery': haceDelivery,
    'bancoCodigo': bancoCodigo,
    'bancoNombre': bancoNombre,
    'fotoUrl': fotoUrl,
    'fotoComoFondo': fotoComoFondo,
    'creadoPor': creadoPor,
    'metodosPago': MetodoPagoConfig.listaAMapa(metodosPago),
  };
}
