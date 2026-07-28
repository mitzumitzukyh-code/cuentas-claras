import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/routes.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../services/ia/lector_etiqueta_service.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../negocio/data/negocio_repository.dart';
import '../data/producto_repository.dart';
import '../domain/producto.dart';

/// Importar inventario (réplica visual de `P1 · IMPORTAR INVENTARIO`,
/// `Lote K · Navegación`).
///
/// Reemplaza al diálogo modal que vivía en Productos: la foto de la libreta
/// y la carga manual pasan a esta pantalla propia, con la migración desde
/// otra app como acceso adicional.
class ImportarInventarioScreen extends ConsumerStatefulWidget {
  const ImportarInventarioScreen({super.key});

  @override
  ConsumerState<ImportarInventarioScreen> createState() =>
      _ImportarInventarioScreenState();
}

class _ImportarInventarioScreenState
    extends ConsumerState<ImportarInventarioScreen> {
  List<FilaLibreta> _filas = [];
  bool _leyendo = false;
  bool _guardando = false;

  Future<void> _elegirFuente() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HojaFuente(),
    );
    if (fuente == null || !mounted) return;
    await _leerFoto(fuente);
  }

  Future<void> _leerFoto(ImageSource fuente) async {
    final x = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (x == null || !mounted) return;

    setState(() => _leyendo = true);
    try {
      final filas = await ref
          .read(lectorEtiquetaServiceProvider)
          .leerLibreta(File(x.path));
      if (!mounted) return;
      setState(() {
        _filas = filas;
        _leyendo = false;
      });
      if (filas.isEmpty) _avisar('No reconocimos productos en la foto.');
    } on SinReconocer {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar('No reconocimos una lista de productos en la foto.');
    } on LimiteDiarioIA {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar('Se agotaron las lecturas con IA por hoy. Vuelve mañana.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _leyendo = false);
      _avisar('No se pudo leer la foto: $e');
    }
  }

  Future<void> _importar() async {
    final membresia = ref.read(membresiaActivaProvider);
    final negocio = ref.read(negocioActivoProvider).valueOrNull;
    if (membresia == null || negocio == null || _filas.isEmpty) return;

    setState(() => _guardando = true);
    final categoria = negocio.rubro.config.categoriasSugeridas.firstOrNull ?? '';
    final nuevos = _filas
        .map((f) => Producto(
              id: '',
              nombre: f.nombre,
              categoria: categoria,
              precio: f.precio ?? 0,
              cantidad: f.cantidad ?? 0,
              alertaEn: 5,
            ))
        .toList();

    try {
      await ref
          .read(productoRepositoryProvider)
          .crearVarios(membresia.negocioId, nuevos);
      if (!mounted) return;
      final cantidad = nuevos.length;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$cantidad productos importados')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _avisar('No se pudo importar: $e');
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _proximamente() =>
      _avisar('Muy pronto podrás importar desde Excel o CSV.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.libreta.papel,
      body: LibretaPageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 26, 22, 32),
            children: [
              Row(
                children: [
                  LibretaBackButton(
                    oscuro: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Importar inventario',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.libreta.textoFuerte,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          'Carga tus productos sin escribir uno por uno.',
                          style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _FilaOpcion(
                icono: Icons.photo_camera_outlined,
                iconoVerde: true,
                titulo: 'Foto de tu lista',
                detalle: _leyendo
                    ? 'Leyendo tu foto…'
                    : 'La app lee nombres y precios de la foto',
                cargando: _leyendo,
                onTap: _leyendo ? null : _elegirFuente,
              ),
              const SizedBox(height: 12),
              _FilaOpcion(
                icono: Icons.description_outlined,
                titulo: 'Subir Excel o CSV',
                detalle: 'Desde otra app o tu computadora',
                proximamente: true,
                onTap: _proximamente,
              ),
              const SizedBox(height: 12),
              _FilaOpcion(
                icono: Icons.edit_outlined,
                titulo: 'Escribir a mano',
                detalle: 'Uno por uno, con calma',
                onTap: () => context.push(Routes.nuevoProducto),
              ),

              if (_filas.isNotEmpty) ...[
                const SizedBox(height: 20),
                _PanelDetectados(filas: _filas),
                const SizedBox(height: 16),
                LibretaButton(
                  label: _guardando
                      ? 'Importando…'
                      : 'Importar ${_filas.length} productos',
                  loading: _guardando,
                  onPressed: _guardando ? null : _importar,
                ),
              ],

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => context.push(Routes.migrarOtraApp),
                  child: Text(
                    '¿Vienes de otra app?',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: LibretaColors.verde,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja para elegir cámara o galería al leer una foto.
class _HojaFuente extends StatelessWidget {
  const _HojaFuente();

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: t.papel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: t.textoFuerte),
              title: Text('Cámara', style: TextStyle(color: t.textoFuerte, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: t.textoFuerte),
              title: Text('Galería', style: TextStyle(color: t.textoFuerte, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila-tarjeta de una forma de importar (réplica de las 3 filas de P1).
class _FilaOpcion extends StatelessWidget {
  const _FilaOpcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    this.iconoVerde = false,
    this.cargando = false,
    this.proximamente = false,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String detalle;
  final bool iconoVerde;
  final bool cargando;
  final bool proximamente;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.superficie,
          border: Border.all(color: t.bordeSuave),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconoVerde ? const Color(0x1F0E9F6E) : t.bordeSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icono,
                size: 22,
                color: iconoVerde ? LibretaColors.verde : t.textoFuerte,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.textoFuerte),
                  ),
                  Text(
                    detalle,
                    style: TextStyle(fontSize: 12, color: t.textoMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (cargando)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            else if (proximamente)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.bordeSuave,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Próximamente',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: t.textoMuted),
                ),
              )
            else
              Icon(Icons.chevron_right, size: 18, color: t.textoMuted),
          ],
        ),
      ),
    );
  }
}

/// Panel "Detectados de tu foto": vista previa de lo leído antes de importar.
class _PanelDetectados extends StatelessWidget {
  const _PanelDetectados({required this.filas});

  final List<FilaLibreta> filas;

  @override
  Widget build(BuildContext context) {
    final t = context.libreta;
    final visibles = filas.take(5).toList();
    final restantes = filas.length - visibles.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x0F0E9F6E),
        border: Border.all(color: const Color(0x2E0E9F6E)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DETECTADOS DE TU FOTO',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: LibretaColors.verde,
            ),
          ),
          const SizedBox(height: 8),
          for (final f in visibles)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      f.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: t.textoFuerte),
                    ),
                  ),
                  Text(
                    f.precio == null ? '—' : MoneyFormatter.usd(f.precio!),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.textoFuerte),
                  ),
                ],
              ),
            ),
          if (restantes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ $restantes productos más detectados',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textoMuted),
              ),
            ),
        ],
      ),
    );
  }
}
