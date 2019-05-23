package com.pycampers.rx_ble

import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.RxBleConnection
import com.polidea.rxandroidble2.RxBleDevice
import com.polidea.rxandroidble2.exceptions.BleException
import com.pycampers.plugin_scaffold.createPluginScaffold
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.reactivex.disposables.Disposable
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins

const val PKG_NAME = "com.pycampers.rx_ble"

class DeviceState {
    var connectDisposable: Disposable? = null
    var stateDisposable: Disposable? = null
    var eventSink: EventChannel.EventSink? = null
    var bleDevice: RxBleDevice? = null
    var bleConnection: RxBleConnection? = null
}

val devices = mutableMapOf<String, DeviceState>()

fun getBleDevice(deviceId: String): RxBleDevice {
    return devices[deviceId]?.bleDevice ?: throw IllegalArgumentException(
        "Device has not been initialized yet. " +
            "You must call \"startScan()\" and wait for " +
            "device to appear in ScanResults before accessing the device."
    )
}

fun getDeviceState(deviceId: String): DeviceState {
    return devices.getOrPut(deviceId) { DeviceState() }
}

fun getBleConnection(deviceId: String): RxBleConnection {
    return devices[deviceId]?.bleConnection ?: throw IllegalArgumentException(
        "Connection to device has not been initialized yet. " +
            "You must call \"connect()\" and wait for " +
            "\"BleConnectionState.connected\" before doing any read/write operation."
    )
}

class RxBlePluginCallDispatcher(
    p: PermissionInterface,
    c: ConnectInterface,
    s: ScanInterface
) : PermissionInterface by p, ConnectInterface by c, ScanInterface by s {
    init {
        RxJavaPlugins.setErrorHandler { error ->
            if (error is UndeliverableException && error.cause is BleException) {
                // ignore BleExceptions as they were surely delivered at least once
                return@setErrorHandler
            }
            throw error
        }
    }
}

class RxBlePlugin {
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val bleClient = RxBleClient.create(registrar.context())!!

            val permissionMethods = PermissionMethods(registrar)
            val connectMethods = ConnectMethods()
            val scanMethods = ScanMethods(bleClient)
            val notifyMethods = NotifyMethods()

            createPluginScaffold(
                PKG_NAME,
                registrar.messenger(),
                RxBlePluginCallDispatcher(permissionMethods, connectMethods, scanMethods),
                mapOf(
                    "notify" to notifyMethods,
                    "connect" to connectMethods,
                    "scan" to scanMethods
                )
            )
        }
    }
}
