/// base class for all BLE exceptions
abstract class BleException implements Exception {
  final String msg, details;

  BleException(this.msg, this.details);

  @override
  String toString() {
    return "$runtimeType: $msg\n$details";
  }
}

/// emitted when the BLE link has been disconnected either when the connection
///  was already established or was in pending connection state. This occurs when the
///  connection was released as a part of expected behavior.
class BleDisconnectedException extends BleException {
  BleDisconnectedException(String msg, String details) : super(msg, details);
}

/// emitted when the BLE link has been interrupted as a result of an error.
/// The exception contains detailed explanation of the error source (type of operation) and
/// the code proxied from the Android system.
class BleGattException extends BleException {
  BleGattException(String msg, String details) : super(msg, details);
}

/// emitted when an internal timeout for connection has been reached. The operation will
/// timeout in direct mode (autoConnect = false) after 35 seconds.
class BleGattCallbackTimeoutException extends BleException {
  BleGattCallbackTimeoutException(String msg, String details)
      : super(msg, details);
}

/// An exception being emitted from any RxBleConnection function
/// that accepts UUID in case the said
/// UUID is not found in the discovered device
class BleCharacteristicNotFoundException extends BleException {
  BleCharacteristicNotFoundException(String msg, String details)
      : super(msg, details);
}

/// An exception emitted from RxBleConnection functions when the underlying
/// BluetoothGatt returns [false] from BluetoothGatt.readRemoteRssi()
/// or other functions associated with device interaction
class BleGattCannotStartException extends BleException {
  BleGattCannotStartException(String msg, String details) : super(msg, details);
}
