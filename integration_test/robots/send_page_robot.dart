import 'dart:async';

import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/send/send_page.dart';
import 'package:cake_wallet/view_model/send/send_view_model_state.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';
import '../components/common_test_constants.dart';
import 'auth_page_robot.dart';

class SendPageRobot {
  SendPageRobot({required this.tester})
      : commonTestCases = CommonTestCases(tester),
        authPageRobot = AuthPageRobot(tester);

  WidgetTester tester;
  CommonTestCases commonTestCases;
  AuthPageRobot authPageRobot;

  Future<void> isSendPage() async {
    await commonTestCases.isSpecificPage<SendPage>();
  }

  void hasTitle() {
    commonTestCases.hasText(S.current.send);
  }

  void confirmViewComponentsDisplayProperly() {
    SendPage sendPage = tester.widget(find.byType(SendPage));
    final sendViewModel = sendPage.sendViewModel;

    commonTestCases.hasValueKey('send_page_address_textfield_key');
    commonTestCases.hasValueKey('send_page_note_textfield_key');
    commonTestCases.hasValueKey('send_page_amount_textfield_key');
    commonTestCases.hasValueKey('send_page_add_template_button_key');

    if (sendViewModel.hasMultipleTokens) {
      commonTestCases.hasValueKey('send_page_currency_picker_button_key');
    }

    if (!sendViewModel.isBatchSending) {
      commonTestCases.hasValueKey('send_page_send_all_button_key');
    }

    if (!sendViewModel.isFiatDisabled) {
      commonTestCases.hasValueKey('send_page_fiat_amount_textfield_key');
    }

    if (sendViewModel.hasFees) {
      commonTestCases.hasValueKey('send_page_select_fee_priority_button_key');
    }

    if (sendViewModel.hasCoinControl) {
      commonTestCases.hasValueKey('send_page_unspent_coin_button_key');
    }

    if (sendViewModel.hasCurrecyChanger) {
      commonTestCases.hasValueKey('send_page_change_asset_button_key');
    }

    if (sendViewModel.sendTemplateViewModel.hasMultiRecipient) {
      commonTestCases.hasValueKey('send_page_add_receiver_button_key');
    }
  }

  Future<void> selectReceiveCurrency(CryptoCurrency receiveCurrency) async {
    final currencyPickerKey = 'send_page_currency_picker_button_key';
    final currencyPickerDialogKey = 'send_page_currency_picker_dialog_button_key';

    await commonTestCases.tapItemByKey(currencyPickerKey);
    commonTestCases.hasValueKey(currencyPickerDialogKey);

    SendPage sendPage = tester.widget(find.byType(SendPage));
    final sendViewModel = sendPage.sendViewModel;

    if (receiveCurrency == sendViewModel.selectedCryptoCurrency) {
      await commonTestCases
          .tapItemByKey('picker_items_index_${receiveCurrency.name}_selected_item_button_key');
      return;
    }

    await commonTestCases.enterText(receiveCurrency.title, 'search_bar_widget_key');

    await commonTestCases.defaultSleepTime();

    await commonTestCases.tapItemByKey('picker_items_index_${receiveCurrency.fullName}_button_key');
  }

  Future<void> enterReceiveAddress(String receiveAddress) async {
    await commonTestCases.enterText(receiveAddress, 'send_page_address_textfield_key');
    await commonTestCases.defaultSleepTime();
  }

  Future<void> enterAmount(String amount) async {
    await commonTestCases.enterText(amount, 'send_page_amount_textfield_key');
  }

  Future<void> selectTransactionPriority({TransactionPriority? priority}) async {
    SendPage sendPage = tester.widget(find.byType(SendPage));
    final sendViewModel = sendPage.sendViewModel;

    if (!sendViewModel.hasFees || priority == null) return;

    final transactionPriorityPickerKey = 'send_page_select_fee_priority_button_key';
    await commonTestCases.tapItemByKey(transactionPriorityPickerKey);

    if (priority == sendViewModel.transactionPriority) {
      await commonTestCases
          .tapItemByKey('picker_items_index_${priority.title}_selected_item_button_key');
      return;
    }

    await commonTestCases.dragUntilVisible(
      'picker_items_index_${priority.title}_button_key',
      'picker_scrollbar_key',
    );
    await commonTestCases.defaultSleepTime();

    await commonTestCases.tapItemByKey('picker_items_index_${priority.title}_button_key');
  }

  Future<void> onSendButtonPressed() async {
    tester.printToConsole('Pressing send');

    await commonTestCases.tapItemByKey(
      'send_page_send_button_key',
      shouldPumpAndSettle: false,
    );

    await _waitForSendTransactionCompletion();

    await commonTestCases.defaultSleepTime();
  }

  Future<void> _waitForSendTransactionCompletion() async {
    await tester.pump();
    final Completer<void> completer = Completer<void>();

    // Loop to wait for the async operation to complete
    while (true) {
      await Future.delayed(Duration(seconds: 1));

      tester.printToConsole('Before _handleAuth');

      await _handleAuthPage();

      tester.printToConsole('After _handleAuth');

      await tester.pump();

      final sendPage = tester.widget<SendPage>(find.byType(SendPage));
      final state = sendPage.sendViewModel.state;

      await tester.pump();

      bool isDone = state is ExecutedSuccessfullyState;
      bool isFailed = state is FailureState;

      tester.printToConsole('isDone: $isDone');
      tester.printToConsole('isFailed: $isFailed');

      if (isDone || isFailed) {
        tester.printToConsole(
          isDone ? 'Completer is done' : 'Completer is done though operation failed',
        );
        completer.complete();
        await tester.pump();
        break;
      } else {
        tester.printToConsole('Completer is not done');
        await tester.pump();
      }
    }

    await expectLater(completer.future, completes);

    tester.printToConsole('Done confirming sending operation');
  }

