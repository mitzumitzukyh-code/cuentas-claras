/// Bancos de Venezuela con su código SUDEBAN, para pago móvil y
/// transferencias (`Lote E · P7`).
///
/// Lista estática y literal del diseño: no viene de la red porque no cambia
/// casi nunca y el dueño necesita poder elegir su banco sin señal.
class BancoVenezuela {
  const BancoVenezuela({required this.codigo, required this.nombre});

  final String codigo;

  /// En mayúsculas, como los muestra el diseño y como aparecen en las apps de
  /// banca del país — así el dueño reconoce el suyo de un vistazo.
  final String nombre;

  /// "0102 - BANCO DE VENEZUELA"
  String get etiqueta => '$codigo - $nombre';

  /// Alfabéticos por nombre, igual que el lote.
  static const List<BancoVenezuela> todos = [
    BancoVenezuela(codigo: '0156', nombre: '100% BANCO'),
    BancoVenezuela(codigo: '0172', nombre: 'BANCAMIGA BANCO UNIVERSAL, C.A.'),
    BancoVenezuela(codigo: '0114', nombre: 'BANCARIBE'),
    BancoVenezuela(codigo: '0171', nombre: 'BANCO ACTIVO'),
    BancoVenezuela(codigo: '0128', nombre: 'BANCO CARONÍ'),
    BancoVenezuela(codigo: '0163', nombre: 'BANCO DEL TESORO'),
    BancoVenezuela(
      codigo: '0175',
      nombre: 'BANCO DIGITAL DE LOS TRABAJADORES, BANCO UNIVERSAL',
    ),
    BancoVenezuela(codigo: '0115', nombre: 'BANCO EXTERIOR'),
    BancoVenezuela(codigo: '0151', nombre: 'BANCO FONDO COMÚN'),
    BancoVenezuela(codigo: '0105', nombre: 'BANCO MERCANTIL'),
    BancoVenezuela(codigo: '0191', nombre: 'BANCO NACIONAL DE CREDITO'),
    BancoVenezuela(codigo: '0138', nombre: 'BANCO PLAZA'),
    BancoVenezuela(codigo: '0137', nombre: 'BANCO SOFITASA'),
    BancoVenezuela(codigo: '0102', nombre: 'BANCO DE VENEZUELA'),
    BancoVenezuela(codigo: '0104', nombre: 'BANCO VENEZOLANO DE CREDITO'),
    BancoVenezuela(codigo: '0168', nombre: 'BANCRECER'),
    BancoVenezuela(codigo: '0134', nombre: 'BANESCO'),
    BancoVenezuela(codigo: '0177', nombre: 'BANFANB'),
    BancoVenezuela(codigo: '0146', nombre: 'BANGENTE'),
    BancoVenezuela(codigo: '0174', nombre: 'BANPLUS'),
    BancoVenezuela(codigo: '0108', nombre: 'BBVA PROVINCIAL'),
    BancoVenezuela(codigo: '0157', nombre: 'DELSUR BANCO UNIVERSAL'),
    BancoVenezuela(
      codigo: '0601',
      nombre: 'INSTITUTO MUNICIPAL DE CREDITO POPULAR',
    ),
    BancoVenezuela(
      codigo: '0178',
      nombre: 'N58 BANCO DIGITAL BANCO MICROFINANCIERO S A',
    ),
    BancoVenezuela(codigo: '0169', nombre: 'R4 BANCO MICROFINANCIERO C.A.'),
  ];

  static BancoVenezuela? porCodigo(String? codigo) {
    if (codigo == null || codigo.isEmpty) return null;
    for (final b in todos) {
      if (b.codigo == codigo) return b;
    }
    return null;
  }
}
