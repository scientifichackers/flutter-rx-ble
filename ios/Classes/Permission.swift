//
//  Permission.swift
//  rx_ble
//
//  Created by Dev Aggarwal on 18/05/19.
//

import Foundation
import CoreLocation
import plugin_scaffold


enum AccessStatus: Int {
    case ok = 0, btDisabled, locDisabled, locDenied, locDeniedNeverAskAgain, locDeniedShowPermissionRationale
}

class PermissionMethods: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    var result: FlutterResult?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .restricted, .denied, .notDetermined:
            self.result?(AccessStatus.locDenied.rawValue)
            break
        case .authorizedWhenInUse, .authorizedAlways:
            self.result?(AccessStatus.ok.rawValue)
            break
        }
    }

    func requestAccess(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if !CLLocationManager.locationServicesEnabled() {
            result(AccessStatus.locDisabled.rawValue)
            return
        }
        if ScanMethods.manager.state != .poweredOn {
            result(AccessStatus.btDisabled.rawValue)
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
        result(AccessStatus.ok.rawValue)
    }

}