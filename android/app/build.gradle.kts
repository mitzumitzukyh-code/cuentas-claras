import java.util.Properties

// Credenciales de firma. Viven en android/key.properties, que no se versiona;
// el propio .jks esta fuera del repositorio (ver ese archivo).
val propiedadesFirma = Properties().apply {
    val archivo = rootProject.file("key.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
val hayClaveDeFirma = propiedadesFirma.getProperty("storeFile") != null

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mitzukyhsdev.cuentaclara"
    // mobile_scanner requiere compileSdk >= 36.
    compileSdk = 36
    // Fijado a mano: 18 de los plugins (Firebase, mobile_scanner, image_picker...)
    // piden esta version y `flutter.ndkVersion` se queda corta, lo que llenaba
    // cada build de avisos de desajuste.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Requerido por flutter_local_notifications (APIs de java.time via desugaring)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mitzukyhsdev.cuentaclara"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase Auth requiere minSdk >= 23.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hayClaveDeFirma) {
            create("release") {
                storeFile = file(propiedadesFirma.getProperty("storeFile"))
                storePassword = propiedadesFirma.getProperty("storePassword")
                keyAlias = propiedadesFirma.getProperty("keyAlias")
                keyPassword = propiedadesFirma.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // NO MINIFICAR / NO OFUSCAR EN RELEASE. No tocar sin leer esto.
            //
            // El plugin de Flutter activa R8 por defecto en release. R8
            // renombraba las clases internas de Firebase Auth
            // (p. ej. com.google.firebase.auth.EmailAuthCredential -> q), y eso
            // rompia la LECTURA de la sesion guardada al reabrir la app: el
            // usuario quedaba logueado en disco pero Firebase no podia
            // deserializarlo, asi que cada arranque en release caia en la
            // pantalla de login. En debug (sin R8) nunca pasaba — por eso
            // costo tanto verlo. Diagnosticado en el Z2464N el 2026-07-22
            // comparando el mismo login en debug (persistia) vs release (no).
            //
            // Una app Flutter casi no adelgaza con R8 (el peso es el motor y los
            // assets, ya tree-shakeados), asi que desactivarlo no cuesta nada y
            // elimina toda esta clase de fallos. Si algun dia se quiere volver a
            // activar, hay que agregar reglas -keep para Firebase Auth y probar
            // el ciclo login -> cerrar del todo -> reabrir EN RELEASE en un
            // dispositivo real antes de dar por bueno el build.
            isMinifyEnabled = false
            isShrinkResources = false

            // Antes se firmaba con la clave de debug, lo que hacia el AAB
            // impublicable: Google Play rechaza cualquier artefacto firmado con
            // ella. Ahora se usa la clave de subida real.
            //
            // Si key.properties no esta (otra maquina, un CI sin secretos), el
            // build FALLA a proposito. La alternativa —caer de vuelta a debug—
            // es peor: produce en silencio un artefacto que parece publicable y
            // no lo es, y solo te enteras al subirlo.
            signingConfig = if (hayClaveDeFirma) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "Falta android/key.properties: no se puede firmar el release. " +
                    "Copia el archivo y el .jks desde tu respaldo."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
