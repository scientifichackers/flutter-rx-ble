//
// Created by Dev Aggarwal on 2019-05-19.
//

import Foundation
import plugin_scaffold
import RxBluetoothKit
import RxSwift

class ConnectMethods: NSObject, FlutterStreamHandler {
    var charCache = [String: Characteristic]()

    func putCharInCache(_ deviceId: String, _ char: Characteristic) {
        let key = deviceId + char.uuid.uuidString
        charCache[key] = char
    }

    func getCharFromCache(_ deviceId: String, _ uuid: String) throws -> Characteristic {
        let key = deviceId + uuid
        guard let char = charCache[key] else { throw Errors.charNotFound }
        return char
    }

    func _disconnect(_ deviceId: String) {
        if let d = devices[deviceId] {
            d.connectDisposable?.dispose()
            d.connectDisposable = nil
            d.stateDisposable?.dispose()
            d.stateDisposable = nil
            d.eventSink?(FlutterEndOfEventStream)
            d.eventSink = nil
        }
    }

    func getCharObservable(_ serviceObservable: Observable<[Service]>) -> Observable<Characteristic> {
        return serviceObservable
            .flatMap { Observable.from($0) }
            .flatMap { $0.discoverCharacteristics(nil) }.asObservable()
            .flatMap { Observable.from($0) }
    }

    func connect(_ deviceId: String, _ eventSink: @escaping FlutterEventSink) throws {
        _disconnect(deviceId)

        let state = getDeviceState(deviceId)
        let peripheral = try getPeripheral(deviceId)

        let serviceObservable = peripheral.establishConnection().flatMap { $0.discoverServices(nil) }.asObservable()

        state.connectDisposable = getCharObservable(serviceObservable)
            .subscribe(
                onNext: { self.putCharInCache(deviceId, $0) },
                onError: { trySendError(eventSink, $0) }
            )

        state.stateDisposable = peripheral.observeConnection().subscribe(
            onNext: { connected in trySend(eventSink) { return connected ? 1 : 2 } },
            onError: { trySendError(eventSink, $0) }
        )

        state.eventSink = eventSink
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        catchErrors(events) {
            let map = arguments as! [String: Any?]
            let deviceId = map["deviceId"] as! String
            try self.connect(deviceId, events)
        }
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        let map = arguments as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        _disconnect(deviceId)
        return nil
    }

    func disconnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let deviceId = call.arguments as? String {
            _disconnect(deviceId)
        } else {
            for it in devices.keys { _disconnect(it) }
        }
        result(nil)
    }

    func discoverChars(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        var chars = [String: [String]]()
        let deviceId = call.arguments as! String
        let peripheral = try getPeripheral(deviceId)
        let serviceObservable = peripheral.discoverServices(nil).asObservable()

        _ = getCharObservable(serviceObservable)
            .subscribe(
                onNext: {
                    let serviceId = $0.service.uuid.uuidString
                    let charId = $0.uuid.uuidString
                    if chars[serviceId] == nil {
                        chars[serviceId] = []
                    }
                    chars[serviceId]?.append(charId)
                },
                onError: { trySendError(result, $0) },
                onCompleted: { trySend(result) { chars } }
            )
    }

    func getConnectionState(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        let deviceId = call.arguments as! String
        let peripheral = try getPeripheral(deviceId)

        trySend(result) {
            switch peripheral.state {
            case .connecting:
                return 0
            case .connected:
                return 1
            case .disconnected:
                return 2
            case .disconnecting:
                return 3
            }
        }
    }

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
}
