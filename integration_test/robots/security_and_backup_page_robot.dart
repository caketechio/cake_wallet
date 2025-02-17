import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/settings/security_backup_page.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class SecurityAndBackupPageRobot {
  SecurityAndBackupPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  final CommonTestCases commonTestCases;

  Future<void> isSecurityAndBackupPage() async {
    await commonTestCases.isSpecificPage<SecurityBackupPage>();
    await commonTestCases.takeScreenshots('security_backup_page');
  }

  void hasTitle() {
    commonTestCases.hasText(S.current.security_and_backup);
  }

  Future<void> navigateToShowKeysPage() async {
    await commonTestCases.tapItemByKey('security_backup_page_show_keys_button_key');
  }
}
