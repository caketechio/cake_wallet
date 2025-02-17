import 'dart:async';

import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/dashboard/pages/transactions_page.dart';
import 'package:cake_wallet/view_model/dashboard/anonpay_transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/dashboard_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/date_section_item.dart';
import 'package:cake_wallet/view_model/dashboard/order_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/trade_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/transaction_list_item.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../components/common_test_cases.dart';

class TransactionsPageRobot {
  TransactionsPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isTransactionsPage() async {
    await commonTestCases.isSpecificPage<TransactionsPage>();
    await commonTestCases.takeScreenshots('transactions_page');
  }

  Future<void> confirmTransactionsPageConstantsDisplayProperly() async {
    await commonTestCases.defaultSleepTime();

    final transactionsPage = tester.widget<TransactionsPage>(find.byType(TransactionsPage));
    final dashboardViewModel = transactionsPage.dashboardViewModel;
    if (dashboardViewModel.status is SyncingSyncStatus) {
      commonTestCases.hasValueKey('transactions_page_syncing_alert_card_key');
      commonTestCases.hasText(S.current.syncing_wallet_alert_title);
      commonTestCases.hasText(S.current.syncing_wallet_alert_content);
    }

    commonTestCases.hasValueKey('transactions_page_header_row_key');
    commonTestCases.hasText(S.current.transactions);
    commonTestCases.hasValueKey('transactions_page_header_row_transaction_filter_button_key');
  }

  Future<void> confirmTransactionHistoryListDisplaysCorrectly(bool hasTxHistoryWhileSyncing) async {
    // Retrieve the TransactionsPage widget and its DashboardViewModel
    final transactionsPage = tester.widget<TransactionsPage>(find.byType(TransactionsPage));
    final dashboardViewModel = transactionsPage.dashboardViewModel;

    // Define a timeout to prevent infinite loops
    // Putting at one hour for cases like monero that takes time to sync
    final timeout = Duration(hours: 1);
    final pollingInterval = Duration(seconds: 2);
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final isSynced = dashboardViewModel.status is SyncedSyncStatus;
      final itemsLoaded = dashboardViewModel.items.isNotEmpty;

      // Perform item checks if items are loaded
      if (itemsLoaded) {
        await _performItemChecks(dashboardViewModel);
      } else {
        // Verify placeholder when items are not loaded
        _verifyPlaceholder();
      }

      // Determine if we should exit the loop
      if (_shouldExitLoop(hasTxHistoryWhileSyncing, isSynced, itemsLoaded)) {
        break;
      }

      // Pump the UI and wait for the next polling interval
      await tester.pumpAndSettle(pollingInterval);
    }

