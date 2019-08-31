//
// Created by Dev Aggarwal on 2019-05-18.
//

import Foundation
import plugin_scaffold
import CoreBluetooth
import RxBluetoothKit
import RxSwift

class ScanMethods: NSObject {
    let manager: CentralManager
    var disposable: Disposable?

    init(_ manager: CentralManager) {
        self.manager = manager
        super.init()
    }

    func _stopScan() {
        disposable?.dispose()
        disposable = nil
    }

    func onListen(id: Int, args: Any?, sink: @escaping FlutterEventSink) {
        let map = args as! [String: Any?]
        let deviceIdFilter = map["deviceId"] as? String
        let deviceNameFilter = map["deviceName"] as? String
        let serviceFilter = map["service"] as? String
        let services: [CBUUID]? =
            serviceFilter != nil ? [CBUUID(string: map["service"] as! String)] : nil

        _stopScan()

        disposable = manager.scanForPeripherals(withServices: services).subscribe(
            onNext: {
                let peripheral = $0.peripheral
                let deviceName = peripheral.name
                let deviceId = peripheral.identifier.uuidString
                let state = getDeviceState(deviceId)
                state.peripheral = peripheral

                if (deviceIdFilter != nil && deviceIdFilter != deviceId)
                    || (deviceNameFilter != nil && deviceNameFilter != deviceName) {
                    return
                }

                sink([
                    deviceName as Any,
                    deviceId,
                    $0.rssi as Any,
                    Int(Date().timeIntervalSince1970 * 1000),
                ])
            },
            onError: { trySendError(sink, $0) },
            onDisposed: { sink(FlutterEndOfEventStream) }
        )
    }

    func onCancel(id: Int, args: Any?) {
        _stopScan()
    }

    func stopScan(call _: FlutterMethodCall, result: @escaping FlutterResult) {
        _stopScan()
        result(nil)
    }
}
