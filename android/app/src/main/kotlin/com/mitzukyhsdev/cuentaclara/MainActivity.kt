package com.mitzukyhsdev.cuentaclara

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Canal para leer los dispositivos Bluetooth emparejados CON SU CLASE.
 *
 * `print_bluetooth_thermal` devuelve solo nombre y MAC, asi que su lista
 * mezclaba impresoras con audifonos, cornetas y el manos libres del carro, y
 * la pantalla los ofrecia todos como si fueran impresoras. La clase de
 * dispositivo la conoce Android y no cruza a Dart por ese plugin, asi que se
 * pide aqui.
 *
 * **`FlutterFragmentActivity` y no `FlutterActivity`**: `local_auth` usa
 * `androidx.biometric.BiometricPrompt`, que necesita alojar un fragment y por
 * tanto una `FragmentActivity`. Con la clase normal, `authenticate()` lanzaba
 * `PlatformException(no_fragment_activity)` en cada intento, el candado
 * biometrico se abria solo y nunca llego a proteger nada.
 */
class MainActivity : FlutterFragmentActivity() {
    private val canal = "cuentaclara/bluetooth"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { llamada, respuesta ->
                when (llamada.method) {
                    "emparejados" -> respuesta.success(emparejados())
                    else -> respuesta.notImplemented()
                }
            }
    }

    /**
     * Emparejados con su clase. El filtrado se hace en Dart: aqui solo se
     * expone el dato crudo, para no repartir la misma regla entre dos
     * lenguajes.
     *
     * Devuelve lista vacia si falta `BLUETOOTH_CONNECT` o no hay adaptador;
     * el mensaje al usuario lo da la capa de Dart, que ya distingue el caso
     * de "Bluetooth apagado" del de "no hay nada emparejado".
     */
    private fun emparejados(): List<Map<String, Any>> {
        val gestor = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adaptador: BluetoothAdapter = gestor?.adapter ?: return emptyList()

        return try {
            adaptador.bondedDevices.orEmpty().map { dispositivo ->
                mapOf(
                    "nombre" to (dispositivo.name ?: ""),
                    "mac" to dispositivo.address,
                    // `majorDeviceClass` ya viene enmascarado (0x0400 audio,
                    // 0x0600 imaging...); `deviceClass` afina dentro del mayor.
                    "claseMayor" to (dispositivo.bluetoothClass?.majorDeviceClass ?: 0),
                    "clase" to (dispositivo.bluetoothClass?.deviceClass ?: 0),
                )
            }
        } catch (e: SecurityException) {
            // Sin BLUETOOTH_CONNECT, `bondedDevices` lanza en Android 12+.
            emptyList()
        }
    }
}
