import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/buy_provider_types.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/exchange_provider_types.dart';
import 'package:cake_wallet/store/anonpay/anonpay_transactions_store.dart';
import 'package:cake_wallet/view_model/dashboard/anonpay_transaction_list_item.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/dashboard/orders_store.dart';
import 'package:cake_wallet/store/dashboard/trade_filter_store.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
import 'package:cake_wallet/store/dashboard/transaction_filter_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/yat/yat_store.dart';
import 'package:cake_wallet/utils/mobx.dart';
import 'package:cake_wallet/view_model/dashboard/action_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/filter_item.dart';
import 'package:cake_wallet/view_model/dashboard/formatted_item_list.dart';
import 'package:cake_wallet/view_model/dashboard/order_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/trade_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/transaction_list_item.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'dashboard_view_model.g.dart';

class DashboardViewModel = DashboardViewModelBase with _$DashboardViewModel;

abstract class DashboardViewModelBase with Store {
  DashboardViewModelBase(
      {required this.balanceViewModel,
      required this.appStore,
      required this.tradesStore,
      required this.tradeFilterStore,
      required this.transactionFilterStore,
      required this.settingsStore,
      required this.yatStore,
      required this.ordersStore,
      required this.anonpayTransactionsStore})
      : hasSellAction = false,
        hasBuyAction = false,
        hasExchangeAction = false,
        isShowFirstYatIntroduction = false,
        isShowSecondYatIntroduction = false,
        isShowThirdYatIntroduction = false,
        filterItems = {
          S.current.transactions: [
            FilterItem(
                value: () => transactionFilterStore.displayAll,
                caption: S.current.all_transactions,
                onChanged: transactionFilterStore.toggleAll),
            FilterItem(
                value: () => transactionFilterStore.displayIncoming,
                caption: S.current.incoming,
                onChanged: transactionFilterStore.toggleIncoming),
            FilterItem(
                value: () => transactionFilterStore.displayOutgoing,
                caption: S.current.outgoing,
                onChanged: transactionFilterStore.toggleOutgoing),
            // FilterItem(
            //     value: () => false,
            //     caption: S.current.transactions_by_date,
            //     onChanged: null),
          ],
          S.current.trades: [
            FilterItem(
                value: () => tradeFilterStore.displayAllTrades,
                caption: S.current.all_trades,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.all)),
            FilterItem(
                value: () => tradeFilterStore.displayChangeNow,
                caption: ExchangeProviderDescription.changeNow.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.changeNow)),
            FilterItem(
                value: () => tradeFilterStore.displaySideShift,
                caption: ExchangeProviderDescription.sideShift.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.sideShift)),
            FilterItem(
                value: () => tradeFilterStore.displaySimpleSwap,
                caption: ExchangeProviderDescription.simpleSwap.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.simpleSwap)),
            FilterItem(
                value: () => tradeFilterStore.displayTrocador,
                caption: ExchangeProviderDescription.trocador.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.trocador)),
            FilterItem(
                value: () => tradeFilterStore.displayExolix,
                caption: ExchangeProviderDescription.exolix.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.exolix)),
          ]
        },
        subname = '',
        name = appStore.wallet!.name,
        type = appStore.wallet!.type,
        transactions = ObservableList<TransactionListItem>(),
        wallet = appStore.wallet! {
    name = wallet.name;
    type = wallet.type;
    isShowFirstYatIntroduction = false;
    isShowSecondYatIntroduction = false;
    isShowThirdYatIntroduction = false;
    updateActions();

    final _wallet = wallet;

    if (_wallet.type == WalletType.monero) {
      subname = monero!.getCurrentAccount(_wallet).label;

      _onMoneroAccountChangeReaction = reaction(
          (_) => monero!.getMoneroWalletDetails(wallet).account,
          (Account account) => _onMoneroAccountChange(_wallet));

      _onMoneroBalanceChangeReaction = reaction(
          (_) => monero!.getMoneroWalletDetails(wallet).balance,
          (MoneroBalance balance) => _onMoneroTransactionsUpdate(_wallet));

      final _accountTransactions = _wallet.transactionHistory.transactions.values
          .where((tx) =>
              monero!.getTransactionInfoAccountId(tx) == monero!.getCurrentAccount(wallet).id)
          .toList();

      transactions = ObservableList.of(_accountTransactions.map((transaction) =>
          TransactionListItem(
              transaction: transaction,
              balanceViewModel: balanceViewModel,
              settingsStore: appStore.settingsStore)));
    } else {
      transactions = ObservableList.of(wallet.transactionHistory.transactions.values.map(
          (transaction) => TransactionListItem(
              transaction: transaction,
              balanceViewModel: balanceViewModel,
              settingsStore: appStore.settingsStore)));
    }

    // TODO: nano sub-account generation is disabled:
    // if (_wallet.type == WalletType.nano || _wallet.type == WalletType.banano) {
    //   subname = nano!.getCurrentAccount(_wallet).label;
    // }

    reaction((_) => appStore.wallet, _onWalletChange);

    connectMapToListWithTransform(
        appStore.wallet!.transactionHistory.transactions,
        transactions,
        (TransactionInfo? transaction) => TransactionListItem(
            transaction: transaction!,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore), filter: (TransactionInfo? transaction) {
      if (transaction == null) {
        return false;
      }

      final wallet = _wallet;
      if (wallet.type == WalletType.monero) {
        return monero!.getTransactionInfoAccountId(transaction) ==
            monero!.getCurrentAccount(wallet).id;
      }

      return true;
    });
  }

  @observable
  WalletType type;

  @observable
  String name;

  @observable
  ObservableList<TransactionListItem> transactions;

  @observable
  String subname;

  @observable
  bool isShowFirstYatIntroduction;

  @observable
  bool isShowSecondYatIntroduction;

  @observable
  bool isShowThirdYatIntroduction;

  @computed
  String get address => wallet.walletAddresses.address;

  @computed
  SyncStatus get status => wallet.syncStatus;

  @computed
  String get syncStatusText {
    var statusText = '';

    if (status is SyncingSyncStatus) {
      statusText = S.current.Blocks_remaining(status.toString());
    }

    if (status is FailedSyncStatus || status is LostConnectionSyncStatus) {
      statusText = S.current.please_try_to_connect_to_another_node;
    }

    return statusText;
  }

  @computed
  BalanceDisplayMode get balanceDisplayMode => appStore.settingsStore.balanceDisplayMode;

  @computed
  bool get shouldShowMarketPlaceInDashboard =>
      appStore.settingsStore.shouldShowMarketPlaceInDashboard;

  @computed
  List<TradeListItem> get trades =>
      tradesStore.trades.where((trade) => trade.trade.walletId == wallet.id).toList();

  @computed
  List<OrderListItem> get orders =>
      ordersStore.orders.where((item) => item.order.walletId == wallet.id).toList();

  @computed
  List<AnonpayTransactionListItem> get anonpayTransactons => anonpayTransactionsStore.transactions
      .where((item) => item.transaction.walletId == wallet.id)
      .toList();

  @computed
  double get price => balanceViewModel.price;

  @computed
  bool get isAutoGenerateSubaddressesEnabled =>
      settingsStore.autoGenerateSubaddressStatus != AutoGenerateSubaddressStatus.disabled;

  @computed
  List<ActionListItem> get items {
    final _items = <ActionListItem>[];

    _items.addAll(
        transactionFilterStore.filtered(transactions: [...transactions, ...anonpayTransactons]));
    _items.addAll(tradeFilterStore.filtered(trades: trades, wallet: wallet));
    _items.addAll(orders);

    return formattedItemsList(_items);
  }

  @observable
  WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet;

  bool get hasRescan => wallet.type == WalletType.monero || wallet.type == WalletType.haven;

  BalanceViewModel balanceViewModel;

  AppStore appStore;

  SettingsStore settingsStore;

  YatStore yatStore;

  TradesStore tradesStore;

  OrdersStore ordersStore;

  TradeFilterStore tradeFilterStore;

  AnonpayTransactionsStore anonpayTransactionsStore;

  TransactionFilterStore transactionFilterStore;

  Map<String, List<FilterItem>> filterItems;

  BuyProviderType get defaultBuyProvider => settingsStore.defaultBuyProvider;

  ExchangeProviderType get defaultExchangeProvider => settingsStore.defaultExchangeProvider;

  bool get isBuyEnabled => settingsStore.isBitcoinBuyEnabled;

  bool get shouldShowYatPopup => settingsStore.shouldShowYatPopup;

  @action
  void furtherShowYatPopup(bool shouldShow) => settingsStore.shouldShowYatPopup = shouldShow;

  @computed
  bool get isEnabledExchangeAction => settingsStore.exchangeStatus != ExchangeApiMode.disabled;

  @observable
  bool hasExchangeAction;

  @computed
  bool get isEnabledBuyAction => !settingsStore.disableBuy && wallet.type != WalletType.haven;

  @observable
  bool hasBuyAction;

  @computed
  bool get isEnabledSellAction =>
      !settingsStore.disableSell &&
      wallet.type != WalletType.haven &&
      wallet.type != WalletType.monero;

  @observable
  bool hasSellAction;

  ReactionDisposer? _onMoneroAccountChangeReaction;

  ReactionDisposer? _onMoneroBalanceChangeReaction;

  @computed
  bool get hasPowNodes => wallet.type == WalletType.nano || wallet.type == WalletType.banano;

  Future<void> reconnect() async {
    final node = appStore.settingsStore.getCurrentNode(wallet.type);
    await wallet.connectToNode(node: node);
    if (hasPowNodes) {
      final powNode = settingsStore.getCurrentPowNode(wallet.type);
      await wallet.connectToPowNode(node: powNode);
    }
  }

  @action
  void _onWalletChange(
      WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>? wallet) {
    if (wallet == null) {
      return;
    }

    this.wallet = wallet;
    type = wallet.type;
    name = wallet.name;
    updateActions();

    if (wallet.type == WalletType.monero) {
      subname = monero!.getCurrentAccount(wallet).label;

      _onMoneroAccountChangeReaction?.reaction.dispose();
      _onMoneroBalanceChangeReaction?.reaction.dispose();

      _onMoneroAccountChangeReaction = reaction(
          (_) => monero!.getMoneroWalletDetails(wallet).account,
          (Account account) => _onMoneroAccountChange(wallet));

      _onMoneroBalanceChangeReaction = reaction(
          (_) => monero!.getMoneroWalletDetails(wallet).balance,
          (MoneroBalance balance) => _onMoneroTransactionsUpdate(wallet));

      _onMoneroTransactionsUpdate(wallet);
    } else {
      // FIX-ME: Check for side effects
      // subname = null;
      subname = '';

      transactions.clear();

      transactions.addAll(wallet.transactionHistory.transactions.values.map((transaction) =>
          TransactionListItem(
              transaction: transaction,
              balanceViewModel: balanceViewModel,
              settingsStore: appStore.settingsStore)));
    }

    connectMapToListWithTransform(
        appStore.wallet!.transactionHistory.transactions,
        transactions,
        (TransactionInfo? transaction) => TransactionListItem(
            transaction: transaction!,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore), filter: (TransactionInfo? tx) {
      if (tx == null) {
        return false;
      }

      if (wallet.type == WalletType.monero) {
        return monero!.getTransactionInfoAccountId(tx) == monero!.getCurrentAccount(wallet).id;
      }

      return true;
    });
  }

  @action
  void _onMoneroAccountChange(WalletBase wallet) {
    subname = monero!.getCurrentAccount(wallet).label;
    _onMoneroTransactionsUpdate(wallet);
  }

  @action
  void _onMoneroTransactionsUpdate(WalletBase wallet) {
    transactions.clear();

    final _accountTransactions = monero!
        .getTransactionHistory(wallet)
        .transactions
        .values
        .where(
            (tx) => monero!.getTransactionInfoAccountId(tx) == monero!.getCurrentAccount(wallet).id)
        .toList();

    transactions.addAll(_accountTransactions.map((transaction) => TransactionListItem(
        transaction: transaction,
        balanceViewModel: balanceViewModel,
        settingsStore: appStore.settingsStore)));
  }

  void updateActions() {
    hasExchangeAction = !isHaven;
    hasBuyAction = !isHaven;
    hasSellAction = !isHaven;
  }

  @computed
  SyncMode get syncMode => settingsStore.currentSyncMode;

  @action
  void setSyncMode(SyncMode syncMode) => settingsStore.currentSyncMode = syncMode;

  @computed
  bool get syncAll => settingsStore.currentSyncAll;

  @action
  void setSyncAll(bool value) => settingsStore.currentSyncAll = value;
}
