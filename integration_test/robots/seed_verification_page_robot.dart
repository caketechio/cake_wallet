import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/seed/seed_verification/seed_verification_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class SeedVerificationPageRobot {
  SeedVerificationPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  final CommonTestCases commonTestCases;

  Future<void> isSeedVerificationPage() async {
    await commonTestCases.isSpecificPage<SeedVerificationPage>();
    await commonTestCases.takeScreenshots('seed_verification_page');
  }

  void hasTitle() {
    commonTestCases.hasText(S.current.verify_seed);
  }

  Future<void> verifyWalletSeeds() async {
    final seedVerificationPage =
        tester.widget<SeedVerificationPage>(find.byType(SeedVerificationPage));

    final walletSeedViewModel = seedVerificationPage.walletSeedViewModel;

    while (!walletSeedViewModel.isVerificationComplete) {
      final currentCorrectWord = walletSeedViewModel.currentCorrectWord;

      commonTestCases.hasTextAtLestOnce(currentCorrectWord);

      await commonTestCases.tapItemByKey(
        'seed_verification_option_${currentCorrectWord}_button_key',
      );

      await commonTestCases.defaultSleepTime(seconds: 1);
    }

    await commonTestCases.tapItemByKey('wallet_seed_page_open_wallet_button_key');

    await commonTestCases.defaultSleepTime();
  }
}
