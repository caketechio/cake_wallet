import 'dart:io';

import 'package:cake_wallet/wallet_types.g.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../components/common_test_cases.dart';
import '../components/common_test_constants.dart';
import '../components/common_test_flows.dart';
import '../robots/auth_page_robot.dart';
import '../robots/dashboard_page_robot.dart';
import '../robots/security_and_backup_page_robot.dart';
import '../robots/wallet_keys_robot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  AuthPageRobot authPageRobot;
  CommonTestFlows commonTestFlows;
  DashboardPageRobot dashboardPageRobot;
  WalletKeysAndSeedPageRobot walletKeysAndSeedPageRobot;
  SecurityAndBackupPageRobot securityAndBackupPageRobot;

  testWidgets(
    'Confirm if the seeds display properly',
    (tester) async {
      authPageRobot = AuthPageRobot(tester);
      commonTestFlows = CommonTestFlows(tester);
      dashboardPageRobot = DashboardPageRobot(tester);
      walletKeysAndSeedPageRobot = WalletKeysAndSeedPageRobot(tester);
      securityAndBackupPageRobot = SecurityAndBackupPageRobot(tester);

      // Start the app
      await commonTestFlows.startAppFlow(
        ValueKey('confirm_creds_display_correctly_flow_app_key'),
      );

      await commonTestFlows.welcomePageToCreateNewWalletFlow(
        WalletType.solana,
        CommonTestConstants.pin,
      );

      await dashboardPageRobot.confirmWalletTypeIsDisplayedCorrectly(WalletType.solana);

      await _confirmSeedsFlowForWalletType(
        WalletType.solana,
        authPageRobot,
        dashboardPageRobot,
        securityAndBackupPageRobot,
        walletKeysAndSeedPageRobot,
        tester,
      );

      // Do the same for other available wallet types
      for (var walletType in availableWalletTypes) {
        if (walletType == WalletType.solana) {
          continue;
        }

        await commonTestFlows.switchToWalletMenuFromDashboardPage();

        await commonTestFlows.createNewWalletFromWalletMenu(walletType);

        await dashboardPageRobot.confirmWalletTypeIsDisplayedCorrectly(walletType);

        await _confirmSeedsFlowForWalletType(
          walletType,
          authPageRobot,
          dashboardPageRobot,
          securityAndBackupPageRobot,
          walletKeysAndSeedPageRobot,
          tester,
        );
      }

      await Future.delayed(Duration(seconds: 15));
    },
  );
}

Future<void> _confirmSeedsFlowForWalletType(
  WalletType walletType,
  AuthPageRobot authPageRobot,
  DashboardPageRobot dashboardPageRobot,
  SecurityAndBackupPageRobot securityAndBackupPageRobot,
  WalletKeysAndSeedPageRobot walletKeysAndSeedPageRobot,
  WidgetTester tester,
) async {
  await dashboardPageRobot.openDrawerMenu();
  await dashboardPageRobot.dashboardMenuWidgetRobot.navigateToSecurityAndBackupPage();

  await securityAndBackupPageRobot.navigateToShowKeysPage();

  final onAuthPage = authPageRobot.onAuthPage();
  if (onAuthPage) {
    await authPageRobot.enterPinCode(CommonTestConstants.pin);
  }

  final onAuthPageDesktop = authPageRobot.onAuthPageDesktop();
  if (onAuthPageDesktop) {
    await authPageRobot.enterPassword(CommonTestConstants.pin.join(""));
  }
  await tester.pumpAndSettle();

  await walletKeysAndSeedPageRobot.isWalletKeysAndSeedPage();
  walletKeysAndSeedPageRobot.hasTitle();
  walletKeysAndSeedPageRobot.hasShareWarning();

  await walletKeysAndSeedPageRobot.confirmWalletCredentials(walletType);

  await walletKeysAndSeedPageRobot.backToDashboard();
}
