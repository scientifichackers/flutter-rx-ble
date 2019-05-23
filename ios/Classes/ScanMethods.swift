//
// Created by Dev Aggarwal on 2019-05-18.
//

import Foundation
import plugin_scaffold
import RxBluetoothKit
import RxSwift

class ScanMethods: NSObject, FlutterStreamHandler {
    let manager: CentralManager
    var disposable: Disposable?
    var eventSink: FlutterEventSink?

    init(_ manager: CentralManager) {
        self.manager = manager
        super.init()
    }

    func _stopScan() {
        disposable?.dispose()
        disposable = nil
        eventSink?(FlutterEndOfEventStream)
        eventSink = nil
    }

    func startScan(_ deviceIdFilter: String?, _ deviceNameFilter: String?, _ eventSink: @escaping FlutterEventSink) {
        _stopScan()

        disposable = manager.scanForPeripherals(withServices: nil).subscribe(
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

                eventSink([
                    deviceName as Any,
                    deviceId,
                    $0.rssi as Any,
                    Int(Date().timeIntervalSince1970 * 1000),
                ])
            },
            onError: {
                trySendError(eventSink, $0)
            }
        )

        self.eventSink = eventSink
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        catchErrors(events) {
            let map = arguments as! [String: Any?]
            let deviceId = map["deviceId"] as? String
            let deviceName = map["deviceName"] as? String
            self.startScan(deviceId, deviceName, events)
        }
        return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
        _stopScan()
        return nil
    }

    func stopScan(call _: FlutterMethodCall, result: @escaping FlutterResult) {
        _stopScan()
        result(nil)
    }
}
