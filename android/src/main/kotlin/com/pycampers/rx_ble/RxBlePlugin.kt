package com.pycampers.rx_ble

import androidx.annotation.NonNull
import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.RxBleConnection
import com.polidea.rxandroidble2.RxBleDevice
import com.polidea.rxandroidble2.exceptions.BleException
import com.pycampers.plugin_scaffold.createPluginScaffold
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.reactivex.disposables.Disposable
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins

const val PKG_NAME = "com.pycampers.rx_ble"

class RxBlePlugin : FlutterPlugin, ActivityAware {
    var permissionMethods: PermissionMethods? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        RxJavaPlugins.setErrorHandler { error ->
            if (error is UndeliverableException && error.cause is BleException) {
                // ignore BleExceptions as they were surely delivered at least once
                return@setErrorHandler
            }
            throw error
        }

        val bleClient = RxBleClient.create(flutterPluginBinding.applicationContext)!!

        permissionMethods = PermissionMethods(flutterPluginBinding.applicationContext)

        val plugin = RxBlePluginMethods(
                permissionMethods!!,
                ConnectMethods(),
                ScanMethods(bleClient),
                ReadWriteMethods()
        )
        createPluginScaffold(flutterPluginBinding.binaryMessenger, PKG_NAME, plugin)
    }

    // This static function is optional and equivalent to onAttachedToEngine. It supports the old
    // pre-Flutter-1.12 Android projects. You are encouraged to continue supporting
    // plugin registration via this function while apps migrate to use the new Android APIs
    // post-flutter-1.12 via https://flutter.dev/go/android-project-migration.
    //
    // It is encouraged to share logic between onAttachedToEngine and registerWith to keep
    // them functionally equivalent. Only one of onAttachedToEngine or registerWith will be called
    // depending on the user's project. onAttachedToEngine or registerWith must both be defined
    // in the same class.
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            RxJavaPlugins.setErrorHandler { error ->
                if (error is UndeliverableException && error.cause is BleException) {
                    // ignore BleExceptions as they were surely delivered at least once
                    return@setErrorHandler
                }
                throw error
            }

            val bleClient = RxBleClient.create(registrar.context())!!

            val permissionMethods = PermissionMethods(registrar.context());
            registrar.addActivityResultListener(permissionMethods)
            registrar.addRequestPermissionsResultListener(permissionMethods)
            permissionMethods.activity = registrar.activity()

            val plugin = RxBlePluginMethods(
                    permissionMethods,
                    ConnectMethods(),
                    ScanMethods(bleClient),
                    ReadWriteMethods()
            )
            createPluginScaffold(registrar.messenger(), PKG_NAME, plugin)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        permissionMethods?.let {
            binding.addActivityResultListener(it)
            binding.addRequestPermissionsResultListener(it)
            it.activity = binding.activity
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {}

    override fun onDetachedFromActivity() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivityForConfigChanges() {}
}


class DeviceState {
    var disposable: Disposable? = null
    var bleDevice: RxBleDevice? = null
    var bleConnection: RxBleConnection? = null

    fun disconnect() {
        print("disconnecting! ${bleDevice?.macAddress}")
        disposable?.dispose()
        disposable = null
    }
}

val devices = mutableMapOf<String, DeviceState>()

fun getDeviceState(deviceId: String): DeviceState {
    return devices.getOrPut(deviceId) { DeviceState() }
}

fun getBleDevice(deviceId: String): RxBleDevice {
    return devices[deviceId]?.bleDevice ?: throw IllegalArgumentException(
            "Device has not been initialized yet. " +
                    "You must call \"startScan()\" and wait for " +
                    "device to appear in ScanResults before accessing the device."
    )
}

fun getBleConnection(deviceId: String): RxBleConnection {
    return devices[deviceId]?.bleConnection ?: throw IllegalArgumentException(
            "Connection to device has not been initialized yet. " +
                    "You must call \"connect()\" and wait for " +
                    "\"BleConnectionState.connected\" before doing any read/write operation."
    )
}

class RxBlePluginMethods(p: PermissionInterface, c: ConnectInterface, s: ScanInterface, r: ReadWriteInterface) :
        PermissionInterface by p, ConnectInterface by c, ScanInterface by s, ReadWriteInterface by r
