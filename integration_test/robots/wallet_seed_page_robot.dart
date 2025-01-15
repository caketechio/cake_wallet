import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/seed/wallet_seed_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class WalletSeedPageRobot {
  WalletSeedPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isWalletSeedPage() async {
    await commonTestCases.isSpecificPage<WalletSeedPage>();
  }

  Future<void> onSeedPageVerifyButtonPressed() async {
    await commonTestCases.tapItemByKey('wallet_seed_page_verify_seed_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> onOpenWalletButtonPressed() async {
    await commonTestCases.tapItemByKey('wallet_seed_page_open_wallet_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> onConfirmButtonOnSeedAlertDialogPressed() async {
    await commonTestCases.tapItemByKey('wallet_seed_page_seed_alert_confirm_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> onBackButtonOnSeedAlertDialogPressed() async {
    await commonTestCases.tapItemByKey('wallet_seed_page_seed_alert_back_button_key');
    await commonTestCases.defaultSleepTime();
  }

  void confirmWalletDetailsDisplayCorrectly() {
    final walletSeedPage = tester.widget<WalletSeedPage>(find.byType(WalletSeedPage));

    final walletSeedViewModel = walletSeedPage.walletSeedViewModel;

    final walletName = walletSeedViewModel.name;
    final walletSeeds = walletSeedViewModel.seed;

    commonTestCases.hasText(walletName);
    final seedList = walletSeeds.trim().split(" ");
    for (final seedWord in seedList) {
      commonTestCases.hasTextAtLestOnce(seedWord);
    }
  }

  void confirmWalletSeedReminderDisplays() {
    commonTestCases.hasText(S.current.cake_seeds_save_disclaimer);
  }

  Future<void> onSaveSeedsButtonPressed() async {
    await commonTestCases.tapItemByKey('wallet_seed_page_save_seeds_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> onCopySeedsButtonPressed() async {
    await commonTestCases.tapItemByKey('wallet_seed_page_copy_seeds_button_key');
    await commonTestCases.defaultSleepTime();
  }
}
