#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cw_decred.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cw_decred'
  s.version          = '0.0.1'
  s.summary          = 'Cake Wallet Decred'
  s.description      = 'Cake Wallet wrapper over Decred project'
  s.homepage         = 'http://cakewallet.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Cake Wallet' => 'support@cakewallet.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.vendored_libraries = 'External/lib/libdcrwallet.a'
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386', "OTHER_LDFLAGS" => "-force_load $(PODS_TARGET_SRCROOT)/External/lib/libdcrwallet.a -lstdc++" }
  s.swift_version = '5.0'
end
