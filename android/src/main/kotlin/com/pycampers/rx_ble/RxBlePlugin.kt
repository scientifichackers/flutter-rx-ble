package com.pycampers.rx_ble

import android.Manifest.permission.ACCESS_COARSE_LOCATION
import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.exceptions.BleException
import com.pycampers.method_call_dispatcher.MethodCallDispatcher
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry.Registrar
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins

const val REQUEST_ENABLE_BT = 1
const val REQUEST_ENABLE_LOC = 2
const val REQUEST_PERM_LOC = 3
const val LOC_PERM = ACCESS_COARSE_LOCATION

const val PKG_NAME = "com.pycampers.rx_ble"

class RxBlePluginCallDispatcher(
    p: PermissionInterface,
    c: ConnectInterface,
    s: ScanInterface
) : MethodCallDispatcher(), PermissionInterface by p, ConnectInterface by c, ScanInterface by s {
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
            val channel = MethodChannel(registrar.messenger(), PKG_NAME)
            val messenger = registrar.messenger()
            val bleClient = RxBleClient.create(registrar.context())!!

            val p = PermissionMethods(registrar)
            val c = ConnectMethods(messenger)
            val s = ScanMethods(messenger, bleClient, c)

            channel.setMethodCallHandler(
                RxBlePluginCallDispatcher(p, c, s)
            )
        }
    }
}
//     val notificationChannel = EventChannel(registrar.messenger(), "$PKG_NAME/notification")
//
//     var scanDisposable: Disposable? = null
//     var notificationDisposableStore = mutableMapOf<String, Disposable>()
//
//     var scanEvents: EventSink? = null
//     var notificationEventStore = mutableMapOf<String, EventSink>()
//
//
//
//     fun getNotificationKey(macAddress: String, uuid: UUID): String {
//         return "$macAddress:$uuid"
//     }
//
//     fun stopScan() {
//         scanDisposable?.dispose()
//         scanDisposable = null
//         scanEvents?.endOfStream()
//         scanEvents = null
//     }
//
//
//     fun stopNotification(key: String) {
//         notificationDisposableStore[key]?.dispose()
//         notificationDisposableStore.remove(key)
//
//         notificationEventStore[key]?.endOfStream()
//         notificationEventStore.remove(key)
//     }
//
//     fun startNotification(macAddress: String, uuid: UUID, eventSink: EventSink) {
//         val key = getNotificationKey(macAddress, uuid)
//         stopNotification(key)
//
//         notificationDisposableStore[key] = getBleConnection(macAddress).setupNotification(uuid)
//             .subscribe(
//                 { trySend(eventSink) { it.all() } },
//                 { trySendThrowable(eventSink, it) }
//             )
//
//         notificationEventStore[key] = eventSink
//     }
//
//     init {
//
//         notificationChannel.setStreamHandler(object : StreamHandler {
//             override fun onListen(_args: Any?, eventSink: EventSink) {
//                 catchErrors(eventSink) {
//                     val args = _args as Map<*, *>
//                     val macAddress = args["macAddress"] as String
//                     val uuid = UUID.fromString(args["uuid"] as String)
//                     startNotification(macAddress, uuid, eventSink)
//                 }
//             }
//
//             override fun onCancel(_args: Any?) {
//                 val args = _args as Map<*, *>
//                 val macAddress = args["macAddress"] as String
//                 val uuid = UUID.fromString(args["uuid"] as String)
//                 val key = getNotificationKey(macAddress, uuid)
//                 stopNotification(key)
//             }
//         })
//     }
//
//
//     fun <T> subscribeAndSendResult(observable: Single<T>, result: Result) {
//         observable.run {
//             subscribe(
//                 { trySend(result) { it } },
//                 { trySendThrowable(result, it) }
//             )
//         }
//     }
//
//     fun readChar(call: MethodCall, result: Result) {
//         val macAddress = call.argument<String>("macAddress")!!
//         val uuid = UUID.fromString(call.argument<String>("uuid")!!)
//         val connection = getBleConnection(macAddress)
//         subscribeAndSendResult(connection.readCharacteristic(uuid), result)
//     }
//
//     fun writeChar(call: MethodCall, result: Result) {
//         val macAddress = call.argument<String>("macAddress")!!
//         val uuid = UUID.fromString(call.argument<String>("uuid")!!)
//         val value = call.argument<ByteArray>("value")!!
//         val connection = getBleConnection(macAddress)
//         subscribeAndSendResult(connection.writeCharacteristic(uuid, value), result)
//     }
//
//     fun requestMtu(call: MethodCall, result: Result) {
//         val macAddress = call.argument<String>("macAddress")!!
//         val value = call.argument<Int>("value")!!
//         val connection = getBleConnection(macAddress)
//         subscribeAndSendResult(connection.requestMtu(value), result)
//     }
