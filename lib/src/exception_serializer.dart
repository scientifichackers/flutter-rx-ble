import 'package:flutter/services.dart';
import 'package:rx_ble/src/exceptions.dart';

final exceptionRegex = RegExp(
  r'(com\.polidea\.rxandroidble2\.exceptions\.)(\w+)',
);

void rethrowException(PlatformException e) {
  final code = exceptionRegex.firstMatch(e.code)?.group(2);
  final msg = e.message;
  final details = e.details;

  switch (code) {
    case "BleDisconnectedException":
      throw BleDisconnectedException(msg, details);
    case "BleGattException":
      throw BleGattException(msg, details);
    case "BleGattCallbackTimeoutException":
      throw BleGattCallbackTimeoutException(msg, details);
    case "BleCharacteristicNotFoundException":
      throw BleCharacteristicNotFoundException(msg, details);
    case "BleGattCannotStartException":
      throw BleGattCannotStartException(msg, details);
    default:
      throw e;
  }
}
