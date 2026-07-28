/// Códigos de banco de Venezuela (SUDEBAN), usados para pago móvil y
/// transferencias. Lista estática según el Lote E · P7 del diseño.
class BancoVenezuela {
  const BancoVenezuela({required this.codigo, required this.nombre});

  final String codigo;
  final String nombre;

  static const List<BancoVenezuela> todos = [
    BancoVenezuela(codigo: '0102', nombre: 'Banco de Venezuela'),
    BancoVenezuela(codigo: '0104', nombre: 'Venezolano de Crédito'),
    BancoVenezuela(codigo: '0105', nombre: 'Banco Mercantil'),
    BancoVenezuela(codigo: '0108', nombre: 'Banco Provincial'),
    BancoVenezuela(codigo: '0114', nombre: 'Bancaribe'),
    BancoVenezuela(codigo: '0115', nombre: 'Banco Exterior'),
    BancoVenezuela(codigo: '0116', nombre: 'Banco Occidental de Descuento'),
    BancoVenezuela(codigo: '0128', nombre: 'Banco Caroní'),
    BancoVenezuela(codigo: '0134', nombre: 'Banesco'),
    BancoVenezuela(codigo: '0137', nombre: 'Banco Sofitasa'),
    BancoVenezuela(codigo: '0138', nombre: 'Banco Plaza'),
    BancoVenezuela(codigo: '0146', nombre: 'Banco de la Gente Emprendedora'),
    BancoVenezuela(codigo: '0149', nombre: 'Banco del Pueblo Soberano'),
    BancoVenezuela(codigo: '0151', nombre: 'BFC Banco Fondo Común'),
    BancoVenezuela(codigo: '0157', nombre: 'DelSur'),
    BancoVenezuela(codigo: '0163', nombre: 'Banco del Tesoro'),
    BancoVenezuela(codigo: '0166', nombre: 'Banco Agrícola de Venezuela'),
    BancoVenezuela(codigo: '0168', nombre: 'Bancrecer'),
    BancoVenezuela(codigo: '0169', nombre: 'Mi Banco'),
    BancoVenezuela(codigo: '0171', nombre: 'Banco Activo'),
    BancoVenezuela(codigo: '0172', nombre: 'Bancamiga'),
    BancoVenezuela(codigo: '0173', nombre: 'Banco Internacional de Desarrollo'),
    BancoVenezuela(codigo: '0174', nombre: 'Banplus'),
    BancoVenezuela(codigo: '0175', nombre: 'Banco Nacional de Crédito'),
    BancoVenezuela(codigo: '0176', nombre: '100% Banco'),
    BancoVenezuela(codigo: '0190', nombre: 'Instituto Municipal de Crédito Popular'),
  ];
}
