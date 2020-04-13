#import "RxBlePlugin.h"
#if __has_include(<rx_ble/rx_ble-Swift.h>)
#import <rx_ble/rx_ble-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "rx_ble-Swift.h"
#endif

@implementation RxBlePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRxBlePlugin registerWithRegistrar:registrar];
}
@end
