/// Validadores reutilizables para formularios (retornan `null` si es válido).
abstract final class Validators {
  const Validators._();

  static String? requerido(String? valor, {String campo = 'Este campo'}) {
    if (valor == null || valor.trim().isEmpty) return '$campo es obligatorio';
    return null;
  }

  static String? correo(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Ingresa tu correo';
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!re.hasMatch(valor.trim())) return 'Correo no válido';
    return null;
  }

  /// Teléfono venezolano en formato internacional (ej: +58 412 1234567).
  static String? telefono(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Ingresa tu teléfono';
    final limpio = valor.replaceAll(RegExp(r'[\s-]'), '');
    final re = RegExp(r'^\+?58\d{10}$|^0?4\d{9}$');
    if (!re.hasMatch(limpio)) return 'Teléfono no válido';
    return null;
  }

  static String? precio(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Ingresa el precio';
    final n = double.tryParse(valor.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Precio no válido';
    return null;
  }

  static String? cantidad(String? valor) {
    if (valor == null || valor.trim().isEmpty) return 'Ingresa la cantidad';
    final n = int.tryParse(valor);
    if (n == null || n < 0) return 'Cantidad no válida';
    return null;
  }
}
