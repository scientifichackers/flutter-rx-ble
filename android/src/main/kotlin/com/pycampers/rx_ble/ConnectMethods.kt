package com.pycampers.rx_ble

import com.pycampers.plugin_scaffold.catchErrors
import com.pycampers.plugin_scaffold.trySend
import com.pycampers.plugin_scaffold.trySendThrowable
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.reactivex.Single
import java.util.UUID

interface ConnectInterface {
    fun disconnect(call: MethodCall, result: Result)
    fun getConnectionState(call: MethodCall, result: Result)
    fun discoverChars(call: MethodCall, result: Result)
    fun readChar(call: MethodCall, result: Result)
    fun writeChar(call: MethodCall, result: Result)
    fun requestMtu(call: MethodCall, result: Result)
}

class ConnectMethods : ConnectInterface, StreamHandler {
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

    fun connect(deviceId: String, waitForDevice: Boolean, eventSink: EventSink) {
        disconnect(deviceId)

        val device = getBleDevice(deviceId)
        val state = getDeviceState(deviceId)

        state.connectDisposable = device.establishConnection(waitForDevice)
            .doFinally { catchErrors(eventSink) { eventSink.endOfStream() } }
            .subscribe(
                { state.bleConnection = it },
                { trySendThrowable(eventSink, it) }
            )

        state.stateDisposable = device.observeConnectionStateChanges()
            .doFinally { catchErrors(eventSink) { eventSink.endOfStream() } }
            .subscribe { trySend(eventSink) { it.ordinal } }

        state.eventSink = eventSink
    }

    override fun onListen(args: Any?, eventSink: EventSink) {
        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        val waitForDevice = map["waitForDevice"] as Boolean
        connect(deviceId, waitForDevice, eventSink)
    }

    override fun onCancel(args: Any?) {
        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        disconnect(deviceId)
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

    fun <T> sendObservable(observable: Single<T>, result: Result) {
        observable.run {
            subscribe(
                { trySend(result) { it } },
                { trySendThrowable(result, it) }
            )
        }
    }

    override fun discoverChars(call: MethodCall, result: Result) {
        val deviceId = call.arguments as String
        val connection = getBleConnection(deviceId)
        val charMap = mutableMapOf<String, List<String>>()

        connection.run {
            discoverServices().subscribe(
                {
                    trySend(result) {
                        for (service in it.bluetoothGattServices) {
                            val serviceId = service.uuid.toString()
                            charMap[serviceId] = service.characteristics.map { it.uuid.toString() }
                        }
                        charMap
                    }
                },
                { trySendThrowable(result, it) }
            )
        }
    }

    override fun readChar(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val connection = getBleConnection(deviceId)
        sendObservable(connection.readCharacteristic(uuid), result)
    }

    override fun writeChar(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val value = call.argument<ByteArray>("value")!!
        val connection = getBleConnection(deviceId)
        sendObservable(connection.writeCharacteristic(uuid, value), result)
    }

    override fun requestMtu(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val value = call.argument<Int>("value")!!
        val connection = getBleConnection(deviceId)
        sendObservable(connection.requestMtu(value), result)
    }
}