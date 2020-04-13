package com.pycampers.rx_ble

import com.pycampers.plugin_scaffold.sendThrowable
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

interface ConnectInterface {
    fun disconnect(call: MethodCall, result: Result)
    fun getConnectionState(call: MethodCall, result: Result)
    fun connectOnCancel(id: Int, args: Any?)
    fun connectOnListen(id: Int, args: Any?, sink: EventSink)
}

class ConnectMethods : ConnectInterface {
    override fun connectOnListen(id: Int, args: Any?, sink: EventSink) {
        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        val waitForDevice = map["waitForDevice"] as Boolean
        val device = getBleDevice(deviceId)
        val state = getDeviceState(deviceId)

        state.disconnect()

        val stateDisposable = device.observeConnectionStateChanges()
                .subscribe { sink.success(it.ordinal) }

        state.disposable = device.establishConnection(waitForDevice)
                .doFinally {
                    sink.endOfStream()
                    stateDisposable.dispose()
                }
                .subscribe(
                        { state.bleConnection = it },
                        { sendThrowable(sink, it) }
                )
    }

    override fun connectOnCancel(id: Int, args: Any?) {
        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        devices[deviceId]?.disconnect()
    }

    override fun disconnect(call: MethodCall, result: Result) {
        val deviceId = call.arguments as String?

        val toDisconnect = if (deviceId != null) {
            listOf(deviceId)
        } else {
            devices.keys
        }
        for (it in toDisconnect) {
            println("disconnecting: $it")
            devices[it]?.disconnect()
        }

        result.success(null)
    }

    override fun getConnectionState(call: MethodCall, result: Result) {
        val deviceId = call.arguments as String
        result.success(getBleDevice(deviceId).connectionState.ordinal)
    }
}