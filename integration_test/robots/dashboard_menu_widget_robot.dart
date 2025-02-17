import 'package:cake_wallet/src/screens/dashboard/widgets/menu_widget.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class DashboardMenuWidgetRobot {
  DashboardMenuWidgetRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> hasMenuWidget() async {
    commonTestCases.hasType<MenuWidget>();
  }

  void displaysTheCorrectWalletNameAndSubName() {
    final menuWidgetState = tester.state<MenuWidgetState>(find.byType(MenuWidget));

    final walletName = menuWidgetState.widget.dashboardViewModel.name;
    commonTestCases.hasText(walletName);

    final walletSubName = menuWidgetState.widget.dashboardViewModel.subname;
    if (walletSubName.isNotEmpty) {
      commonTestCases.hasText(walletSubName);
    }
  }

  Future<void> navigateToWalletMenu() async {
    await commonTestCases.tapItemByKey('dashboard_page_Wallets_action_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> navigateToSecurityAndBackupPage() async {
    await commonTestCases.tapItemByKey(
      'dashboard_page_menu_widget_security_and_backup_button_key',
    );
    await commonTestCases.defaultSleepTime();
  }
}
