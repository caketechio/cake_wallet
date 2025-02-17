import 'package:cake_wallet/src/screens/disclaimer/disclaimer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class DisclaimerPageRobot {
  DisclaimerPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isDisclaimerPage() async {
    await commonTestCases.isSpecificPage<DisclaimerPage>();
    await commonTestCases.takeScreenshots('disclaimer_page');
  }

  void hasCheckIcon(bool hasBeenTapped) {
    // The checked Icon should not be available initially, until user taps the checkbox
    final checkIcon = find.byKey(ValueKey('disclaimer_check_icon_key'));
    expect(checkIcon, hasBeenTapped ? findsOneWidget : findsNothing);
  }

  void hasDisclaimerCheckbox() {
    final checkBox = find.byKey(ValueKey('disclaimer_check_key'));
    expect(checkBox, findsOneWidget);
  }

  Future<void> tapDisclaimerCheckbox() async {
    await commonTestCases.tapItemByKey('disclaimer_check_key');

    await commonTestCases.defaultSleepTime();
  }

  Future<void> tapAcceptButton() async {
    await commonTestCases.tapItemByKey('disclaimer_accept_button_key');
    
    await commonTestCases.defaultSleepTime();
  }
}
