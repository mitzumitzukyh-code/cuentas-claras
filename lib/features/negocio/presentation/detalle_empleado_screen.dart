import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/presentation/libreta/libreta.dart';
import '../data/negocio_repository.dart';
import '../domain/membresia.dart';

/// Pantalla de detalle de un empleado con permisos granularizados.
/// Lote E · P2 del diseño.
class DetalleEmpleadoScreen extends ConsumerStatefulWidget {
  const DetalleEmpleadoScreen({super.key, required this.membresia});

  final Membresia membresia;

  @override
  ConsumerState<DetalleEmpleadoScreen> createState() =>
      _DetalleEmpleadoScreenState();
}

class _DetalleEmpleadoScreenState
    extends ConsumerState<DetalleEmpleadoScreen> {
  late Map<String, bool> _permisos;

  static const _etiquetas = {
    'cobrar': 'Cobrar',
    'verReportes': 'Ver reportes',
    'editarInventario': 'Editar inventario',
    'registrarGastos': 'Registrar gastos',
    'cerrarCaja': 'Cerrar caja',
    'gestionarEmpleados': 'Gestionar empleados',
  };

  static const _descripciones = {
    'cobrar': 'Puede registrar ventas en el punto de venta',
    'verReportes': 'Accede a reportes financieros del negocio',
    'editarInventario': 'Agrega, edita y elimina productos',
    'registrarGastos': 'Registra gastos del negocio',
    'cerrarCaja': 'Realiza el cierre de caja del día',
    'gestionarEmpleados': 'Invita, cambia roles y quita miembros',
  };

  @override
  void initState() {
    super.initState();
    _permisos = Map.from(widget.membresia.permisosEfectivos);
  }

  Future<void> _guardarPermisos() async {
    if (widget.membresia.permisosEfectivos == _permisos) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await ref
          .read(negocioRepositoryProvider)
          .guardarPermisos(widget.membresia.id, _permisos);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permisos guardados ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron guardar los permisos: $e'),
          backgroundColor: LibretaColors.peligro,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final esDueno = widget.membresia.rol.esDueno;

    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                child: Row(
                  children: [
                    LibretaBackButton(
                      oscuro: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.membresia.nombreVisible,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.libreta.textoFuerte,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.libreta.renglon),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1F0E9F6E),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: LibretaColors.verde,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              widget.membresia.rol.etiqueta,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              esDueno
                                  ? 'Tiene acceso completo al negocio.'
                                  : 'Elige qué puede hacer este vendedor.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: LibretaColors.verde,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (esDueno)
                      ...permisosDueno.entries.map(
                        (e) => _filaPermiso(
                          clave: e.key,
                          activo: true,
                          habilitado: false,
                        ),
                      )
                    else
                      ..._etiquetas.entries.map(
                        (e) => _filaPermiso(
                          clave: e.key,
                          activo: _permisos[e.key] ?? false,
                          habilitado: true,
                          onChanged: (v) {
                            setState(() => _permisos[e.key] = v);
                          },
                        ),
                      ),
                  ],
                ),
              ),
              if (!esDueno)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: LibretaButton(
                    label: 'Guardar permisos',
                    onPressed: _guardarPermisos,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaPermiso({
    required String clave,
    required bool activo,
    required bool habilitado,
    void Function(bool)? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: context.libreta.superficie,
        border: Border.all(color: const Color(0x141E2A38)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(
          _etiquetas[clave] ?? clave,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.libreta.textoFuerte,
          ),
        ),
        subtitle: Text(
          _descripciones[clave] ?? '',
          style: TextStyle(fontSize: 12, color: context.libreta.textoMuted),
        ),
        value: activo,
        activeColor: LibretaColors.verde,
        onChanged: habilitado ? onChanged : null,
      ),
    );
  }
}
