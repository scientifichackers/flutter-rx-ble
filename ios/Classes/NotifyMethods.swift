//
//  NotifyMethods.swift
//  rx_ble
//
//  Created by Dev Aggarwal on 21/05/19.
//

import Foundation
import plugin_scaffold
import RxBluetoothKit
import RxSwift

class NotifyMethods: NSObject, FlutterStreamHandler {
    var disposables = [String: Disposable]()
    let connectMethods: ConnectMethods
    
    init(_ connectMethods: ConnectMethods) {
        self.connectMethods = connectMethods
        super.init()
    }
    
    func startNotify(_ deviceId: String, _ uuid: String, _ eventSink: @escaping FlutterEventSink) throws {
        let peripheral = try getPeripheral(deviceId)
        let char = try connectMethods.getCharFromCache(deviceId, uuid)
        let key = deviceId + uuid
        
        disposables[key] = peripheral
            .observeValueUpdateAndSetNotification(for: char)
            .subscribe(
                onNext: { char in trySend(eventSink) { FlutterStandardTypedData(bytes: char.value ?? Data()) } },
                onError: { trySendError(eventSink, $0) },
                onDisposed: { trySend(eventSink) { FlutterEndOfEventStream } }
            )
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let map = arguments as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let uuid = map["uuid"] as! String
        do {
            try startNotify(deviceId, uuid, events)
        } catch {
            return serializeError(error)
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let map = arguments as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let uuid = map["uuid"] as! String
        let key = deviceId + uuid
        disposables[key]?.dispose()
        disposables.removeValue(forKey: key)
        return nil
    }
}
