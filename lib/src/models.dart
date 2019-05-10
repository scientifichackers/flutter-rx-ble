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
  locationDeniedNeverAskAgain
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
  final String name, macAddress;
  final int rssi;
  final DateTime time;
  final ScanCallbackType callbackType;

  ScanResult.fromJson(List msg)
      : name = msg[0],
        macAddress = msg[1],
        rssi = msg[2],
        time = DateTime.fromMillisecondsSinceEpoch(msg[3]),
        callbackType = ScanCallbackType.values[msg[4]];

  @override
  String toString() {
    return "ScanResult { name: $name, macAddress: $macAddress, rssi: $rssi, time: $time }";
  }
}
