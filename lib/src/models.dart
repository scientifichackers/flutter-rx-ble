import 'package:rx_ble/rx_ble.dart';

enum AccessStatus {
  ok,

  /// bluetooth is disabled.
  bluetoothDisabled,

  /// location is disabled.
  locationDisabled,

  /// location permission denied by user.
  locationDenied,

  /// location permission denied by user,
  /// and "Never ask again" checkbox was ticked.
  ///
  /// In this case, the only way to acquire permission,
  /// is to make the user manually go to app settings,
  /// and enable the switch.
  ///
  /// You may use the utility method [RxBle.openAppSettings]
  /// to open the settings page programmatically.
  locationDeniedNeverAskAgain,

  /// Bluetooth is not available on this device
  bluetoothNotAvailable
}

enum ScanModes {
  /// A special Bluetooth LE scan mode. Applications using this scan mode will passively listen for
  /// other scan results without starting BLE scans themselves.
  opportunistic,

  /// Perform Bluetooth LE scan in low power mode. This is the default scan mode as it consumes the
  /// least power. This mode is enforced if the scanning application is not in foreground.
  lowPower,

  /// Perform Bluetooth LE scan in balanced power mode. Scan results are returned at a rate that
  /// provides a good trade-off between scan frequency and power consumption.
  balanced,

  /// Scan using highest duty cycle. It's recommended to only use this mode when the application is
  /// running in the foreground.
  lowLatency,
}

enum BleConnectionState { connecting, connected, disconnected, disconnecting }

enum ScanCallbackType {
  allMatches,
  firstMatch,
  matchLost,
  batch,
  unspecified,
  unknown
}

class ScanResult {
  final String deviceName, deviceId;
  final int rssi;
  final DateTime time;

  ScanResult.fromJson(List msg)
      : deviceName = msg[0],
        deviceId = msg[1],
        rssi = msg[2],
        time = DateTime.fromMillisecondsSinceEpoch(msg[3]);

  @override
  String toString() {
    return "ScanResult { deviceName: $deviceName, deviceId: $deviceId, rssi: $rssi, time: $time }";
  }
}
