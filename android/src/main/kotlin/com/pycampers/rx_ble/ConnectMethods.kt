    package com.pycampers.rx_ble

import com.polidea.rxandroidble2.RxBleConnection
import com.polidea.rxandroidble2.RxBleDevice
import com.pycampers.plugin_scaffold.catchErrors
import com.pycampers.plugin_scaffold.trySend
import com.pycampers.plugin_scaffold.trySendThrowable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.reactivex.Single
import io.reactivex.disposables.Disposable
import java.util.UUID

interface ConnectInterface {
    fun disconnect(call: MethodCall, result: Result)
    fun getBleConnection(deviceId: String): RxBleConnection
    fun getConnectionState(call: MethodCall, result: Result)
    fun readChar(call: MethodCall, result: Result)
    fun writeChar(call: MethodCall, result: Result)
    fun requestMtu(call: MethodCall, result: Result)
}

class DeviceState {
    var connectDisposable: Disposable? = null
    var stateDisposable: Disposable? = null
    var eventSink: EventSink? = null
    var bleDevice: RxBleDevice? = null
    var bleConnection: RxBleConnection? = null
}

class ConnectMethods(messenger: BinaryMessenger) : ConnectInterface {
    val channel = EventChannel(messenger, "$PKG_NAME/connect")
    val devices = mutableMapOf<String, DeviceState>()

    fun getBleDevice(deviceId: String): RxBleDevice {
        return devices[deviceId]?.bleDevice ?: throw IllegalArgumentException(
            "Device has not been initialized yet. " +
                "You must call \"startScan()\" and wait for " +
                "device to appear in ScanResults before accessing the device."
        )
    }

    fun getDeviceState(deviceId: String) = devices.getOrPut(deviceId) { DeviceState() }

    fun disconnect(deviceId: String) {
        devices[deviceId]?.run {
            connectDisposable?.dispose()
            connectDisposable = null
            stateDisposable?.dispose()
            stateDisposable = null
            eventSink?.endOfStream()
            eventSink = null
        }
    }

    fun connect(deviceId: String, waitForDevice: Boolean, events: EventSink) {
        disconnect(deviceId)

        val device = getBleDevice(deviceId)
        val state = getDeviceState(deviceId)

        state.connectDisposable = device.establishConnection(waitForDevice).subscribe(
            { state.bleConnection = it },
            { trySendThrowable(events, it) }
        )
        state.stateDisposable = device.observeConnectionStateChanges().subscribe { trySend(events) { it.ordinal } }

        state.eventSink = events
    }

    init {
        channel.setStreamHandler(object : StreamHandler {
            override fun onListen(args: Any?, events: EventSink) {
                catchErrors(events) {
                    val map = args as Map<*, *>
                    val deviceId = map["deviceId"] as String
                    val waitForDevice = map["waitForDevice"] as Boolean
                    connect(deviceId, waitForDevice, events)
                }
            }

            override fun onCancel(args: Any?) {
                val map = args as Map<*, *>
                val deviceId = map["deviceId"] as String
                disconnect(deviceId)
            }
        })
    }

    override fun getBleConnection(deviceId: String): RxBleConnection {
        return devices[deviceId]?.bleConnection ?: throw IllegalArgumentException(
            "Connection to device has not been initialized yet. " +
                "You must call \"connect()\" and wait for " +
                "\"BleConnectionState.connected\" before doing any read/write operation."
        )
    }

    override fun disconnect(call: MethodCall, result: Result) {
        val deviceId = call.arguments as String?
        if (deviceId != null) {
            disconnect(deviceId)
        } else {
            for (it in devices.keys) {
                disconnect(it)
            }
        }
        result.success(null)
    }

    override fun getConnectionState(call: MethodCall, result: Result) {
        val deviceId = call.arguments as String
        result.success(getBleDevice(deviceId).connectionState.ordinal)
    }

    fun <T> subscribeAndSendResult(observable: Single<T>, result: Result) {
        observable.run {
            subscribe(
                { trySend(result) { it } },
                { trySendThrowable(result, it) }
            )
        }
    }

    override fun readChar(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val connection = getBleConnection(deviceId)
        subscribeAndSendResult(connection.readCharacteristic(uuid), result)
    }

    override fun writeChar(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val value = call.argument<ByteArray>("value")!!
        val connection = getBleConnection(deviceId)
        subscribeAndSendResult(connection.writeCharacteristic(uuid, value), result)
    }

    override fun requestMtu(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val value = call.argument<Int>("value")!!
        val connection = getBleConnection(deviceId)
        subscribeAndSendResult(connection.requestMtu(value), result)
    }
}