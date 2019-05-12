import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:rx_ble/src/exception_serializer.dart';
import 'package:rx_ble/src/exceptions.dart';
import 'package:rx_ble/src/models.dart';

export 'package:rx_ble/src/exceptions.dart';
export 'package:rx_ble/src/models.dart';

/// A callback that allows showing a small message to user
/// explaining the need for the location permission.
///
/// This method should return a Boolean value,
/// indicating whether the library should continue
/// asking the user for permission or not.
typedef Future<bool> ShowLocationPermissionRationale();

const PKG_NAME = "com.pycampers.rx_ble";

class RxBle {
  static const channel = MethodChannel(PKG_NAME);
  static const scanChannel = EventChannel('$PKG_NAME/scan');
  static const connectChannel = EventChannel('$PKG_NAME/connect');

  static Future<dynamic> invokeMethod(String method, [args]) async {
    try {
      return await channel.invokeMethod(method, args);
    } on PlatformException catch (e) {
      rethrowException(e);
    }
  }

  /// Check if the app has all the necessary permissions, settings, etc.
  /// that are needed for the plugin to function.
  static Future<bool> hasAccess() async {
    return await invokeMethod("hasAccess");
  }

  /// Check if the app has all the necessary permissions, settings, etc.
  /// that are needed for the plugin to function.
  ///
  /// If necessary conditions are not met,
  /// request the user for any permissions/settings that are required,
  /// automatically.
  ///
  /// No need to call [hasAccess] when using this function.
  ///
  /// [showRationale] - (Optional but recommended)
  ///   A callback function that gets called when the
  ///   app should probably show a message explaining why it needs the permission,
  ///   since the user keeps denying the permission request!
  ///
  ///   It is left up-to the developer to show the message however they wish.
  ///   The default behavior is to continue asking user for permission anyway.
  ///
  ///   For more info, refer the [Android documentation](https://developer.android.com/training/permissions/requesting#explain).
  static Future<AccessStatus> requestAccess({
    ShowLocationPermissionRationale showRationale,
  }) async {
    int index;
    AccessStatus status;

    index = await invokeMethod("requestAccess");
    try {
      status = AccessStatus.values[index];
    } on RangeError {
      if (!(await showRationale?.call() ?? true)) {
        return AccessStatus.locationDenied;
      }
      index = await invokeMethod("requestLocPerm");
      status = AccessStatus.values[index];
    }

    return status;
  }

  static Future<void> openAppSettings() async {
    await invokeMethod("openAppSettings");
  }

  /// Returns an infinite [Stream] emitting BLE [ScanResult]s.
  ///
  /// Scanning can be stopped by either cancelling the [StreamSubscription],
  /// or by calling [stopScan].
  static Stream<ScanResult> startScan({
    ScanModes scanMode: ScanModes.lowPower,
    String name,
    String macAddress,
  }) {
    return scanChannel.receiveBroadcastStream({
      "scanMode": scanMode.index,
      "name": name,
      "macAddress": macAddress,
    }).map((event) {
      return ScanResult.fromJson(event);
    }).handleError((e) {
      rethrowException(e);
    });
  }

  /// Stops the Scan started by [startScan].
  static Future<void> stopScan() async {
    await invokeMethod("stopScan");
  }

  static Future<BleConnectionState> getConnectionState(
    String macAddress,
  ) async {
    return BleConnectionState
        .values[await RxBle.invokeMethod("getConnectionState", macAddress)];
  }

