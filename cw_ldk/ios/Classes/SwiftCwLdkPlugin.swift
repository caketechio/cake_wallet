import Flutter
import UIKit

public class SwiftCwLdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cw_ldk", binaryMessenger: registrar.messenger())
    let instance = SwiftCwLdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }

  public func dummyMethodToEnforceBundling() {
    // dummy calls to prevent tree shaking
    hello_world();
  }
}
