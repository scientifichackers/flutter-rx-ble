//
//  PermissionMethods.swift
//  rx_ble
//
//  Created by Dev Aggarwal on 18/05/19.
//

import CoreLocation
import Foundation
import plugin_scaffold
import RxBluetoothKit

enum AccessStatus: Int {
    case ok = 0, btDisabled, locDisabled, locDenied
}

class PermissionMethods: NSObject, CLLocationManagerDelegate {
    let manager: CentralManager
    let locationManager = CLLocationManager()
    var bluetoothIsOn = false
    var result: FlutterResult?

    init(_ manager: CentralManager) {
        self.manager = manager

        super.init()

        locationManager.delegate = self
        _ = manager.observeState().subscribe(onNext: { self.bluetoothIsOn = $0 == .poweredOn })
    }

    func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            result?(AccessStatus.ok.rawValue)
        default:
            result?(AccessStatus.locDenied.rawValue)
        }
    }

    func requestAccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if !CLLocationManager.locationServicesEnabled() {
            result(AccessStatus.locDisabled.rawValue)
            return
        }
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            self.result = result
            return
        case .restricted, .denied:
            result(AccessStatus.locDenied.rawValue)
            return
        default:
            break
        }
        if !bluetoothIsOn {
            result(AccessStatus.btDisabled.rawValue)
            return
        }
        result(AccessStatus.ok.rawValue)
    }

    func hasAccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let status = CLLocationManager.authorizationStatus()
        result(
            CLLocationManager.locationServicesEnabled()
                && (status == .authorizedWhenInUse || status == .authorizedAlways)
                && bluetoothIsOn
        )
    }
}
