import 'package:flutter/services.dart';
import 'package:rx_ble/src/exceptions.dart';

final exceptionRegex = RegExp(
  r'(com\.polidea\.rxandroidble2\.exceptions\.|java\.lang\.)(\w+)',
);

void rethrowException(e) {
  if (e is! PlatformException) throw e;

  final code = exceptionRegex.firstMatch(e.code)?.group(2);
  final message = e.message;
  final details = e.details;

  switch (code) {
    case "BleDisconnectedException":
      throw BleDisconnectedException(message, details);
    case "BleGattException":
      throw BleGattException(message, details);
    case "BleGattCallbackTimeoutException":
      throw BleGattCallbackTimeoutException(message, details);
    case "BleCharacteristicNotFoundException":
      throw BleCharacteristicNotFoundException(message, details);
    case "BleGattCharacteristicException":
      throw BleGattCharacteristicException(message, details);
    case "BleGattCannotStartException":
      throw BleGattCannotStartException(message, details);
    case "BleScanException":
      throw BleScanException(message, details);
    case "IllegalArgumentException":
      throw IllegalArgumentException(message, details);
    default:
      throw e;
  }
}
