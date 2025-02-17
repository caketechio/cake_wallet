import 'package:cake_wallet/src/screens/send/transaction_success_info_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class TransactionSuccessInfoRobot {
  TransactionSuccessInfoRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isTransactionSuccessInfoPage() async {
    await commonTestCases.isSpecificPage<TransactionSuccessPage>();
    await commonTestCases.takeScreenshots('transaction_success_info_page');
  }

  Future<void> onConfirmButtonPressed() async {
    await commonTestCases.tapItemByKey('transaction_success_info_page_button_key');
    await commonTestCases.defaultSleepTime();
  }
}
