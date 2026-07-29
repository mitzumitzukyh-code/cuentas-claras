import 'package:flutter/material.dart';

import '../../../shared/presentation/libreta/libreta.dart';

/// Pantalla de información legal (Privacidad y Términos de uso).
/// Lote E · P5 del diseño.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Información legal',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: context.libreta.textoFuerte,
                        letterSpacing: -0.5,
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
                    _EntradaSuave(
                      orden: 1,
                      child: _SeccionLegal(
                        icono: Icons.shield_outlined,
                        titulo: 'Política de privacidad',
                        subtitulo:
                            'Cómo manejamos tus datos personales',
                        onTap: () => _abrir(context, _privacidad),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EntradaSuave(
                      orden: 2,
                      child: _SeccionLegal(
                        icono: Icons.description_outlined,
                        titulo: 'Términos de uso',
                        subtitulo:
                            'Condiciones para usar Cuenta Clara',
                        onTap: () => _abrir(context, _terminos),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Cuenta Clara © ${DateTime.now().year} Mitzukyhs Dev — Venezuela.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.libreta.textoMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _abrir(BuildContext context, String contenido) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DetalleLegal(contenido: contenido),
      ),
    );
  }
}

class _SeccionLegal extends StatelessWidget {
  const _SeccionLegal({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.libreta.superficie,
          border: Border.all(color: const Color(0x141E2A38)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icono, size: 24, color: context.libreta.textoFuerte),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.libreta.textoFuerte,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 12.5, color: context.libreta.textoMuted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: context.libreta.textoMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de scroll con el contenido legal completo.
class _DetalleLegal extends StatelessWidget {
  const _DetalleLegal({required this.contenido});

  final String contenido;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.libreta.papel,
      appBar: AppBar(
        backgroundColor: context.libreta.papel,
        surfaceTintColor: context.libreta.papel,
        leading: LibretaBackButton(
          oscuro: true,
          onTap: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        child: SelectableText(
          contenido,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: context.libreta.textoFuerte,
          ),
        ),
      ),
    );
  }
}

const _privacidad = '''
POLÍTICA DE PRIVACIDAD DE CUENTA CLARA

Última actualización: 20 de julio de 2026.

Cuenta Clara es una aplicación de gestión para pequeños negocios en Venezuela (inventario, ventas, gastos y catálogo), desarrollada por Mitzukyhs Dev ("nosotros"). Esta política explica qué datos recopila la app, para qué se usan, con quién se comparten y cómo se protegen.

1. DATOS QUE RECOPILAMOS

1.1 Datos que tú nos das voluntariamente:
- Nombre del negocio, rubro y foto de perfil.
- Productos, precios, cantidades, fotos y variantes.
- Ventas, gastos, clientes (fiado), proveedores (cuentas por pagar).
- Correo electrónico y/o número de teléfono para la creación de la cuenta.

1.2 Datos recopilados automáticamente:
- Identificador único del dispositivo y token de notificaciones push (FCM).
- Fecha y hora de las transacciones.

1.3 Datos que NO recopilamos:
- No recopilamos datos de ubicación GPS.
- No recopilamos contactos de la agenda del dispositivo.
- No procesamos ni almacenamos números de tarjetas de crédito/débito.
- No vendemos datos personales a terceros.

2. FINALIDAD DEL TRATAMIENTO

Usamos tus datos exclusivamente para:
- Operar la aplicación: registrar ventas, controlar inventario, generar reportes y compartir catálogos.
- Enviar notificaciones push sobre ventas, stock bajo y cambios en la tasa BCV (solo si activaste los avisos).
- Mejorar la app: analizamos métricas de uso agregadas (nunca datos personales).
- Cumplir obligaciones legales: conservamos los registros de venta según lo exige la legislación venezolana.

3. ALMACENAMIENTO Y SEGURIDAD

- Todos los datos se almacenan en Firebase (Google Cloud Platform), con servidores en Estados Unidos.
- Las contraseñas se manejan exclusivamente a través de Firebase Authentication; nunca almacenamos contraseñas en nuestros servidores.
- El acceso a los datos de cada negocio está protegido por reglas de seguridad de Firestore que verifican la membresía del usuario.

4. CONSERVACIÓN DE DATOS

- Conservamos tus datos mientras mantengas una cuenta activa.
- Las ventas NO se eliminan al cerrar la cuenta, por requisitos fiscales venezolanos. El resto de los datos (productos, gastos, clientes) se eliminan al solicitar el borrado de cuenta.
- Puedes solicitar la exportación de tus datos en cualquier momento escribiendo a nuestro correo de contacto.

5. TUS DERECHOS (LOPDP)

Como titular de datos personales en Venezuela, tienes derecho a:
- Solicitar el acceso a tus datos personales.
- Solicitar la rectificación de datos inexactos.
- Solicitar la eliminación de tus datos (sujeto a limitaciones legales).
- Oponerte al tratamiento de tus datos para fines específicos.

Para ejercer estos derechos, escríbenos a: cuenta.clara.app@gmail.com

6. CONTACTO

Mitzukyhs Dev — Venezuela
Correo: cuenta.clara.app@gmail.com
''';

const _terminos = '''
TÉRMINOS DE USO DE CUENTA CLARA

Última actualización: 20 de julio de 2026.

Al usar Cuenta Clara aceptas estos términos. Si no estás de acuerdo, no uses la app.

1. DESCRIPCIÓN DEL SERVICIO

Cuenta Clara es una aplicación móvil de gestión para pequeños negocios en Venezuela. Permite controlar inventario, registrar ventas y gastos, generar reportes y compartir un catálogo de productos.

2. CUENTAS Y RESPONSABILIDAD

- Eres responsable de mantener la confidencialidad de tu cuenta.
- Debes proporcionar información veraz al registrarte.
- El dueño del negocio es responsable de las acciones de sus empleados en la app.

3. PLAN GRATIS Y PREMIUM

- Plan gratis: 1 negocio, 50 productos, historial de 30 días, 1 usuario, 1 moneda, catálogo con marca de agua.
- Plan Premium (\$5/mes): usuarios y productos ilimitados, reportes avanzados, exportación Excel/PDF, multi-moneda, control de deudas, sin marca de agua.
- Los pagos se procesan exclusivamente a través de Google Play y App Store.

4. PROPIEDAD INTELECTUAL

- Cuenta Clara es propiedad de Mitzukyhs Dev.
- El contenido que subes a la app (productos, fotos, etc.) te pertenece.
- No reclamamos derechos sobre tus datos de negocio.

5. LIMITACIÓN DE RESPONSABILIDAD

- Cuenta Clara se proporciona "tal cual", sin garantías de disponibilidad continua.
- No nos hacemos responsables por pérdidas derivadas del uso de la app.
- No garantizamos la precisión de la tasa de cambio obtenida de terceros (BCV, Paralelo).

6. MODIFICACIONES

- Podemos actualizar estos términos en cualquier momento.
- Te notificaremos de cambios materiales por correo o dentro de la app.
- El uso continuado después de los cambios constituye aceptación.

7. CONTACTO

Mitzukyhs Dev — Venezuela
Correo: cuenta.clara.app@gmail.com
''';

/// Fade + deslizamiento hacia arriba al entrar, escalonado por [orden].
class _EntradaSuave extends StatefulWidget {
  const _EntradaSuave({required this.orden, required this.child});

  final int orden;
  final Widget child;

  @override
  State<_EntradaSuave> createState() => _EntradaSuaveState();
}

class _EntradaSuaveState extends State<_EntradaSuave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(Duration(milliseconds: 60 * widget.orden), _ctrl.forward);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_anim),
        child: widget.child,
      ),
    );
  }
}
