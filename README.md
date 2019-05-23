[![Sponsor](https://img.shields.io/badge/Sponsor-jaaga_labs-red.svg?style=for-the-badge)](https://www.jaaga.in/labs) [![pub package](https://img.shields.io/pub/v/rx_ble.svg?style=for-the-badge)](https://pub.dartlang.org/packages/rx_ble)

# Flutter Rx BLE

A Flutter BLE plugin, based on the wonderful [RxAndroidBle](https://github.com/Polidea/RxAndroidBle) and [RxBluetoothKit](https://github.com/Polidea/RxBluetoothKit) libraries.

### Batteries included.

- Acquire every permission and setting required for Bluetooth access, using a _single_ method - `RxBle.requestAccess()`.
- No need to manually discover BLE services.
- Automatically queue up GATT requests to avoid race conditions.
