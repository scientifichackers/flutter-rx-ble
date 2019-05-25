package com.pycampers.rx_ble

import com.polidea.rxandroidble2.RxBleClient
import com.polidea.rxandroidble2.scan.ScanFilter
import com.polidea.rxandroidble2.scan.ScanSettings
import com.pycampers.plugin_scaffold.StreamSink
import com.pycampers.plugin_scaffold.trySend
import com.pycampers.plugin_scaffold.trySendThrowable
import dumpScanResult
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.reactivex.disposables.Disposable

interface ScanInterface {
    fun stopScan(call: MethodCall, result: MethodChannel.Result)
    fun scanOnCancel(id: Int, args: Any?)
    fun scanOnListen(id: Int, args: Any?, sink: StreamSink)
}

class ScanMethods(val bleClient: RxBleClient) : ScanInterface {
    var disposable: Disposable? = null

    fun stopScan() {
        disposable?.dispose()
        disposable = null
    }

    override fun scanOnListen(id: Int, args: Any?, sink: StreamSink) {
        val map = args as Map<*, *>
        val scanSettings = ScanSettings.Builder().setScanMode(map["scanMode"] as Int - 1).build()

        val filter = ScanFilter.Builder()
        map["deviceId"]?.let { filter.setDeviceAddress(it as String) }
        map["name"]?.let { filter.setDeviceName(it as String) }

        stopScan()

        disposable = bleClient.scanBleDevices(scanSettings, filter.build())
            .doFinally { sink.endOfStream() }
            .subscribe(
                {
                    trySend(sink) {
                        val device = it.bleDevice
                        val state = getDeviceState(device.macAddress)
                        state.bleDevice = device
                        dumpScanResult(it)
                    }
                },
                { trySendThrowable(sink, it) }
            )
    }

    override fun scanOnCancel(id: Int, args: Any?) {
        stopScan()
    }

    override fun stopScan(call: MethodCall, result: MethodChannel.Result) {
        stopScan()
        result.success(null)
    }
}