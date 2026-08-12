/// Los borradores de lo que la app le escribe a un cliente por WhatsApp.
///
/// **Viven todos juntos y en un solo sitio a propósito.** Antes cada pantalla
/// escribía el suyo, y el mismo cliente podía recibir «Le recordamos con
/// cariño su saldo pendiente… ¡Gracias por su preferencia!» o «te escribo de
/// la bodega, ¿puedes pasar a abonar?» según por dónde hubiera tocado el
/// dueño. Ninguno estaba mal; lo que estaba mal es que salieran los dos de la
/// misma app sin que él eligiera.
///
/// Se unifica en el **tuteo**: la app se llama Cuenta Clara y su promesa es
/// «cuentas claras, amistades largas». El usted de cadena de tiendas no es la
/// voz de una bodega donde el dueño conoce a quien le fía por su nombre.
///
/// Son funciones puras y devuelven **borradores**, no mensajes enviados: todo
/// esto pasa por `editarMensaje` antes de salir, porque cobrarle a alguien es
/// delicado y el tono final lo pone el dueño.
library;

import '../../../core/utils/money_formatter.dart';
import 'cliente_fiado.dart';

/// El nombre con el que se saluda: el primero, no el completo.
///
/// «Hola María Alejandra Gonzalez Perez 👋» no lo escribe nadie.
String _saludo(String nombre) {
  final limpio = nombre.trim();
  if (limpio.isEmpty) return '';
  return limpio.split(RegExp(r'\s+')).first;
}

/// «$12,00 (Bs 9.172,20)», o solo los dólares si no hay tasa del día.
String _conBs(double usd, double? tasa) {
  final dolares = MoneyFormatter.usd(usd);
  if (tasa == null || tasa <= 0) return dolares;
  return '$dolares (${MoneyFormatter.usdComoBs(usd, tasa)})';
}

/// «Todavía me debes X, ¿te acercas?»
String borradorRecordatorio({
  required String nombre,
  required String negocio,
  required double saldoUSD,
  double? tasa,
}) {
  return 'Hola ${_saludo(nombre)} 👋 te escribo de $negocio. Tienes un saldo '
      'pendiente de ${_conBs(saldoUSD, tasa)}. ¿Puedes pasar a abonar esta '
      'semana? ¡Gracias!';
}

/// «Recibí tu abono, te quedan X».
///
/// Es el mensaje que el cliente agradece recibir, y el único de todos estos
/// que no le pide nada. Antes no existía: solo se avisaba al llegar a cero, de
/// modo que quien abonaba $5 de $20 —justo el cliente al que conviene
/// reforzarle la costumbre— no recibía constancia de nada.
String borradorAbono({
  required String nombre,
  required String negocio,
  required double abonoUSD,
  required double saldoRestanteUSD,
  double? tasa,
}) {
  final cierre = saldoRestanteUSD > 0.005
      ? 'Te quedan ${_conBs(saldoRestanteUSD, tasa)} por pagar.'
      : '¡Con eso quedas al día!';
  return 'Hola ${_saludo(nombre)} 👋 recibí tu abono de '
      '${_conBs(abonoUSD, tasa)} en $negocio. $cierre ¡Gracias!';
}

/// «Tu cuenta quedó en cero».
String borradorCuentaSaldada({
  required String nombre,
  required String negocio,
  required String fechaLarga,
  double aFavorUSD = 0,
  double? tasa,
}) {
  final extra = aFavorUSD > 0.005
      ? ' Además te quedan ${_conBs(aFavorUSD, tasa)} a favor para tu próxima '
          'compra.'
      : '';
  return 'Hola ${_saludo(nombre)} 👋 tu cuenta en $negocio quedó en CERO hoy, '
      '$fechaLarga. ¡Gracias por tu pago!$extra';
}

/// El detalle que respalda la cifra, no solo el total.
///
/// Un recordatorio que dice «$12,00» y nada más no le da al cliente con qué
/// contrastarlo, y ahí es justo donde se pierde la confianza que esta app
/// promete cuidar. Los movimientos ya estaban guardados; solo no se usaban.
///
/// Se manda del más viejo al más nuevo —al revés de como se leen en pantalla—
/// porque una cuenta se explica en el orden en que pasó.
String borradorEstadoCuenta({
  required String nombre,
  required String negocio,
  required List<MovimientoFiado> movimientos,
  required double saldoUSD,
  double? tasa,
  int maximoLineas = 15,
}) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  final orden = [...movimientos]..sort((a, b) => a.fecha.compareTo(b.fecha));
  // Con un cliente de años, mandar doscientas líneas por WhatsApp no explica
  // nada: se manda la cola reciente y se dice que hay más atrás.
  final recortado = orden.length > maximoLineas;
  final visibles = recortado
      ? orden.sublist(orden.length - maximoLineas)
      : orden;

  final lineas = visibles.map((m) {
    final f = '${m.fecha.day} ${meses[m.fecha.month - 1]}';
    final concepto = m.concepto.trim().isEmpty
        ? (m.tipo == TipoMovimientoFiado.abono ? 'abono' : 'fiado')
        : m.concepto.trim();
    final signo = m.tipo == TipoMovimientoFiado.abono ? '−' : '+';
    return '• $f — $concepto — $signo${MoneyFormatter.usd(m.montoUSD)}';
  }).join('\n');

  final buffer = StringBuffer()
    ..writeln('Hola ${_saludo(nombre)} 👋 este es el detalle de tu cuenta en '
        '$negocio:')
    ..writeln();
  if (recortado) buffer.writeln('(los últimos $maximoLineas movimientos)');
  buffer
    ..writeln(lineas)
    ..writeln();

  if (saldoUSD > 0.005) {
    buffer.write('Saldo pendiente: ${_conBs(saldoUSD, tasa)}');
  } else if (saldoUSD < -0.005) {
    buffer.write('Tienes ${_conBs(-saldoUSD, tasa)} a favor.');
  } else {
    buffer.write('Estás al día, no debes nada. ¡Gracias!');
  }
  return buffer.toString();
}
