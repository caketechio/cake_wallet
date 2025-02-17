import 'package:cake_wallet/src/screens/welcome/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class WelcomePageRobot {
  WelcomePageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isWelcomePage() async {
    await commonTestCases.isSpecificPage<WelcomePage>();
    await commonTestCases.takeScreenshots('welcome_page');
  }

  void confirmActionButtonsDisplay() {
    final createNewWalletButton = find.byKey(ValueKey('welcome_page_create_new_wallet_button_key'));

    final restoreWalletButton = find.byKey(ValueKey('welcome_page_restore_wallet_button_key'));

    expect(createNewWalletButton, findsOneWidget);
    expect(restoreWalletButton, findsOneWidget);
  }

  Future<void> navigateToCreateNewWalletPage() async {
    await commonTestCases.tapItemByKey('welcome_page_create_new_wallet_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> navigateToRestoreWalletPage() async {
    await commonTestCases.tapItemByKey('welcome_page_restore_wallet_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> backAndVerify() async {
    await commonTestCases.goBack();
    await isWelcomePage();
  }
}
