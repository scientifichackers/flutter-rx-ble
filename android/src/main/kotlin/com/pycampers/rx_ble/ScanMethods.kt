package com.pycampers.rx_ble

import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.scan.ScanFilter
import com.polidea.rxandroidble2.scan.ScanSettings
import com.pycampers.plugin_scaffold.catchErrors
import com.pycampers.plugin_scaffold.trySend
import com.pycampers.plugin_scaffold.trySendThrowable
import dumpScanResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.reactivex.disposables.Disposable

interface ScanInterface {
    fun stopScan(call: MethodCall, result: MethodChannel.Result)
}

class ScanMethods(messenger: BinaryMessenger, val bleClient: RxBleClient, val connect: ConnectMethods) : ScanInterface {
    val channel = EventChannel(messenger, "$PKG_NAME/scan")
    var disposable: Disposable? = null
    var eventSink: EventSink? = null

    fun stopScan() {
        disposable?.dispose()
        disposable = null
        eventSink?.endOfStream()
        eventSink = null
    }

    fun startScan(scanSettings: ScanSettings, scanFilter: ScanFilter, events: EventSink) {
        stopScan()

        disposable = bleClient.scanBleDevices(scanSettings, scanFilter).subscribe(
            {
                trySend(events) {
                    val device = it.bleDevice
                    val state = connect.getDeviceState(device.macAddress)
                    state.bleDevice = device
                    dumpScanResult(it)
                }
            },
            { trySendThrowable(events, it) }
        )

        eventSink = events
    }

    init {
        channel.setStreamHandler(object : StreamHandler {
            override fun onListen(args: Any?, events: EventSink) {
                catchErrors(events) {
                    val map = args as Map<*, *>
                    val scanSettings = ScanSettings.Builder().setScanMode(map["scanMode"] as Int - 1).build()
                    val filter = ScanFilter.Builder()
                    (map["macAddress"] as String?)?.let { filter.setDeviceAddress(it) }
                    (map["name"] as String?)?.let { filter.setDeviceName(it) }
                    startScan(scanSettings, filter.build(), events)
                }
            }

            override fun onCancel(args: Any?) {
                stopScan()
            }
        })
    }

    override fun stopScan(call: MethodCall, result: MethodChannel.Result) {
        stopScan()
        result.success(null)
    }
}