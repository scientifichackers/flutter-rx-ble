//
//  ReadWriteMethods.swift
//  rx_ble
//
//  Created by Dev Aggarwal on 21/05/19.
//

import Foundation
import plugin_scaffold
import RxBluetoothKit
import RxSwift

class ReadWriteMethods: NSObject {
    var disposables = [Int: Disposable]()
    
    func sendSingle<T>(_ single: Single<T>, _ result: @escaping FlutterResult, _ serializer: @escaping (T) -> Any?) {
        _ = single.subscribe(
            onSuccess: { it in trySend(result) { serializer(it) } },
            onError: { trySendError(result, $0) }
        )
    }
    
    func readChar(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        let map = call.arguments as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let uuid = map["uuid"] as! String
        let peripheral = try getPeripheral(deviceId)
        let char = try getCharFromCache(deviceId, uuid)
        
        sendSingle(peripheral.readValue(for: char), result) {
            FlutterStandardTypedData(bytes: $0.value ?? Data())
        }
    }
    
    func writeChar(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        let map = call.arguments as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let uuid = map["uuid"] as! String
        let value = map["value"] as! FlutterStandardTypedData
        let peripheral = try getPeripheral(deviceId)
        let char = try getCharFromCache(deviceId, uuid)
        
        sendSingle(peripheral.writeValue(value.data, for: char, type: .withResponse), result) {
            FlutterStandardTypedData(bytes: $0.value ?? Data())
        }
    }
    
    func onListen(id: Int, args: Any?, sink: @escaping FlutterEventSink) throws {
        let map = args as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let uuid = map["uuid"] as! String
        let peripheral = try getPeripheral(deviceId)
        let char = try getCharFromCache(deviceId, uuid)
        
        disposables[id] = peripheral
            .observeValueUpdateAndSetNotification(for: char)
            .subscribe(
                onNext: { char in trySend(sink) { FlutterStandardTypedData(bytes: char.value ?? Data()) } },
                onError: { trySendError(sink, $0) },
                onDisposed: { sink(FlutterEndOfEventStream) }
        )
    }
    
    func onCancel(id: Int, args: Any?) {
        disposables[id]?.dispose()
        disposables.removeValue(forKey: id)
    }
}
