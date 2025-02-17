import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/src/screens/exchange_trade/exchange_confirm_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../components/common_test_cases.dart';

class ExchangeConfirmPageRobot {
  ExchangeConfirmPageRobot(this.tester) : commonTestCases = CommonTestCases(tester);

  final WidgetTester tester;
  late CommonTestCases commonTestCases;

  Future<void> isExchangeConfirmPage() async {
    await commonTestCases.isSpecificPage<ExchangeConfirmPage>();
    await commonTestCases.takeScreenshots('exchange_confirm_page');
  }

  void confirmComponentsOfTradeDisplayProperly() {
    final ExchangeConfirmPage exchangeConfirmPage = tester.widget(find.byType(ExchangeConfirmPage));
    final trade = exchangeConfirmPage.trade;

    commonTestCases.hasText(trade.id);
    commonTestCases.hasText('${trade.provider.title} ${S.current.trade_id}');

    commonTestCases.hasValueKey('exchange_confirm_page_saved_id_button_key');
    commonTestCases.hasValueKey('exchange_confirm_page_copy_to_clipboard_button_key');
  }

  Future<void> confirmCopyTradeIdToClipBoardWorksProperly() async {
    final ExchangeConfirmPage exchangeConfirmPage = tester.widget(find.byType(ExchangeConfirmPage));
    final trade = exchangeConfirmPage.trade;

    await commonTestCases.tapItemByKey('exchange_confirm_page_copy_to_clipboard_button_key');

    ClipboardData? clipboardData = await Clipboard.getData('text/plain');

    expect(clipboardData?.text, trade.id);
  }

  Future<void> onSavedTradeIdButtonPressed() async {
    await tester.pumpAndSettle();
    await commonTestCases.defaultSleepTime();
    await commonTestCases.tapItemByKey('exchange_confirm_page_saved_id_button_key');
  }
}
