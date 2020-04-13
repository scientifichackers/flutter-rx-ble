package com.pycampers.rx_ble

import com.pycampers.plugin_scaffold.trySend
import com.pycampers.plugin_scaffold.sendThrowable
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.reactivex.Single
import io.reactivex.disposables.Disposable
import java.util.*

interface ReadWriteInterface {
    fun discoverChars(call: MethodCall, result: Result)
    fun readChar(call: MethodCall, result: Result)
    fun writeChar(call: MethodCall, result: Result)
    fun requestMtu(call: MethodCall, result: Result)
    fun observeCharOnListen(id: Int, args: Any?, sink: EventSink)
    fun observeCharOnCancel(id: Int, args: Any?)
}

class ReadWriteMethods : ReadWriteInterface {
    val disposables = mutableMapOf<Int, Disposable>()

    fun <T> sendSingle(observable: Single<T>, result: Result) {
        observable.run {
            subscribe(
                    { trySend(result) { it } },
                    { sendThrowable(result, it) }
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
                    { sendThrowable(result, it) }
            )
        }
    }

    override fun readChar(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val connection = getBleConnection(deviceId)
        sendSingle(connection.readCharacteristic(uuid), result)
    }

    override fun writeChar(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val uuid = UUID.fromString(call.argument<String>("uuid")!!)
        val value = call.argument<ByteArray>("value")!!
        val connection = getBleConnection(deviceId)
        sendSingle(connection.writeCharacteristic(uuid, value), result)
    }

    override fun requestMtu(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")!!
        val value = call.argument<Int>("value")!!
        val connection = getBleConnection(deviceId)
        sendSingle(connection.requestMtu(value), result)
    }

    override fun observeCharOnListen(id: Int, args: Any?, sink: EventSink) {
        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        val uuid = UUID.fromString(map["uuid"] as String)

        disposables[id] = getBleConnection(deviceId).setupNotification(uuid)
                .flatMap { it }
                .doFinally { sink.endOfStream() }
                .subscribe(
                        { sink.success(it) },
                        { sendThrowable(sink, it) }
                )
    }

    override fun observeCharOnCancel(id: Int, args: Any?) {
        disposables[id]?.dispose()
        disposables.remove(id)
    }
}