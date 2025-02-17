import 'package:cake_wallet/src/screens/new_wallet/new_wallet_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class NewWalletPageRobot {
  NewWalletPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isNewWalletPage() async {
    await commonTestCases.isSpecificPage<NewWalletPage>();
    await commonTestCases.takeScreenshots('new_wallet_page');
  }

  Future<void> enterWalletName(String walletName) async {
    await commonTestCases.enterText(
      walletName,
      'new_wallet_page_wallet_name_textformfield_key',
    );
    await commonTestCases.defaultSleepTime();
  }

  Future<void> generateWalletName() async {
    await commonTestCases.tapItemByKey(
      'new_wallet_page_wallet_name_textformfield_generate_name_button_key',
    );
    await commonTestCases.defaultSleepTime();
  }

  Future<void> onNextButtonPressed() async {
    await commonTestCases.tapItemByKey('new_wallet_page_confirm_button_key');
    await commonTestCases.defaultSleepTime();
  }
}
