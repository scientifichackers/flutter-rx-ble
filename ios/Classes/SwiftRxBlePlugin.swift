import Flutter
import UIKit
import plugin_scaffold

let pkgName = "com.pycampers.rx_ble";

public class SwiftRxBlePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let scanMethods = ScanMethods(messenger)
        let permissionMethods = PermissionMethods()
        createMethodChannel(
                name: pkgName,
                messenger: messenger,
                funcMap: [
                    "stopScan": scanMethods.stopScan,
                    "requestAccess": permissionMethods.requestAccess,
                    //            "hasAccess":
                ]
        )
        let connectChannel = FlutterEventChannel(name: pkgName + "/connect", binaryMessenger: messenger)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        result("iOS " + UIDevice.current.systemVersion)
    }
}
