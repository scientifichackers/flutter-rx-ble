//
// Created by Dev Aggarwal on 2019-05-18.
//

import Foundation
import RxBluetoothKit
import RxSwift
import plugin_scaffold

class ScanMethods: NSObject, FlutterStreamHandler {
    static let manager = CentralManager(queue: .main)

    let channel: FlutterEventChannel
    var disposable: Disposable?
    var eventSink: FlutterEventSink?

    init(_ messenger: FlutterBinaryMessenger) {
        channel = FlutterEventChannel(name: pkgName + "/scan", binaryMessenger: messenger)
        super.init()
        channel.setStreamHandler(self)
    }

    func _stopScan() {
        disposable?.dispose()
        disposable = nil
        eventSink?(FlutterEndOfEventStream)
        eventSink = nil
    }

    func startScan(_ macAddress: String?, _ name: String?, _ events: @escaping FlutterEventSink) {
        _stopScan()

        disposable = ScanMethods.manager.scanForPeripherals(withServices: nil).subscribe({ item in
            trySend(events) {
                if let error = item.error {
                    throw error
                }
                return nil
            }
        })

        eventSink = events
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        catchErrors(events, {
            let map = arguments as! [String: Any?]
            self.startScan(map["macAddress"] as! String?, map["name"] as! String?, events)
        })
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        _stopScan()
        return nil
    }


    func stopScan(call: FlutterMethodCall, result: @escaping FlutterResult) {
        _stopScan()
        result(nil)
    }
}
