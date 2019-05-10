/// base class for all BLE exceptions
class BleException implements Exception {
  final String message, details;

  BleException(this.message, this.details);

  @override
  String toString() {
    return "$runtimeType: $message\n$details";
  }
}

/// emitted when the BLE link has been disconnected either when the connection
///  was already established or was in pending connection state. This occurs when the
///  connection was released as a part of expected behavior.
class BleDisconnectedException extends BleException {
  BleDisconnectedException(String message, String details) : super(message, details);
}

/// emitted when the BLE link has been interrupted as a result of an error.
/// The exception contains detailed explanation of the error source (type of operation) and
/// the code proxied from the Android system.
class BleGattException extends BleException {
  BleGattException(String message, String details) : super(message, details);
}

/// emitted when an internal timeout for connection has been reached. The operation will
/// timeout in direct mode (autoConnect = false) after 35 seconds.
class BleGattCallbackTimeoutException extends BleException {
  BleGattCallbackTimeoutException(String message, String details)
      : super(message, details);
}

/// An exception being emitted from any RxBleConnection function
/// that accepts UUID in case the said
/// UUID is not found in the discovered device
class BleCharacteristicNotFoundException extends BleException {
  BleCharacteristicNotFoundException(String message, String details)
      : super(message, details);
}

/// An exception emitted from RxBleConnection functions when the underlying
/// BluetoothGatt returns [false] from BluetoothGatt.readRemoteRssi()
/// or other functions associated with device interaction
class BleGattCannotStartException extends BleException {
  BleGattCannotStartException(String message, String details) : super(message, details);
}

class BleScanException extends BleException {
  BleScanException(String message, String details) : super(message, details);
}

class IllegalArgumentException extends BleException {
  IllegalArgumentException(String message, String details) : super(message, details);
}

class BleGattCharacteristicException extends BleException {
  BleGattCharacteristicException(String message, String details)
      : super(message, details);
}