    // After the loop, verify that both status is synced and items are loaded
    if (!_isFinalStateValid(dashboardViewModel)) {
      throw TimeoutException('Dashboard did not sync and load items within the allotted time.');
    }
  }

  bool _shouldExitLoop(bool hasTxHistoryWhileSyncing, bool isSynced, bool itemsLoaded) {
    if (hasTxHistoryWhileSyncing) {
      // When hasTxHistoryWhileSyncing is true, exit when status is synced
      return isSynced;
    } else {
      // When hasTxHistoryWhileSyncing is false, exit when status is synced and items are loaded
      return isSynced && itemsLoaded;
    }
  }

  void _verifyPlaceholder() {
    commonTestCases.hasValueKey('transactions_page_placeholder_transactions_text_key');
    commonTestCases.hasText(S.current.placeholder_transactions);
  }

  bool _isFinalStateValid(DashboardViewModel dashboardViewModel) {
    final isSynced = dashboardViewModel.status is SyncedSyncStatus;
    final itemsLoaded = dashboardViewModel.items.isNotEmpty;
    return isSynced && itemsLoaded;
  }

  Future<void> _performItemChecks(DashboardViewModel dashboardViewModel) async {
    final itemsToProcess = dashboardViewModel.items.where((item) {
      if (item is DateSectionItem) return false;
      if (item is TransactionListItem) {
        return !(item.hasTokens && item.assetOfTransaction == null);
      }
      return true;
    }).toList();

    for (var item in itemsToProcess) {
      final keyId = (item.key as ValueKey<String>).value;

      tester.printToConsole('\nProcessing item: $keyId\n');
      await tester.pumpAndSettle();

      // Scroll the item into view
      await commonTestCases.dragUntilVisible(keyId, 'transactions_page_list_view_builder_key');
      await tester.pumpAndSettle();

      // Check if the widget is visible
      if (!tester.any(find.byKey(ValueKey(keyId)))) {
        tester.printToConsole('Item not visible: $keyId. Moving to the next.');
        continue;
      }

      await tester.pumpAndSettle();

      switch (item.runtimeType) {
        case TransactionListItem:
          final transactionItem = item as TransactionListItem;
          tester.printToConsole(transactionItem.formattedTitle);
          tester.printToConsole(transactionItem.formattedFiatAmount);
          tester.printToConsole('\n');
          await _verifyTransactionListItemDisplay(transactionItem, dashboardViewModel);
          break;

        case AnonpayTransactionListItem:
          await _verifyAnonpayTransactionListItemDisplay(item as AnonpayTransactionListItem);
          break;

        case TradeListItem:
          await _verifyTradeListItemDisplay(item as TradeListItem);
          break;

        case OrderListItem:
          await _verifyOrderListItemDisplay(item as OrderListItem);
          break;

        default:
          tester.printToConsole('Unhandled item type: ${item.runtimeType}');
      }
    }
  }

  Future<void> _verifyTransactionListItemDisplay(
    TransactionListItem item,
    DashboardViewModel dashboardViewModel,
  ) async {
    final keyId =
        '${dashboardViewModel.type.name}_transaction_history_item_${item.transaction.id}_key';

    if (item.hasTokens && item.assetOfTransaction == null) return;

    //* ==============Confirm it has the right key for this item ========
    commonTestCases.hasValueKey(keyId);

    //* ======Confirm it displays the properly formatted amount==========
    commonTestCases.findWidgetViaDescendant(
      of: find.byKey(ValueKey(keyId)),
      matching: find.text(item.formattedCryptoAmount),
    );

    //TODO(David): Check out inconsistencies, from Flutter?
    // //* ======Confirm it displays the properly formatted title===========
    // final transactionType = dashboardViewModel.getTransactionType(item.transaction);

    // final title = item.formattedTitle + item.formattedStatus + transactionType;

    // commonTestCases.findWidgetViaDescendant(
    //   of: find.byKey(ValueKey(keyId)),
    //   matching: find.text(title),
    // );

    //* ======Confirm it displays the properly formatted date============
    final formattedDate = DateFormat('HH:mm').format(item.transaction.date);
    commonTestCases.findWidgetViaDescendant(
      of: find.byKey(ValueKey(keyId)),
      matching: find.text(formattedDate),
    );

    //* ======Confirm it displays the properly formatted fiat amount=====
    final formattedFiatAmount =
        dashboardViewModel.balanceViewModel.isFiatDisabled ? '' : item.formattedFiatAmount;
    if (formattedFiatAmount.isNotEmpty) {
      commonTestCases.findWidgetViaDescendant(
        of: find.byKey(ValueKey(keyId)),
        matching: find.text(formattedFiatAmount),
      );
    }

    //* ======Confirm it displays the right image based on the transaction direction=====
    final imageToUse = item.transaction.direction == TransactionDirection.incoming
        ? 'assets/images/down_arrow.png'
        : 'assets/images/up_arrow.png';

    find.widgetWithImage(Container, AssetImage(imageToUse));
  }

  Future<void> _verifyAnonpayTransactionListItemDisplay(AnonpayTransactionListItem item) async {
    final keyId = 'anonpay_invoice_transaction_list_item_${item.transaction.invoiceId}_key';

    //* ==============Confirm it has the right key for this item ========
    commonTestCases.hasValueKey(keyId);

    //* ==============Confirm it displays the correct provider =========================
    commonTestCases.hasText(item.transaction.provider);

    //* ===========Confirm it displays the properly formatted amount with currency ========
    final currency = item.transaction.fiatAmount != null
        ? item.transaction.fiatEquiv ?? ''
        : CryptoCurrency.fromFullName(item.transaction.coinTo).name.toUpperCase();

    final amount =
        item.transaction.fiatAmount?.toString() ?? (item.transaction.amountTo?.toString() ?? '');

    final amountCurrencyText = amount + ' ' + currency;

    commonTestCases.hasText(amountCurrencyText);

    //* ======Confirm it displays the properly formatted date=================
    final formattedDate = DateFormat('HH:mm').format(item.transaction.createdAt);
    commonTestCases.hasText(formattedDate);

    //* ===============Confirm it displays the right image====================
    find.widgetWithImage(ClipRRect, AssetImage('assets/images/trocador.png'));
  }

  Future<void> _verifyTradeListItemDisplay(TradeListItem item) async {
    final keyId = 'trade_list_item_${item.trade.id}_key';

    //* ==============Confirm it has the right key for this item ========
    commonTestCases.hasValueKey(keyId);

    //* ==============Confirm it displays the correct provider =========================
    final conversionFlow = '${item.trade.from.toString()} → ${item.trade.to.toString()}';

    commonTestCases.hasText(conversionFlow);

    //* ===========Confirm it displays the properly formatted amount with its crypto tag ========

    final amountCryptoText = item.tradeFormattedAmount + ' ' + item.trade.from.toString();

    commonTestCases.hasText(amountCryptoText);

    //* ======Confirm it displays the properly formatted date=================
    final createdAtFormattedDate =
        item.trade.createdAt != null ? DateFormat('HH:mm').format(item.trade.createdAt!) : null;

    if (createdAtFormattedDate != null) {
      commonTestCases.hasText(createdAtFormattedDate);
    }

    //* ===============Confirm it displays the right image====================
    commonTestCases.hasValueKey(item.trade.provider.image);
  }

  Future<void> _verifyOrderListItemDisplay(OrderListItem item) async {
    final keyId = 'order_list_item_${item.order.id}_key';

    //* ==============Confirm it has the right key for this item ========
    commonTestCases.hasValueKey(keyId);

    //* ==============Confirm it displays the correct provider =========================
    final orderFlow = '${item.order.from!} → ${item.order.to}';

    commonTestCases.hasText(orderFlow);

    //* ===========Confirm it displays the properly formatted amount with its crypto tag ========

    final amountCryptoText = item.orderFormattedAmount + ' ' + item.order.to!;

    commonTestCases.hasText(amountCryptoText);

    //* ======Confirm it displays the properly formatted date=================
    final createdAtFormattedDate = DateFormat('HH:mm').format(item.order.createdAt);

    commonTestCases.hasText(createdAtFormattedDate);
  }
}
