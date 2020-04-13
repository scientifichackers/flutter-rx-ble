[![Sponsor](https://img.shields.io/badge/Sponsor-jaaga_labs-red.svg?style=for-the-badge)](https://www.jaaga.in/labs) [![pub package](https://img.shields.io/pub/v/rx_ble.svg?style=for-the-badge)](https://pub.dartlang.org/packages/rx_ble)

# Flutter Rx BLE

A Flutter BLE plugin, based on the wonderful [RxAndroidBle](https://github.com/Polidea/RxAndroidBle) and [RxBluetoothKit](https://github.com/Polidea/RxBluetoothKit) libraries.

### Batteries included.

- Acquire every permission and setting required for Bluetooth access, using a _single_ method - `RxBle.requestAccess()`.
- No need to manually discover BLE services.
- Automatically queues up GATT requests to avoid race conditions.


## Installation

### iOS

1. Open iOS module in XCode
2. Edit `Info.plist`
3. Right click > Enable show Raw Keys/Values
4. Add these entries
    - `NSBluetoothAlwaysUsageDescription` = `Please enable location to continue.`
    - `NSLocationWhenInUseUsageDescription` = `Please enable location to continue.`
    - `NSBluetoothPeripheralUsageDescription` = `Please enable bluetooth to continue.`

Or, you may add these entries maually using your editor of choice:

```plist
<dict>
    ...

    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Please enable location to continue.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>Please enable location to continue.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Please enable bluetooth to continue.</string>
</dict>
```