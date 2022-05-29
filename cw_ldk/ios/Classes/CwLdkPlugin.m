#import "CwLdkPlugin.h"
#if __has_include(<cw_ldk/cw_ldk-Swift.h>)
#import <cw_ldk/cw_ldk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "cw_ldk-Swift.h"
#endif

@implementation CwLdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCwLdkPlugin registerWithRegistrar:registrar];
}
@end
