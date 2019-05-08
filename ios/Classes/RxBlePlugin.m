#import "RxBlePlugin.h"
#import <rx_ble/rx_ble-Swift.h>

@implementation RxBlePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftRxBlePlugin registerWithRegistrar:registrar];
}
@end
