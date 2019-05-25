//
// Created by Dev Aggarwal on 2019-05-19.
//

import Foundation
import plugin_scaffold
import RxBluetoothKit
import RxSwift

class ConnectMethods: NSObject {
    func getCharObservable(_ serviceObservable: Observable<[Service]>) -> Observable<Characteristic> {
        return serviceObservable
            .flatMap { Observable.from($0) }
            .flatMap { $0.discoverCharacteristics(nil) }.asObservable()
            .flatMap { Observable.from($0) }
    }

    func onListen(id: Int, args: Any?, sink: @escaping FlutterEventSink) throws {
        let map = args as! [String: Any?]
        let deviceId = map["deviceId"] as! String
        let state = getDeviceState(deviceId)
        let peripheral = try getPeripheral(deviceId)

        state.disconnect()

        let serviceObservable = peripheral.establishConnection().flatMap { $0.discoverServices(nil) }.asObservable()
        state.connectDisposable = getCharObservable(serviceObservable)
            .subscribe(
                onNext: { putCharInCache(deviceId, $0) },
                onError: { trySendError(sink, $0) },
                onDisposed: { sink(FlutterEndOfEventStream) }
            )
        state.stateDisposable = peripheral.observeConnection().subscribe(
            onNext: { sink($0 ? 1 : 2) },
            onError: { trySendError(sink, $0) },
            onDisposed: { sink(FlutterEndOfEventStream) }
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
                onDisposed: { trySend(result) { chars } }
            )
    }
}
