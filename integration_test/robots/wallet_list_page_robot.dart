import 'package:cake_wallet/generated/i18n.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class WalletListPageRobot {
  WalletListPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isWalletListPage() async {
    await commonTestCases.isSpecificPage<WalletListPageRobot>();
    await commonTestCases.takeScreenshots('wallet_list_page');
  }

  void displaysCorrectTitle() {
    commonTestCases.hasText(S.current.wallets);
  }

  Future<void> navigateToCreateNewWalletPage() async {
    commonTestCases.tapItemByKey('wallet_list_page_create_new_wallet_button_key');
  }

  Future<void> navigateToRestoreWalletOptionsPage() async {
    commonTestCases.tapItemByKey('wallet_list_page_restore_wallet_button_key');
  }
}
