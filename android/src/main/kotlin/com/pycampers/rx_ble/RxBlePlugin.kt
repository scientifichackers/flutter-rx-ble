package com.pycampers.rx_ble

import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.RxBleConnection
import com.polidea.rxandroidble2.RxBleDevice
import com.polidea.rxandroidble2.exceptions.BleException
import com.pycampers.plugin_scaffold.createPluginScaffold
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.reactivex.disposables.Disposable
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins

const val PKG_NAME = "com.pycampers.rx_ble"

class DeviceState {
    var connectDisposable: Disposable? = null
    var stateDisposable: Disposable? = null
    var bleDevice: RxBleDevice? = null
    var bleConnection: RxBleConnection? = null

    fun disconnect() {
        print("disconnecting! ${bleDevice?.macAddress}")
        connectDisposable?.dispose()
        connectDisposable = null
        stateDisposable?.dispose()
        stateDisposable = null
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

class RxBlePlugin {
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

            val plugin = RxBlePluginMethods(
                PermissionMethods(registrar),
                ConnectMethods(),
                ScanMethods(bleClient),
                ReadWriteMethods()
            )

            createPluginScaffold(registrar.messenger(), PKG_NAME, plugin)
        }
    }
}
