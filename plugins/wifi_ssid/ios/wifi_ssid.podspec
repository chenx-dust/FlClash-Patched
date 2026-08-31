Pod::Spec.new do |s|
  s.name             = 'wifi_ssid'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin to retrieve the current WiFi SSID.'
  s.description      = <<-DESC
A Flutter plugin to retrieve the current WiFi SSID.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'FlClash' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.frameworks = 'CoreLocation', 'NetworkExtension'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
