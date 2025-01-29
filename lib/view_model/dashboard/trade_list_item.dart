import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/dashboard/action_list_item.dart';

class TradeListItem extends ActionListItem {
  TradeListItem({
    required this.trade,
    required this.settingsStore,
    required super.key,
  });

  final Trade trade;
  final SettingsStore settingsStore;

  BalanceDisplayMode get displayMode => settingsStore.balanceDisplayMode;

  String get tradeFormattedAmount =>
      displayMode == BalanceDisplayMode.hiddenBalance ? '---' : trade.amountFormatted();

  String get tradeFormattedReceiveAmount =>
      displayMode == BalanceDisplayMode.hiddenBalance ? '---' : trade.receiveAmountFormatted();
  
  @override
  DateTime get date => trade.createdAt!;
}
