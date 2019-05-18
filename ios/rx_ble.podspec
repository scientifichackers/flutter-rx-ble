#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'rx_ble'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter BLE plugin, based on Polidea&#x27;s RxAndroidBle and RxBluetoothKit'
  s.description      = <<-DESC
A Flutter BLE plugin, based on RxAndroidBle and RxBluetoothKit.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'

  s.ios.deployment_target = '8.0'

  s.dependency 'RxBluetoothKit'
  s.dependency 'plugin_scaffold'
end

