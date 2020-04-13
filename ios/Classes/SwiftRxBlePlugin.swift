import Flutter
import plugin_scaffold
import RxBluetoothKit
import RxSwift
import UIKit

let pkgName = "com.pycampers.rx_ble"

public class SwiftRxBlePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let manager = CentralManager(queue: .main)
    let permissionMethods = PermissionMethods(manager)
    let scanMethods = ScanMethods(manager)
    let connectMethods = ConnectMethods()
    let readWriteMethods = ReadWriteMethods()

    _ = createPluginScaffold(messenger: messenger, channelName: pkgName, methodMap: [
        "requestAccess": permissionMethods.requestAccess,
        "hasAccess": permissionMethods.hasAccess,
        "stopScan": scanMethods.stopScan,
        "disconnect": connectMethods.disconnect,
        "getConnectionState": connectMethods.getConnectionState,
        "discoverChars": connectMethods.discoverChars,
        "readChar": readWriteMethods.readChar,
        "writeChar": readWriteMethods.writeChar,
        "scanOnListen": scanMethods.onListen,
        "scanOnCancel": scanMethods.onCancel,
        "connectOnListen": connectMethods.onListen,
        "connectOnCancel": connectMethods.onCancel,
        "observeCharOnListen": readWriteMethods.onListen,
        "observeCharOnCancel": readWriteMethods.onCancel
    ])
  }
}

class DeviceState {
    var disposable: Disposable?
    var peripheral: Peripheral?

    func disconnect() {
        disposable?.dispose()
        disposable = nil
    }
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

