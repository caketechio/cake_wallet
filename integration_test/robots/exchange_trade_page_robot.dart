import 'dart:async';

import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/exchange_trade/exchange_trade_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class ExchangeTradePageRobot {
  ExchangeTradePageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isExchangeTradePage() async {
    await commonTestCases.isSpecificPage<ExchangeTradePage>();
    await commonTestCases.takeScreenshots('exchange_trade_page');

  }

  void hasInformationDialog() {
    commonTestCases.hasValueKey('information_page_dialog_key');
  }

  Future<void> onGotItButtonPressed() async {
    await commonTestCases.tapItemByKey('information_page_got_it_button_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> onConfirmSendingButtonPressed() async {
    tester.printToConsole('Now confirming sending');

    await commonTestCases.tapItemByKey(
      'exchange_trade_page_confirm_sending_button_key',
      shouldPumpAndSettle: false,
    );

    final Completer<void> completer = Completer<void>();

    // Loop to wait for the async operation to complete
    while (true) {
      await Future.delayed(Duration(seconds: 1));

      final ExchangeTradeState state = tester.state(find.byType(ExchangeTradeForm));
      final execState = state.widget.exchangeTradeViewModel.sendViewModel.state;

      bool isDone = execState is ExecutedSuccessfullyState;
      bool isFailed = execState is FailureState;

      tester.printToConsole('isDone: $isDone');
      tester.printToConsole('isFailed: $isFailed');

      if (isDone || isFailed) {
        tester.printToConsole(
            isDone ? 'Completer is done' : 'Completer is done though operation failed');
        completer.complete();
        await tester.pump();
        break;
      } else {
        tester.printToConsole('Completer is not done');
        await tester.pump();
      }
    }

    await expectLater(completer.future, completes);

    tester.printToConsole('Done confirming sending');

    await commonTestCases.defaultSleepTime(seconds: 4);
  }

  Future<void> onSendButtonOnConfirmSendingDialogPressed() async {
    tester.printToConsole('Send Button on Confirm Dialog Triggered');
    await commonTestCases.defaultSleepTime(seconds: 4);

    final sendText = find.text(S.current.send);
    bool hasText = sendText.tryEvaluate();

    if (hasText) {
      await commonTestCases.tapItemByFinder(sendText);

      await commonTestCases.defaultSleepTime(seconds: 4);
    }
  }

  Future<void> onCancelButtonOnConfirmSendingDialogPressed() async {
    tester.printToConsole('Cancel Button on Confirm Dialog Triggered');

    await commonTestCases.tapItemByKey(
      'exchange_trade_page_confirm_sending_dialog_cancel_button_key',
    );

    await commonTestCases.defaultSleepTime();
  }

  Future<void> onSendFailureDialogButtonPressed() async {
    await commonTestCases.defaultSleepTime(seconds: 6);

    tester.printToConsole('Send Button Failure Dialog Triggered');

    await commonTestCases.tapItemByKey('exchange_trade_page_send_failure_dialog_button_key');
  }

  Future<bool> hasErrorWhileSending() async {
    await tester.pump();

    tester.printToConsole('Checking if there is an error');

    final errorDialog = find.byKey(
      ValueKey('exchange_trade_page_send_failure_dialog_button_key'),
    );

    bool hasError = errorDialog.tryEvaluate();

    tester.printToConsole('Has error: $hasError');

    return hasError;
  }

  Future<void> handleConfirmSendResult() async {
    bool hasError = false;

    hasError = await hasErrorWhileSending();

    int maxRetries = 20;
    int retries = 0;

    while (hasError && retries < maxRetries) {
      tester.printToConsole('hasErrorInLoop: $hasError');
      await tester.pump();

      await onSendFailureDialogButtonPressed();
      tester.printToConsole('Failure button tapped');

      await commonTestCases.defaultSleepTime();

      await onConfirmSendingButtonPressed();
      tester.printToConsole('Confirm sending button tapped');

      hasError = await hasErrorWhileSending();

      retries++;
    }

    if (!hasError) {
      tester.printToConsole('No error, proceeding with flow');
      await tester.pump();
    }

    await commonTestCases.defaultSleepTime();
  }
}
