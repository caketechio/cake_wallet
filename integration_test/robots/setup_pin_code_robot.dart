import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/setup_pin_code/setup_pin_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';
import 'pin_code_widget_robot.dart';

class SetupPinCodeRobot extends PinCodeWidgetRobot {
  SetupPinCodeRobot(this.tester)
      : commonTestCases = CommonTestCases(tester),
        super(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isSetupPinCodePage() async {
    await commonTestCases.isSpecificPage<SetupPinCodePage>();
    await commonTestCases.takeScreenshots('setup_pin_code_page');
  }

  void hasTitle() {
    commonTestCases.hasText(S.current.setup_pin);
  }

  Future<void> tapSuccessButton() async {
    await commonTestCases.tapItemByKey('setup_pin_code_success_button_key');
    await commonTestCases.defaultSleepTime();
  }
}
