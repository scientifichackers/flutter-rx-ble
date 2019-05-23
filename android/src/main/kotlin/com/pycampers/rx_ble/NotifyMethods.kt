package com.pycampers.rx_ble

import com.pycampers.plugin_scaffold.catchErrors
import com.pycampers.plugin_scaffold.trySend
import com.pycampers.plugin_scaffold.trySendThrowable
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.reactivex.disposables.Disposable
import java.util.UUID

class NotifyMethods : StreamHandler {
    val disposables = mutableMapOf<String, Disposable>()

    fun getNotificationKey(deviceId: String, uuid: UUID): String = "$deviceId:$uuid"

    fun stopNotification(key: String) {
        disposables[key]?.dispose()
        disposables.remove(key)
    }

    fun startNotification(deviceId: String, uuid: UUID, eventSink: EventSink) {
        val key = getNotificationKey(deviceId, uuid)
        stopNotification(key)

        disposables[key] = getBleConnection(deviceId).setupNotification(uuid)
            .flatMap { it }
            .doFinally { catchErrors(eventSink) { eventSink.endOfStream() } }
            .subscribe(
                { trySend(eventSink) { it } },
                { trySendThrowable(eventSink, it) }
            )
    }

    override fun onListen(args: Any?, eventSink: EventSink) {
        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        val uuid = UUID.fromString(args["uuid"] as String)
        startNotification(deviceId, uuid, eventSink)
    }

    override fun onCancel(args: Any?) {
        println(">> $disposables")

        val map = args as Map<*, *>
        val deviceId = map["deviceId"] as String
        val uuid = UUID.fromString(map["uuid"] as String)
        val key = getNotificationKey(deviceId, uuid)
        stopNotification(key)
    }
}
