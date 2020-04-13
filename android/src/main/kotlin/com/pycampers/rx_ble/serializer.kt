package com.pycampers.rx_ble

import android.os.SystemClock
import com.polidea.rxandroidble2.scan.ScanResult

fun dumpScanResult(result: ScanResult): List<*> {
    return result.run {
        listOf(
                bleDevice.name,
                bleDevice.macAddress,
                rssi,
                (System.currentTimeMillis() - SystemClock.elapsedRealtime() + timestampNanos / 1e6).toLong()
        )
    }
}