  Future<void> _handleAuthPage() async {
    final onAuthPage = authPageRobot.onAuthPage();
    if (onAuthPage) {
      await authPageRobot.enterPinCode(CommonTestConstants.pin);
    }

  final onAuthPageDesktop = authPageRobot.onAuthPageDesktop();
  if (onAuthPageDesktop) {
      await authPageRobot.enterPassword(CommonTestConstants.pin.join(""));
    }
  }

  Future<void> handleSendResult() async {
    await tester.pump();
    tester.printToConsole('Inside handle function');

    bool hasError = false;

    hasError = await hasErrorWhileSending();

    tester.printToConsole('Has an Error in the handle: $hasError');

    int maxRetries = 3;
    int retries = 0;

    while (hasError && retries < maxRetries) {
      tester.printToConsole('hasErrorInLoop: $hasError');
      await tester.pump();

      await onSendFailureDialogButtonPressed();
      tester.printToConsole('Failure button tapped');

      await commonTestCases.defaultSleepTime();

      await onSendButtonPressed();
      tester.printToConsole('Send button tapped');

      hasError = await hasErrorWhileSending();

      retries++;
    }

    if (!hasError) {
      tester.printToConsole('No error, proceeding with flow');
      await tester.pump();
    }

    await commonTestCases.defaultSleepTime();
  }

  //* ------ On Sending Failure ------------
  Future<bool> hasErrorWhileSending() async {
    await tester.pump();

    tester.printToConsole('Checking if there is an error');

    final errorDialog = find.byKey(ValueKey('send_page_send_failure_dialog_button_key'));

    bool hasError = errorDialog.tryEvaluate();

    tester.printToConsole('Has error: $hasError');

    return hasError;
  }

  Future<void> onSendFailureDialogButtonPressed() async {
    await commonTestCases.defaultSleepTime();

    tester.printToConsole('Send Button Failure Dialog Triggered');

    await commonTestCases.tapItemByKey('send_page_send_failure_dialog_button_key');
  }

  //* ------ On Sending Success ------------
  Future<void> onSendButtonOnConfirmSendingDialogPressed() async {
    tester.printToConsole('Inside confirm sending dialog: For sending');
    await commonTestCases.defaultSleepTime();
    await tester.pump();

    final sendText = find.text(S.current.send).last;
    bool hasText = sendText.tryEvaluate();
    tester.printToConsole('Has Text: $hasText');

    if (hasText) {
      await commonTestCases.tapItemByFinder(sendText, shouldPumpAndSettle: false);
      // Loop to wait for the operation to commit transaction
      await _waitForCommitTransactionCompletion();

      await tester.pump();

      await commonTestCases.defaultSleepTime(seconds: 4);
    } else {
      await commonTestCases.defaultSleepTime();
      await tester.pump();
      onSendButtonOnConfirmSendingDialogPressed();
    }
  }

  Future<void> _waitForCommitTransactionCompletion() async {
    final Completer<void> completer = Completer<void>();

    while (true) {
      await Future.delayed(Duration(seconds: 1));

      final sendPage = tester.widget<SendPage>(find.byType(SendPage));
      final state = sendPage.sendViewModel.state;

      bool isDone = state is TransactionCommitted;
      bool isFailed = state is FailureState;

      tester.printToConsole('isDone: $isDone');
      tester.printToConsole('isFailed: $isFailed');

      if (isDone || isFailed) {
        tester.printToConsole(
          isDone ? 'Completer is done' : 'Completer is done though operation failed',
        );
        completer.complete();
        await tester.pump();
        break;
      } else {
        tester.printToConsole('Completer is not done');
        await tester.pump();
      }
    }

    await expectLater(completer.future, completes);

    tester.printToConsole('Done Committing Transaction');
  }

  Future<void> onCancelButtonOnConfirmSendingDialogPressed() async {
    tester.printToConsole('Inside confirm sending dialog: For canceling');
    await commonTestCases.defaultSleepTime(seconds: 4);

    final cancelText = find.text(S.current.cancel);
    bool hasText = cancelText.tryEvaluate();

    if (hasText) {
      await commonTestCases.tapItemByFinder(cancelText);

      await commonTestCases.defaultSleepTime(seconds: 4);
    }
  }

  //* ---- Add Contact Dialog On Send Successful Dialog -----
  Future<void> onSentDialogPopUp() async {
    SendPage sendPage = tester.widget(find.byType(SendPage));
    final sendViewModel = sendPage.sendViewModel;

    final newContactAddress = sendPage.newContactAddress ?? sendViewModel.newContactAddress();
    if (newContactAddress != null) {
      await _onAddContactButtonOnSentDialogPressed();
    }

    await commonTestCases.defaultSleepTime();
  }

  Future<void> _onAddContactButtonOnSentDialogPressed() async {
    await commonTestCases.tapItemByKey('send_page_sent_dialog_add_contact_button_key');
  }

  // ignore: unused_element
  Future<void> _onIgnoreButtonOnSentDialogPressed() async {
    await commonTestCases.tapItemByKey('send_page_sent_dialog_ignore_button_key');
  }
}
