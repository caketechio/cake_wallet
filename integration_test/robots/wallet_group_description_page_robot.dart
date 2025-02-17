import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/new_wallet/wallet_group_description_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class WalletGroupDescriptionPageRobot {
  WalletGroupDescriptionPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  final CommonTestCases commonTestCases;

  Future<void> isWalletGroupDescriptionPage() async {
    await commonTestCases.isSpecificPage<WalletGroupDescriptionPage>();
    await commonTestCases.takeScreenshots('wallet_group_description_page');
  }

  void hasTitle() {
    commonTestCases.hasText(S.current.wallet_group);
  }

  Future<void> navigateToCreateNewSeedPage() async {
    await commonTestCases.tapItemByKey(
      'wallet_group_description_page_create_new_seed_button_key',
    );
  }

  Future<void> navigateToChooseWalletGroup() async {
    await commonTestCases.tapItemByKey(
      'wallet_group_description_page_choose_wallet_group_button_key',
    );
  }
}
