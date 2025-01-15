import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/auth/auth_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';
import 'pin_code_widget_robot.dart';

class AuthPageRobot extends PinCodeWidgetRobot {
  AuthPageRobot(this.tester)
      : commonTestCases = CommonTestCases(tester),
        super(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  bool onAuthPage() {
    final hasPinButtons = find.byKey(ValueKey('pin_code_button_3_key'));
    final hasPin = hasPinButtons.tryEvaluate();
    return hasPin;
  }

  bool onAuthPageDesktop() {
    final hasWalletPasswordInput = find.byKey(ValueKey('enter_wallet_password'));
    return hasWalletPasswordInput.tryEvaluate();
  }

  Future<void> isAuthPage() async {
    await commonTestCases.isSpecificPage<AuthPage>();
  }

  void hasTitle() {
    commonTestCases.hasText(S.current.setup_pin);
  }
}
