package com.pycampers.rx_ble

import android.Manifest.permission.ACCESS_COARSE_LOCATION
import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.RxBleConnection
import com.polidea.rxandroidble2.RxBleDevice
import com.polidea.rxandroidble2.scan.ScanFilter
import com.polidea.rxandroidble2.scan.ScanSettings
import com.pycampers.method_call_dispatcher.catchErrors
import com.pycampers.method_call_dispatcher.trySend
import com.pycampers.method_call_dispatcher.trySendThrowable
import dumpScanResult
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.reactivex.Single
import io.reactivex.disposables.Disposable
import java.util.UUID

const val REQUEST_ENABLE_BT = 1
const val REQUEST_ENABLE_LOC = 2
const val REQUEST_PERM_LOC = 3
const val LOC_PERM = ACCESS_COARSE_LOCATION

const val PKG_NAME = "com.pycampers.rx_ble"

class RxBlePlugin(registrar: Registrar) : PermissionMagic(registrar) {
    companion object {
        @JvmStatic
        fun registerWith(registrar: Registrar) {
            val channel = MethodChannel(registrar.messenger(), PKG_NAME)
            channel.toString()
            channel.setMethodCallHandler(RxBlePlugin(registrar))
        }
    }

    val bleClient = RxBleClient.create(context)!!

    val scanChannel = EventChannel(registrar.messenger(), "$PKG_NAME/scan")
    val connectChannel = EventChannel(registrar.messenger(), "$PKG_NAME/connect")

    var scanDisposable: Disposable? = null
    var connectDisposable: Disposable? = null
    var observeStateDisposable: Disposable? = null

    var connectEvents: EventSink? = null
    var scanEvents: EventSink? = null

    val bleDeviceStore = mutableMapOf<String, RxBleDevice>()
    val bleConnectionStore = mutableMapOf<String, RxBleConnection>()

    fun getBleDevice(macAddress: String): RxBleDevice {
        return bleDeviceStore[macAddress] ?: throw IllegalArgumentException(
            "Device has not been initialized yet. " +
                "You must call \"startScan()\" and wait for " +
                "device to appear in ScanResults before accessing the device."
        )
    }

    fun getBleConnection(macAddress: String): RxBleConnection {
        return bleConnectionStore[macAddress] ?: throw IllegalArgumentException(
            "Connection to device has not been initialized yet. " +
                "You must call \"connect()\" and wait for " +
                "\"BleConnectionState.connected\" before doing any read/write operation."
        )
    }

    fun stopScan() {
        scanDisposable?.dispose()
        scanDisposable = null
        scanEvents?.endOfStream()
        scanEvents = null
    }

    fun startScan(scanMode: Int, scanFilter: ScanFilter, events: EventSink) {
        stopScan()
        scanDisposable = bleClient.scanBleDevices(
            ScanSettings.Builder().setScanMode(scanMode).build(),
            scanFilter
        ).subscribe(
            { scanResult ->
                trySend(events) {
                    bleDeviceStore[scanResult.bleDevice.macAddress] = scanResult.bleDevice
                    dumpScanResult(scanResult)
                }
            },
            { trySendThrowable(events, it) }
        )
        scanEvents = events
    }

    fun disconnect() {
        connectDisposable?.dispose()
        connectDisposable = null
        connectEvents?.endOfStream()
        connectEvents = null
    }

    fun connect(device: RxBleDevice, waitForDevice: Boolean, events: EventSink) {
        disconnect()
        connectDisposable = device.establishConnection(waitForDevice).subscribe(
            { bleConnectionStore[device.macAddress] = it },
            { trySendThrowable(events, it) }
        )

        observeStateDisposable?.dispose()
        observeStateDisposable = device.observeConnectionStateChanges().subscribe { trySend(events) { it.ordinal } }

        connectEvents = events
    }

    init {
        scanChannel.setStreamHandler(object : StreamHandler {
            override fun onListen(_args: Any?, events: EventSink) {
                catchErrors(events) {
                    val args = _args as Map<*, *>
                    val scanMode = args["scanMode"] as Int - 1
                    val filter = ScanFilter.Builder()
                    (args["macAddress"] as String?)?.let { filter.setDeviceAddress(it) }
                    (args["name"] as String?)?.let { filter.setDeviceName(it) }
                    startScan(scanMode, filter.build(), events)
                }
            }

            override fun onCancel(args: Any?) {
                stopScan()
            }
        })
        connectChannel.setStreamHandler(object : StreamHandler {
            override fun onListen(_args: Any?, events: EventSink) {
                catchErrors(events) {
                    val args = _args as Map<*, *>
                    val macAddress = args["macAddress"] as String
                    val waitForDevice = args["waitForDevice"] as Boolean
                    val device = getBleDevice(macAddress)
                    connect(device, waitForDevice, events)
                }
            }

            override fun onCancel(args: Any?) {
                disconnect()
            }
        })
    }

    fun stopScan(call: MethodCall, result: Result) {
        stopScan()
        result.success(null)
    }

    fun disconnect(call: MethodCall, result: Result) {
        disconnect()
        result.success(null)
    }

    fun getConnectionState(call: MethodCall, result: Result) {
        result.success(getBleDevice(call.arguments as String).connectionState.ordinal)
    }

    fun <T> subscribeAndSendResult(observable: Single<T>, result: Result) {
        observable.run {
            subscribe(
                { trySend(result) { it } },
                { trySendThrowable(result, it) }
            )
        }
    }

    fun readChar(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val connection = getBleConnection(macAddress)
        subscribeAndSendResult(connection.readCharacteristic(uuid), result)
    }

    fun writeChar(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val value = call.argument<ByteArray>("value")!!
        val connection = getBleConnection(macAddress)
        subscribeAndSendResult(connection.writeCharacteristic(uuid, value), result)
    }

    fun requestMtu(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")!!
        val value = call.argument<Int>("value")!!
        val connection = getBleConnection(macAddress)
        subscribeAndSendResult(connection.requestMtu(value), result)
    }
}
