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
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.vendored_libraries = 'External/lib/libdcrwallet.a'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', "OTHER_LDFLAGS" => "-force_load $(PODS_TARGET_SRCROOT)/External/lib/libdcrwallet.a -lstdc++" }
  s.swift_version = '5.0'
end
