import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'components/common_test_constants.dart';
import 'components/common_test_flows.dart';
import 'robots/auth_page_robot.dart';
import 'robots/dashboard_page_robot.dart';
import 'robots/exchange_confirm_page_robot.dart';
import 'robots/exchange_page_robot.dart';
import 'robots/exchange_trade_page_robot.dart';
import 'package:cake_wallet/.secrets.g.dart' as secrets;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  DashboardPageRobot dashboardPageRobot;
  ExchangePageRobot exchangePageRobot;
  ExchangeConfirmPageRobot exchangeConfirmPageRobot;
  AuthPageRobot authPageRobot;
  ExchangeTradePageRobot exchangeTradePageRobot;
  CommonTestFlows commonTestFlows;

  group('Startup Test', () {
    testWidgets('Test for Exchange flow using Restore Wallet - Exchanging USDT(Sol) to SOL',
        (tester) async {
      authPageRobot = AuthPageRobot(tester);
      exchangePageRobot = ExchangePageRobot(tester);
      dashboardPageRobot = DashboardPageRobot(tester);
      exchangeTradePageRobot = ExchangeTradePageRobot(tester);
      exchangeConfirmPageRobot = ExchangeConfirmPageRobot(tester);
      commonTestFlows = CommonTestFlows(tester);

      await commonTestFlows.startAppFlow(ValueKey('funds_exchange_test_app_key'));

      await commonTestFlows.welcomePageToRestoreWalletThroughSeedsFlow(
        CommonTestConstants.testWalletType,
        secrets.solanaTestWalletSeeds,
        CommonTestConstants.pin,
      );

      // ----------- RestoreFromSeedOrKeys Page -------------
      await dashboardPageRobot.navigateToExchangePage();

      // ----------- Exchange Page -------------
      await exchangePageRobot.isExchangePage();
      exchangePageRobot.hasResetButton();
      await exchangePageRobot.displayBothExchangeCards();
      exchangePageRobot.confirmRightComponentsDisplayOnDepositExchangeCards();
      exchangePageRobot.confirmRightComponentsDisplayOnReceiveExchangeCards();

      await exchangePageRobot.selectDepositCurrency(CommonTestConstants.testDepositCurrency);
      await exchangePageRobot.selectReceiveCurrency(CommonTestConstants.testReceiveCurrency);

      await exchangePageRobot.enterDepositAmount(CommonTestConstants.exchangeTestAmount);
      await exchangePageRobot.enterDepositRefundAddress(
          depositAddress: CommonTestConstants.testWalletAddress);

      await exchangePageRobot.enterReceiveAddress(CommonTestConstants.testWalletAddress);

      await exchangePageRobot.onExchangeButtonPressed();

      await exchangePageRobot.handleErrors(CommonTestConstants.exchangeTestAmount);

      final onAuthPage = authPageRobot.onAuthPage();
      if (onAuthPage) {
        await authPageRobot.enterPinCode(CommonTestConstants.pin);
      }

      final onAuthPageDesktop = authPageRobot.onAuthPageDesktop();
      if (onAuthPageDesktop) {
        await authPageRobot.enterPassword(CommonTestConstants.pin.join(""));
      }

      // ----------- Exchange Confirm Page -------------
      await exchangeConfirmPageRobot.isExchangeConfirmPage();

      exchangeConfirmPageRobot.confirmComponentsOfTradeDisplayProperly();
      await exchangeConfirmPageRobot.confirmCopyTradeIdToClipBoardWorksProperly();
      await exchangeConfirmPageRobot.onSavedTradeIdButtonPressed();

      // ----------- Exchange Trade Page -------------
      await exchangeTradePageRobot.isExchangeTradePage();
      exchangeTradePageRobot.hasInformationDialog();
      await exchangeTradePageRobot.onGotItButtonPressed();

      await exchangeTradePageRobot.onConfirmSendingButtonPressed();

      await exchangeTradePageRobot.handleConfirmSendResult();

      await exchangeTradePageRobot.onSendButtonOnConfirmSendingDialogPressed();
    });
  });
}
