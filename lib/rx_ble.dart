import 'dart:async';

import 'package:flutter/services.dart';

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

/// A callback that allows showing a small message to user
/// explaining the need for the location permission.
///
/// This method should return a Boolean value,
/// indicating whether the library should continue
/// asking the user for permission or not.
typedef Future<bool> ShowLocationPermissionRationale();

class RxBle {
  static const channel = MethodChannel('rx_ble');

  /// Check if the app has all the necessary permissions, settings, etc.
  /// that are needed for the plugin to function.
  static Future<bool> hasAccess() async {
    return await channel.invokeMethod("hasAccess");
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
  /// [showRationale] -
  ///   A callback function that gets called when the
  ///   app should probably show a message explaining why it needs the permission,
  ///   since the user keeps denying the permission request!
  ///
  ///   It is left up-to the developer to show the message however they wish.
  ///   The default behavior is to continue asking user for permission anyway.
  ///
  ///   For more info, refer the Android docs here:
  ///     https://developer.android.com/training/permissions/requesting#explain
  static Future<AccessStatus> requestAccess({
    ShowLocationPermissionRationale showRationale,
  }) async {
    int index;
    AccessStatus status;

    index = await channel.invokeMethod("requestAccess");
    try {
      status = AccessStatus.values[index];
    } on RangeError {
      if (!(await showRationale?.call() ?? true)) {
        return AccessStatus.locationDenied;
      }
      index = await channel.invokeMethod("requestLocPerm");
      status = AccessStatus.values[index];
    }

    return status;
  }

  static Future<void> openAppSettings() async {
    await channel.invokeMethod("openAppSettings");
  }
}
