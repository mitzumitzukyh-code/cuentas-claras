import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/tasa_activa_provider.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../shared/presentation/libreta/libreta.dart';
import '../../../shared/utils/whatsapp.dart';
import '../../negocio/data/negocio_repository.dart';
import '../domain/cierre_caja.dart';

/// Resumen del día tras cerrar caja (réplica visual de `P1 · RESUMEN DEL
/// DÍA`, `Lote H · Cierre y Proveedores`).
class ResumenDiaScreen extends ConsumerWidget {
  const ResumenDiaScreen({super.key, required this.cierre});

  final CierreCaja cierre;

  String _fecha(DateTime f) {
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${dias[f.weekday - 1]} ${f.day} ${meses[f.month - 1]}';
  }

  Future<void> _compartir(String negocioNombre) async {
    final texto = StringBuffer()
      ..writeln('*Resumen del día · $negocioNombre*')
      ..writeln(_fecha(cierre.cerradaEn))
      ..writeln()
      ..writeln('Ventas: +${MoneyFormatter.usd(cierre.ventasUSD)}')
      ..writeln('Gastos: −${MoneyFormatter.usd(cierre.gastosUSD)}')
      ..writeln('Fiado otorgado: −${MoneyFormatter.usd(cierre.fiadoOtorgadoUSD)}')
      ..writeln('Abonos recibidos: +${MoneyFormatter.usd(cierre.abonosUSD)}')
      ..writeln()
      ..writeln('Neto en caja: ${MoneyFormatter.usd(cierre.netoUSD)}');
    if (cierre.descuadreUSD != 0) {
      texto.writeln(
        cierre.descuadreUSD > 0
            ? 'Sobrante de efectivo: ${MoneyFormatter.usd(cierre.descuadreUSD)}'
            : 'Descuadre de efectivo: faltan ${MoneyFormatter.usd(-cierre.descuadreUSD)}',
      );
    }
    await abrirWhatsApp(texto: texto.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negocio = ref.watch(negocioActivoProvider).valueOrNull;
    final tasa = ref.watch(tasaActivaValorProvider);

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
                    onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen del día',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.libreta.textoFuerte,
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          '${_fecha(cierre.cerradaEn)} · caja cerrada',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.libreta.textoMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: LibretaColors.verde,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Color(0x470E9F6E), offset: Offset(0, 12), blurRadius: 26),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NETO EN CAJA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xD9FFFFFF)),
                    ),
                    Text(
                      MoneyFormatter.usd(cierre.netoUSD),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.7),
                    ),
                    Text(
                      tasa == null
                          ? 'tasa no disponible'
                          : '${MoneyFormatter.usdComoBs(cierre.netoUSD, tasa)} · a la tasa de hoy',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xD9FFFFFF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(
                  color: context.libreta.superficie,
                  border: Border.all(color: const Color(0x141E2A38)),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _FilaResumen(etiqueta: 'Ventas', monto: cierre.ventasUSD, positivo: true),
                    _FilaResumen(etiqueta: 'Gastos', monto: -cierre.gastosUSD, positivo: false),
                    _FilaResumen(etiqueta: 'Fiado otorgado', monto: -cierre.fiadoOtorgadoUSD, positivo: false),
                    _FilaResumen(
                      etiqueta: 'Abonos recibidos',
                      monto: cierre.abonosUSD,
                      positivo: true,
                      ultima: true,
                    ),
                  ],
                ),
              ),

              if (cierre.descuadreUSD != 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x21F2A93C),
                    border: Border.all(color: const Color(0x59F2A93C)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const LibretaIcono(AppAssets.accAlerta, size: 18, color: LibretaColors.aviso),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          cierre.descuadreUSD > 0
                              ? 'Sobrante de efectivo: ${MoneyFormatter.usd(cierre.descuadreUSD)}'
                              : 'Descuadre de efectivo: faltan ${MoneyFormatter.usd(-cierre.descuadreUSD)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LibretaColors.aviso),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Center(
                child: Text(
                  '¡buen día de trabajo!',
                  style: GoogleFonts.caveat(fontSize: 22, fontWeight: FontWeight.w700, color: LibretaColors.verde),
                ),
              ),
              const SizedBox(height: 14),
              LibretaSecondaryButton(
                label: 'Enviar resumen por WhatsApp',
                icon: const LibretaIcono(AppAssets.accMensaje, size: 18, color: LibretaColors.verde),
                onPressed: () => _compartir(negocio?.nombre ?? 'mi negocio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaResumen extends StatelessWidget {
  const _FilaResumen({
    required this.etiqueta,
    required this.monto,
    required this.positivo,
    this.ultima = false,
  });

  final String etiqueta;
  final double monto;
  final bool positivo;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: ultima ? null : Border(bottom: BorderSide(color: context.libreta.renglon)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.libreta.textoFuerte)),
          Text(
            '${monto >= 0 ? "+" : "−"}${MoneyFormatter.usd(monto.abs())}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: positivo ? LibretaColors.verde : context.libreta.textoFuerte,
            ),
          ),
        ],
      ),
    );
  }
}
