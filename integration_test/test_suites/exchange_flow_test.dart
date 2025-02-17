import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../components/common_test_constants.dart';
import '../components/common_test_flows.dart';
import '../robots/dashboard_page_robot.dart';
import '../robots/exchange_confirm_page_robot.dart';
import '../robots/exchange_page_robot.dart';
import '../robots/exchange_trade_page_robot.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  CommonTestFlows commonTestFlows;
  ExchangePageRobot exchangePageRobot;
  DashboardPageRobot dashboardPageRobot;
  ExchangeTradePageRobot exchangeTradePageRobot;
  ExchangeConfirmPageRobot exchangeConfirmPageRobot;

  testWidgets('Exchange flow', (tester) async {
    commonTestFlows = CommonTestFlows(tester);
    exchangePageRobot = ExchangePageRobot(tester);
    dashboardPageRobot = DashboardPageRobot(tester);
    exchangeTradePageRobot = ExchangeTradePageRobot(tester);
    exchangeConfirmPageRobot = ExchangeConfirmPageRobot(tester);

    await commonTestFlows.startAppFlow(ValueKey('exchange_app_test_key'));
    await commonTestFlows.welcomePageToRestoreWalletThroughSeedsFlow(
      CommonTestConstants.testWalletType,
      secrets.solanaTestWalletSeeds,
      CommonTestConstants.pin,
    );
    await dashboardPageRobot.navigateToExchangePage();

    // ----------- Exchange Page -------------
    await exchangePageRobot.selectDepositCurrency(CommonTestConstants.exchangeTestDepositCurrency);
    await exchangePageRobot.selectReceiveCurrency(CommonTestConstants.exchangeTestReceiveCurrency);

    await exchangePageRobot.enterDepositAmount(CommonTestConstants.exchangeTestAmount);
    await exchangePageRobot.enterDepositRefundAddress(
      depositAddress: CommonTestConstants.testWalletAddress,
    );
    await exchangePageRobot.enterReceiveAddress(CommonTestConstants.testWalletAddress);

    await exchangePageRobot.onExchangeButtonPressed();

    await exchangePageRobot.handleErrors(CommonTestConstants.exchangeTestAmount);

    await exchangeConfirmPageRobot.onSavedTradeIdButtonPressed();
    await exchangeTradePageRobot.onGotItButtonPressed();
  });
}
