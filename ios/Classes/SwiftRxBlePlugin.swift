import Flutter
import plugin_scaffold
import RxBluetoothKit
import RxSwift
import UIKit

let pkgName = "com.pycampers.rx_ble"

class DeviceState {
    var connectDisposable: Disposable?
    var stateDisposable: Disposable?
    var eventSink: FlutterEventSink?
    var peripheral: Peripheral?
}

enum Errors: Error {
    case deviceNotInitialized, charNotFound
}

var devices: [String: DeviceState] = [:]

func getPeripheral(_ deviceId: String) throws -> Peripheral {
    if let peripheral = devices[deviceId]?.peripheral {
        return peripheral
    }
    throw Errors.deviceNotInitialized
}

func getDeviceState(_ deviceId: String) -> DeviceState {
    if let state = devices[deviceId] {
        return state
    }
    let deviceState = DeviceState()
    devices[deviceId] = deviceState
    return deviceState
}

public class SwiftRxBlePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let manager = CentralManager(queue: .main)
        let permissionMethods = PermissionMethods(manager)
        let scanMethods = ScanMethods(manager)
        let connectMethods = ConnectMethods()
        let notifyMethods = NotifyMethods(connectMethods)

        _ = createPluginScaffold(messenger: messenger, channelName: pkgName, methodMap: [
            "requestAccess": permissionMethods.requestAccess,
            "hasAccess": permissionMethods.hasAccess,
            "stopScan": scanMethods.stopScan,
            "disconnect": connectMethods.disconnect,
            "getConnectionState": connectMethods.getConnectionState,
            "discoverChars": connectMethods.discoverChars,
            "readChar": connectMethods.readChar,
            "writeChar": connectMethods.writeChar,
        ], eventMap: [
            "scan": scanMethods,
            "connect": connectMethods,
            "notify": notifyMethods,
        ])
    }

    public func handle(_: FlutterMethodCall, result: @escaping FlutterResult) {
        result("iOS " + UIDevice.current.systemVersion)
    }
}
