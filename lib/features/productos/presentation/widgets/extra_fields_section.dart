import 'package:flutter/material.dart';

import '../../../../core/business/business_profile.dart';
import '../../../../core/theme/app_assets.dart';
import '../../../../shared/presentation/libreta/libreta.dart';

/// Pinta los campos propios del rubro a partir de `BusinessProfile.extraFields`.
///
/// **Es la única fuente de qué campos extra muestra el formulario de producto**
/// (`CLAUDE.md` §8.b). Itera la lista: no hay un `if` por rubro aquí dentro ni
/// lo puede haber. Agregar un campo a un rubro es agregar un [ExtraField] a su
/// preset, sin tocar este archivo.
///
/// Los valores viven en un mapa `clave → valor` que maneja el formulario, y
/// terminan en `producto.extras`. La única clave con trato aparte es
/// `vencimiento`, que tiene columna propia en el documento desde antes de que
/// existiera esta sección; el puente lo hace quien guarda, no este widget.
class ExtraFieldsSection extends StatefulWidget {
  const ExtraFieldsSection({
    super.key,
    required this.campos,
    required this.valores,
    required this.onCambio,
  });

  final List<ExtraField> campos;

  /// Valores actuales, por [ExtraField.key].
  final Map<String, dynamic> valores;

  final void Function(String clave, dynamic valor) onCambio;

  @override
  State<ExtraFieldsSection> createState() => _ExtraFieldsSectionState();
}

class _ExtraFieldsSectionState extends State<ExtraFieldsSection> {
  /// Un controlador por campo de texto/número. Se crean una vez y se liberan
  /// al salir: reconstruirlos en cada `build` le movería el cursor al usuario.
  final _controles = <String, TextEditingController>{};

  TextEditingController _controlador(ExtraField campo) => _controles.putIfAbsent(
    campo.key,
    () => TextEditingController(text: widget.valores[campo.key]?.toString() ?? ''),
  );

  @override
  void dispose() {
    for (final c in _controles.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFecha(ExtraField campo) async {
    final actual = widget.valores[campo.key];
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: actual is DateTime ? actual : hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 10),
    );
    if (fecha != null) widget.onCambio(campo.key, fecha);
  }

  /// Valor libre de un `select` con [ExtraField.allowsCustom]: las tallas no
  /// se acaban en XXL y hay negocios que manejan 38, 40 o "Talla única".
  Future<void> _pedirValorLibre(ExtraField campo) async {
    final control = TextEditingController();
    final valor = await showDialog<String>(
      context: context,
      builder:
          (d) => AlertDialog(
            title: Text(campo.label),
            content: LibretaInput(controller: control, hint: 'Escríbela'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(d).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(d).pop(control.text.trim()),
                child: const Text('Usar'),
              ),
            ],
          ),
    );
    control.dispose();
    if (valor != null && valor.isNotEmpty) widget.onCambio(campo.key, valor);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.campos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final campo in widget.campos) ...[
          const SizedBox(height: 18),
          _Campo(campo: campo, hijo: _widgetDe(campo)),
        ],
      ],
    );
  }

  Widget _widgetDe(ExtraField campo) => switch (campo.type) {
    ExtraFieldType.text => LibretaInput(
      controller: _controlador(campo),
      hint: campo.label,
      onChanged: (v) => widget.onCambio(campo.key, v.trim()),
    ),
    ExtraFieldType.number => LibretaInput(
      controller: _controlador(campo),
      hint: campo.suffix == null ? '0' : '0 ${campo.suffix}',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged:
          (v) => widget.onCambio(campo.key, double.tryParse(v.replaceAll(',', '.'))),
    ),
    ExtraFieldType.date => _BotonFecha(
      valor: widget.valores[campo.key],
      onPressed: () => _elegirFecha(campo),
    ),
    ExtraFieldType.select => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final opcion in campo.options ?? const <String>[])
          LibretaChip(
            label: opcion,
            selected: widget.valores[campo.key] == opcion,
            onTap: () => widget.onCambio(campo.key, opcion),
          ),
        if (campo.allowsCustom) ...[
          // Si el valor guardado no está entre las opciones, es uno libre: se
          // muestra como una pastilla más para que se vea seleccionado.
          if (widget.valores[campo.key] is String &&
              !(campo.options ?? const <String>[])
                  .contains(widget.valores[campo.key]))
            LibretaChip(
              label: widget.valores[campo.key] as String,
              selected: true,
              onTap: () => _pedirValorLibre(campo),
            ),
          LibretaChip(
            label: 'Otra…',
            selected: false,
            onTap: () => _pedirValorLibre(campo),
          ),
        ],
      ],
    ),
  };
}

/// Etiqueta + control, con el mismo ritmo que el resto del formulario.
class _Campo extends StatelessWidget {
  const _Campo({required this.campo, required this.hijo});

  final ExtraField campo;
  final Widget hijo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          campo.required ? campo.label : '${campo.label} (opcional)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.libreta.textoMuted,
          ),
        ),
        const SizedBox(height: 6),
        hijo,
      ],
    );
  }
}

class _BotonFecha extends StatelessWidget {
  const _BotonFecha({required this.valor, required this.onPressed});

  final Object? valor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fecha = valor is DateTime ? valor as DateTime : null;
    return Align(
      alignment: Alignment.centerLeft,
      child: LibretaSecondaryButton(
        label:
            fecha == null
                ? 'Elegir fecha'
                : '${fecha.day}/${fecha.month}/${fecha.year}',
        icon: const LibretaIcono(AppAssets.accCalendario, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
