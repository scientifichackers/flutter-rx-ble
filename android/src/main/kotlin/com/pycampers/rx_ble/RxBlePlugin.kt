package com.pycampers.rx_ble

import android.Manifest.permission.ACCESS_COARSE_LOCATION
import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.exceptions.BleException
import com.pycampers.plugin_scaffold.createMethodChannel
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
            val messenger = registrar.messenger()
            val bleClient = RxBleClient.create(registrar.context())!!

            val p = PermissionMethods(registrar)
            val c = ConnectMethods(messenger)
            val s = ScanMethods(messenger, bleClient, c)

            createMethodChannel(
                PKG_NAME,
                registrar.messenger(),
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
//     fun getNotificationKey(deviceId: String, uuid: UUID): String {
//         return "$deviceId:$uuid"
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
//     fun startNotification(deviceId: String, uuid: UUID, eventSink: EventSink) {
//         val key = getNotificationKey(deviceId, uuid)
//         stopNotification(key)
//
//         notificationDisposableStore[key] = getBleConnection(deviceId).setupNotification(uuid)
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
//                     val deviceId = args["deviceId"] as String
//                     val uuid = UUID.fromString(args["uuid"] as String)
//                     startNotification(deviceId, uuid, eventSink)
//                 }
//             }
//
//             override fun onCancel(_args: Any?) {
//                 val args = _args as Map<*, *>
//                 val deviceId = args["deviceId"] as String
//                 val uuid = UUID.fromString(args["uuid"] as String)
//                 val key = getNotificationKey(deviceId, uuid)
//                 stopNotification(key)
//             }
//         })
//     }
//
//
//

