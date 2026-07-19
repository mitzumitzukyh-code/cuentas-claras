# Cuenta Clara — Setup

Pasos para dejar el proyecto corriendo. Los que requieren tu cuenta de Firebase
**debes ejecutarlos tú** (Claude no puede autenticar por ti).

## 1. Requisitos

- Flutter 3.29+ (probado con 3.29.3 / Dart 3.7.2)
- Una cuenta de Google para Firebase

## 2. Conectar Firebase (obligatorio antes del primer `flutter run`)

El repo trae `lib/firebase_options.dart` como **placeholder** con valores
ficticios: compila, pero la app no conecta. Si lo ejecutas sin configurar, verás
una pantalla "Firebase no está configurado" en vez de un crash.

```bash
# 1. Instalar las CLIs
dart pub global activate flutterfire_cli
npm install -g firebase-tools
firebase login

# 2. Crear/enlazar el proyecto y generar firebase_options.dart real
#    Sobrescribe el placeholder y coloca google-services.json / GoogleService-Info.plist
flutterfire configure

# 3. Publicar las reglas de seguridad y los índices
firebase deploy --only firestore:rules,firestore:indexes
```

## 3. En la consola de Firebase

1. **Authentication → Sign-in method**: habilitar **Teléfono** y **Correo
   electrónico** (con *Email link / passwordless* si quieres el flujo de "abrir
   correo").
2. **Firestore Database**: crear la base (modo producción — las reglas de este
   repo ya la protegen).
3. **Storage**: crear el bucket (fotos de producto).

### Pendiente de configuración para el login por correo

`AuthRepository.enviarEnlaceCorreo` usa un `ActionCodeSettings` con una URL
placeholder (`https://placeholder-cuenta-clara.web.app/finishSignIn`). Hay que
reemplazarla por un dominio autorizado real en
`lib/features/auth/data/auth_repository.dart`.

## 4. Correr la app

```bash
flutter pub get
flutter run
```

## 5. Verificar las reglas de seguridad

El punto crítico del brief (§4): nadie puede leer un negocio donde no tenga
membresía. Para probarlo con el emulador:

```bash
firebase emulators:start --only firestore
```

Luego intenta leer `negocios/{otroNegocio}/productos` con un usuario sin
membresía → debe responder `PERMISSION_DENIED`.

## Notas

- **Tipografía**: se usa `google_fonts` (Inter), que descarga la fuente en
  runtime la primera vez. Para producción conviene empaquetar los `.ttf` en
  `assets/fonts/` y declararlos en `pubspec.yaml`.
- **`assets/legal/`**: carpeta creada vacía a propósito — los documentos legales
  los colocas tú (ver más abajo).
- **Android**: `minSdk` está fijado en 23 (requisito de Firebase Auth),
  `compileSdk` en 36 (requisito de `mobile_scanner`) y el desugaring está
  activado (requisito de `flutter_local_notifications`).
- **`open_mail_app` → `url_launcher`**: el brief (§2) listaba `open_mail_app`
  para el botón "abrir correo", pero esa librería está sin mantenimiento y no
  declara `namespace`, lo que **rompe el build con AGP 8**. Se sustituyó por
  `url_launcher` con el esquema `mailto:`. Diferencia funcional: se abre la app
  de correo por defecto en vez de mostrar un selector entre varias.
