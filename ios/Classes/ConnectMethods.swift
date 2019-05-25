//
// Created by Dev Aggarwal on 2019-05-19.
//

import Foundation
import plugin_scaffold
import RxBluetoothKit
import RxSwift

typealias CharMap = [String: [Characteristic]]

class ConnectMethods: NSObject {
    func getCharObservable(_ peripheral: Peripheral) -> Observable<Characteristic> {
        return peripheral
            .discoverServices(nil).asObservable()
            .flatMap { Observable.from($0) }
            .flatMap { $0.discoverCharacteristics(nil) }.asObservable()
            .flatMap { Observable.from($0) }
    }

    func _discoverChars(_ peripheral: Peripheral, onSuccess: @escaping (CharMap) -> Void, onError: @escaping (Error) -> Void) {
        var chars = CharMap()
        _ = getCharObservable(peripheral).subscribe(
            onNext: {
                let serviceId = $0.service.uuid.uuidString
                if chars[serviceId] == nil {
                    chars[serviceId] = []
                }
                chars[serviceId]?.append($0)
            },
            onError: { onError($0) },
            onDisposed: { onSuccess(chars) }
        )
    }

    func onListen(id: Int, args: Any?, sink: @escaping FlutterEventSink) throws {
        let map = args as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let state = getDeviceState(deviceId)
        let peripheral = try getPeripheral(deviceId)

        state.disconnect()
        
        let stateDisposable = peripheral.observeConnection().subscribe(
            onNext: {
                if $0 {
                    self._discoverChars(
                        peripheral,
                        onSuccess: {
                            for chars in $0.values {
                                for char in chars {
                                    charCache[deviceId + char.uuid.uuidString] = char
                                }
                            }
                            sink(1)
                        },
                        onError: { trySendError(sink, $0) }
                    )
                } else {
                    sink(2)
                }
            },
            onError: { trySendError(sink, $0) }
        )
        
        state.disposable = peripheral.establishConnection().subscribe(
            onError: { trySendError(sink, $0) },
            onDisposed: {
                sink(FlutterEndOfEventStream)
                stateDisposable.dispose()
            }
        )
    }

    func onCancel(id: Int, args: Any?) {
        let map = args as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        devices[deviceId]?.disconnect()
    }

    func disconnect(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let deviceId = call.arguments as? String {
            devices[deviceId]?.disconnect()
        } else {
            for it in devices.values {
                it.disconnect()
            }
        }
        result(nil)
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

    func discoverChars(call: FlutterMethodCall, result: @escaping FlutterResult) throws {
        let deviceId = call.arguments as! String
        let peripheral = try getPeripheral(deviceId)

        _discoverChars(
            peripheral,
            onSuccess: {
                chars in trySend(result) {
                    chars.mapValues { $0.map { $0.uuid.uuidString } }
                }
            },
            onError: { trySendError(result, $0) }
        )
    }
}
