import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:plugin_scaffold/plugin_scaffold.dart';
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

class RxBle {
  static const pkgName = "com.pycampers.rx_ble";
  static const channel = MethodChannel(pkgName);

  static Future<dynamic> invokeMethod(String method, [dynamic args]) async {
    try {
      return await channel.invokeMethod(method, args);
    } catch (e) {
      rethrowException(e);
    }
  }

  static final uuidRegex = RegExp(
    '(0000)([0-9A-z]{4})(-0000-1000-8000-00805f9b34fb)',
  );

  static String encodeUUID(String uuid) {
    if (Platform.isAndroid && uuid.length == 4) {
      return "0000${uuid.toLowerCase()}-0000-1000-8000-00805f9b34fb";
    }
    return uuid;
  }

  static String decodeUUID(String uuid) {
    if (Platform.isAndroid) {
      return uuidRegex.firstMatch(uuid)?.group(2)?.toUpperCase() ?? uuid;
    }
    return uuid;
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
      // app should show location permission rationale to user
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
    String deviceName,
    String deviceId,
    String service,
  }) {
    return PluginScaffold.createStream(channel, "scan", {
      "scanMode": scanMode.index,
      "deviceName": deviceName,
      "deviceId": deviceId,
      "service": service,
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
    String deviceId,
  ) async {
    return BleConnectionState
        .values[await RxBle.invokeMethod("getConnectionState", deviceId)];
  }

  /// Establish connection to the BLE device identified by [deviceId]
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
  /// do a scan for the [deviceId], and connect automatically in background.
  ///
  ///
  /// It is mandatory that you perform a scan before issuing a connect request.
  /// In cases where the caller hasn't done a scan,
  /// and is loading the [deviceId] from say, local storage, the connect will fail.
  /// This can usually be solved using some simple dart [Stream] methods :-
  ///
  /// ```dart
  /// final scanResult = await RxBle.startScan(deviceId: "XX:XX:XX:XX:XX:XX")
  ///   .timeout(Duration(seconds: 5))
  ///   .first;
  /// ```
  ///
  /// This is done automatically when [autoConnect] is enabled.
  static Stream<BleConnectionState> connect(
    String deviceId, {
    bool waitForDevice: false,
    bool autoConnect: false,
    ScanModes scanMode: ScanModes.lowPower,
  }) async* {
    Future<void> doScan() async {
      final scanStream =
          RxBle.startScan(deviceId: deviceId, scanMode: scanMode);
      await for (final _ in scanStream) break;
    }

    while (true) {
      if (autoConnect) {
        await doScan();
      }

      final stream = PluginScaffold.createStream(channel, "connect", {
        "deviceId": deviceId,
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
        continue;
      }

      yield BleConnectionState.disconnected;
      break;
    }
  }

  /// Disconnect with the device with [deviceId].
  ///
  /// If [deviceId] is not provided,
  /// then all previously connected devices are disconnected.
  static Future<void> disconnect({String deviceId}) async {
    await RxBle.invokeMethod("disconnect", deviceId);
  }

  static Future<Map<String, List<String>>> discoverChars(
    String deviceId,
  ) async {
    final value = await RxBle.invokeMethod("discoverChars", deviceId);
    return Map<String, List<String>>.from(
      value.map((k, v) {
        return MapEntry(
          decodeUUID(k),
          List<String>.from(
            v.map((it) {
              return decodeUUID(it);
            }),
          ),
        );
      }),
    );
  }

  /// Performs GATT read operation on a characteristic with given [uuid].
  ///
  /// Throws the following errors:
  ///   - [BleCharacteristicNotFoundException]
  ///   - [BleGattCannotStartException]
  ///   - [BleGattException].
  static Future<Uint8List> readChar(String deviceId, String uuid) async {
    return await RxBle.invokeMethod("readChar", {
      "deviceId": deviceId,
      "uuid": encodeUUID(uuid),
    });
  }

  /// Set up BLE notifications,
  /// and emit the changes in the characteristic with the given [uuid].
  static Stream<Uint8List> observeChar(String deviceId, String uuid) {
    return PluginScaffold.createStream(channel, "observeChar", {
      "deviceId": deviceId,
      "uuid": encodeUUID(uuid),
    }).map((it) {
      return it as Uint8List;
    }).handleError((e) {
      rethrowException(e);
    });
  }

  /// Performs GATT write operation on a characteristic with given [uuid] and [value].
  ///
  /// Throws the following errors:
  ///   - [BleCharacteristicNotFoundException]
  ///   - [BleGattCannotStartException]
  ///   - [BleGattException].
  static Future<Uint8List> writeChar(
    String deviceId,
    String uuid,
    Uint8List value,
  ) async {
    return await RxBle.invokeMethod("writeChar", {
      "deviceId": deviceId,
      "uuid": encodeUUID(uuid),
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
  static Future<int> requestMtu(String deviceId, int value) async {
    return await RxBle.invokeMethod("requestMtu", {
      "deviceId": deviceId,
      "value": value,
    });
  }

  /// Converts characteristic value returned by [readChar] into utf-8 [String],
  /// By removing zeros (null value) and trimming leading and trailing whitespace.
  static String charToString(Uint8List value, {bool allowMalformed: false}) {
    return utf8
        .decode(
          value.where((it) => it != 0).toList(),
          allowMalformed: allowMalformed,
        )
        .trim();
  }

  /// Converts utf-8 string to  characteristic value
  static Uint8List stringToChar(String value) {
    return utf8.encode(value);
  }
}
