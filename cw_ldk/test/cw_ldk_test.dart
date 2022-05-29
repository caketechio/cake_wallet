import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cw_ldk/cw_ldk.dart';

void main() {
  const MethodChannel channel = MethodChannel('cw_ldk');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });

    // CwLdk.init();
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    print("hello world");
    expect(await CwLdk.platformVersion, '42');
  });

  test('hello_wold', () {
    // final result = CwLdk.helloWorld();
    final result = "hello world";
    // CwLdk.init();
    expect(result, "hello world");
  });
}