  /// Establish connection to the BLE device identified by [macAddress]
  /// and emit the [BleConnectionState] changes.
  ///
  ///
  /// In cases when the BLE device is _not_ available at the time of calling this function,
  /// enabling [waitForDevice] will make the framework wait for device to start advertising.
  ///
  ///
  /// [BleConnectionState] is just a convenience value for
  /// easy monitoring that may be useful in the UI.
  /// It is not meant to be a trigger for reconnecting to a
  /// particular device. For that, use the [BleException]s.
  ///
  ///
  /// Throws the following errors:
  ///   - [BleDisconnectedException]
  ///   - [BleGattException]
  ///   - [BleGattCallbackTimeoutException].
  ///
  /// Device can be disconnected by either cancelling the [StreamSubscription],
  /// or by calling [disconnect].
  ///
  /// [autoConnect] will catch [BleDisconnectedException],
  /// do a scan for the [macAddress], and connect automatically in background.
  ///
  ///
  /// It is mandatory that you perform a scan before issuing a connect request.
  /// In cases where the caller hasn't done a scan,
  /// and is loading the [macAddress] from say, local storage, the connect will fail.
  /// This can usually be solved using some simple dart [Stream] methods :-
  ///
  /// ```dart
  /// final scanResult = await RxBle.startScan(macAddress: "XX:XX:XX:XX:XX:XX")
  ///   .timeout(Duration(seconds: 5))
  ///   .first;
  /// ```
  ///
  /// This is done automatically when [autoConnect] is enabled.
  static Stream<BleConnectionState> connect(
    String macAddress, {
    bool waitForDevice: false,
    bool autoConnect: false,
    ScanModes scanMode: ScanModes.lowPower,
  }) async* {
    Future<void> scan() async {
      final scanStream =
          RxBle.startScan(macAddress: macAddress, scanMode: scanMode);
      await for (final _ in scanStream) break;
    }

    while (true) {
      if (autoConnect) {
        await scan();
      }

      final stream = RxBle.connectChannel.receiveBroadcastStream({
        "macAddress": macAddress,
        "waitForDevice": waitForDevice,
      }).map((it) {
        return BleConnectionState.values[it];
      }).handleError((e) {
        rethrowException(e);
      });

      try {
        await for (final state in stream) {
          yield state;
        }
      } on BleDisconnectedException {
        yield BleConnectionState.disconnected;
        if (!autoConnect) rethrow;
        await scan();
        continue;
      }

      yield BleConnectionState.disconnected;
      break;
    }
  }

  /// Disconnect with this device.
  static Future<void> disconnect() async {
    await RxBle.invokeMethod("disconnect");
  }

  /// Performs GATT read operation on a characteristic with given [uuid].
  ///
  /// Throws the following errors:
  ///   - [BleCharacteristicNotFoundException]
  ///   - [BleGattCannotStartException]
  ///   - [BleGattException].
  static Future<Uint8List> readChar(String macAddress, String uuid) async {
    return await RxBle.invokeMethod("readChar", {
      "macAddress": macAddress,
      "uuid": uuid,
    });
  }

  /// Performs GATT write operation on a characteristic with given [uuid] and [value].
  ///
  /// Throws the following errors:
  ///   - [BleCharacteristicNotFoundException]
  ///   - [BleGattCannotStartException]
  ///   - [BleGattException].
  static Future<Uint8List> writeChar(
    String macAddress,
    String uuid,
    Uint8List value,
  ) async {
    return await RxBle.invokeMethod("writeChar", {
      "macAddress": macAddress,
      "uuid": uuid,
      "value": value,
    });
  }

  /// Performs GATT MTU (Maximum Transfer Unit) request.
  ///
  /// Timeouts after 10 seconds.
  ///
  /// Throws the following errors:
  ///   - [BleGattCannotStartException]
  ///   - [BleGattException]
  static Future<int> requestMtu(String macAddress, int value) async {
    return await RxBle.invokeMethod("requestMtu", {
      "macAddress": macAddress,
      "value": value,
    });
  }

  /// Converts characteristic value returned by [readChar] into utf-8 [String],
  /// By removing zeros (null value) and trimming leading and trailing whitespace.
  static String charToString(Uint8List value) {
    return utf8.decode(value.where((it) => it != 0).toList()).trim();
  }

  /// Converts utf-8 string to  characteristic value
  static Uint8List stringToChar(String value) {
    return utf8.encode(value);
  }
}
