#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_native_events.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_native_events'
  s.version          = '1.0.0'
  s.summary          = 'Lightweight native to Flutter event bus.'
  s.description      = <<-DESC
Flutter plugin for typed native and Flutter events, request-response callbacks, and hybrid app communication.
                       DESC
  s.homepage         = 'https://pub.dev/packages/flutter_native_events'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Flutter Native Events Contributors' => 'maintainers@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_native_events_privacy' => ['flutter_native_events/Sources/flutter_native_events/PrivacyInfo.xcprivacy']}
end
