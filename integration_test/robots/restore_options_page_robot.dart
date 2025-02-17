import 'package:cake_wallet/src/screens/restore/restore_options_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class RestoreOptionsPageRobot {
  RestoreOptionsPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isRestoreOptionsPage() async {
    await commonTestCases.isSpecificPage<RestoreOptionsPage>();
    await commonTestCases.takeScreenshots('restore_options');
  }

  void hasRestoreOptionsButton() {
    commonTestCases.hasValueKey('restore_options_from_seeds_or_keys_button_key');
    commonTestCases.hasValueKey('restore_options_from_backup_button_key');
    commonTestCases.hasValueKey('restore_options_from_hardware_wallet_button_key');
    commonTestCases.hasValueKey('restore_options_from_qr_button_key');
  }

  Future<void> navigateToRestoreFromSeedsOrKeysPage() async {
    await commonTestCases.tapItemByKey('restore_options_from_seeds_or_keys_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> navigateToRestoreFromBackupPage() async {
    await commonTestCases.tapItemByKey('restore_options_from_backup_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> navigateToRestoreFromHardwareWalletPage() async {
    await commonTestCases.tapItemByKey('restore_options_from_hardware_wallet_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> backAndVerify() async {
    await commonTestCases.goBack();
    await isRestoreOptionsPage();
  }
}
