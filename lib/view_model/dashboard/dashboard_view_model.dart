import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cake_wallet/.secrets.g.dart' as secrets;
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/key_service.dart';
import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/entities/service_status.dart';
import 'package:cake_wallet/exchange/exchange_provider_description.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/utils/proxy_wrapper.dart';
import 'package:cake_wallet/utils/tor.dart';
import 'package:cake_wallet/wownero/wownero.dart' as wow;
import 'package:cake_wallet/nano/nano.dart';
import 'package:cake_wallet/store/anonpay/anonpay_transactions_store.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/dashboard/orders_store.dart';
import 'package:cake_wallet/store/dashboard/trade_filter_store.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
import 'package:cake_wallet/store/dashboard/transaction_filter_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/yat/yat_store.dart';
import 'package:cake_wallet/utils/mobx.dart';
import 'package:cake_wallet/view_model/dashboard/action_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/anonpay_transaction_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/balance_view_model.dart';
import 'package:cake_wallet/view_model/dashboard/filter_item.dart';
import 'package:cake_wallet/view_model/dashboard/formatted_item_list.dart';
import 'package:cake_wallet/view_model/dashboard/order_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/trade_list_item.dart';
import 'package:cake_wallet/view_model/dashboard/transaction_list_item.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/utils/file.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_wownero/api/wallet.dart';
import 'package:eth_sig_util/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tor/tor.dart';

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
      required this.anonpayTransactionsStore,
      required this.sharedPreferences,
      required this.keyService})
      : hasTradeAction = false,
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
            if (appStore.wallet!.type == WalletType.bitcoin)
              FilterItem(
                value: () => transactionFilterStore.displaySilentPayments,
                caption: S.current.silent_payments,
                onChanged: transactionFilterStore.toggleSilentPayments,
              ),
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
            FilterItem(
                value: () => tradeFilterStore.displayThorChain,
                caption: ExchangeProviderDescription.thorChain.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.thorChain)),
            FilterItem(
                value: () => tradeFilterStore.displayLetsExchange,
                caption: ExchangeProviderDescription.letsExchange.title,
                onChanged: () => tradeFilterStore
                    .toggleDisplayExchange(ExchangeProviderDescription.letsExchange)),
            FilterItem(
                value: () => tradeFilterStore.displayStealthEx,
                caption: ExchangeProviderDescription.stealthEx.title,
                onChanged: () =>
                    tradeFilterStore.toggleDisplayExchange(ExchangeProviderDescription.stealthEx)),
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

      final sortedTransactions = [..._accountTransactions];
      sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

      transactions = ObservableList.of(
        sortedTransactions.map(
          (transaction) => TransactionListItem(
            transaction: transaction,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore,
            key: ValueKey('monero_transaction_history_item_${transaction.id}_key'),
          ),
        ),
      );
    } else if (_wallet.type == WalletType.wownero) {
      subname = wow.wownero!.getCurrentAccount(_wallet).label;

      _onMoneroAccountChangeReaction = reaction(
          (_) => wow.wownero!.getWowneroWalletDetails(wallet).account,
          (wow.Account account) => _onMoneroAccountChange(_wallet));

      _onMoneroBalanceChangeReaction = reaction(
          (_) => wow.wownero!.getWowneroWalletDetails(wallet).balance,
          (wow.WowneroBalance balance) => _onMoneroTransactionsUpdate(_wallet));

      final _accountTransactions = _wallet.transactionHistory.transactions.values
          .where((tx) =>
              wow.wownero!.getTransactionInfoAccountId(tx) ==
              wow.wownero!.getCurrentAccount(wallet).id)
          .toList();

      final sortedTransactions = [..._accountTransactions];
      sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

      transactions = ObservableList.of(
        sortedTransactions.map(
          (transaction) => TransactionListItem(
            transaction: transaction,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore,
            key: ValueKey('wownero_transaction_history_item_${transaction.id}_key'),
          ),
        ),
      );
    } else {
      final sortedTransactions = [...wallet.transactionHistory.transactions.values];
      sortedTransactions.sort((a, b) => a.date.compareTo(b.date));

      transactions = ObservableList.of(
        sortedTransactions.map(
          (transaction) => TransactionListItem(
            transaction: transaction,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore,
            key: ValueKey('${_wallet.type.name}_transaction_history_item_${transaction.id}_key'),
          ),
        ),
      );
    }

    // TODO: nano sub-account generation is disabled:
    // if (_wallet.type == WalletType.nano || _wallet.type == WalletType.banano) {
    //   subname = nano!.getCurrentAccount(_wallet).label;
    // }

    reaction((_) => appStore.wallet, (wallet) {
      _onWalletChange(wallet);
      _checkMweb();
    });

    connectMapToListWithTransform(
        appStore.wallet!.transactionHistory.transactions,
        transactions,
        (TransactionInfo? transaction) => TransactionListItem(
              transaction: transaction!,
              balanceViewModel: balanceViewModel,
              settingsStore: appStore.settingsStore,
              key: ValueKey(
                '${_wallet.type.name}_transaction_history_item_${transaction.id}_key',
              ),
            ), filter: (TransactionInfo? transaction) {
      if (transaction == null) {
        return false;
      }

      final wallet = _wallet;
      if (wallet.type == WalletType.monero) {
        return monero!.getTransactionInfoAccountId(transaction) ==
            monero!.getCurrentAccount(wallet).id;
      }
      if (wallet.type == WalletType.wownero) {
        return wow.wownero!.getTransactionInfoAccountId(transaction) ==
            wow.wownero!.getCurrentAccount(wallet).id;
      }

      return true;
    });

    if (hasSilentPayments) {
      silentPaymentsScanningActive = bitcoin!.getScanningActive(wallet);

      reaction((_) => wallet.syncStatus, (SyncStatus syncStatus) {
        silentPaymentsScanningActive = bitcoin!.getScanningActive(wallet);
      });
    }

    _checkMweb();
    reaction((_) => settingsStore.mwebAlwaysScan, (bool value) {
      _checkMweb();
    });
  }

  void _checkMweb() {
    if (hasMweb) {
      mwebEnabled = bitcoin!.getMwebEnabled(wallet);
      balanceViewModel.mwebEnabled = mwebEnabled;
    }
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

  @computed
  bool get isTestnet => wallet.type == WalletType.bitcoin && bitcoin!.isTestnet(wallet);

  @computed
  bool get hasRescan =>
      wallet.type == WalletType.bitcoin ||
      wallet.type == WalletType.monero ||
      wallet.type == WalletType.litecoin ||
      wallet.type == WalletType.wownero ||
      wallet.type == WalletType.haven;

  @computed
  bool get isMoneroViewOnly {
    if (wallet.type != WalletType.monero) return false;
    return monero!.isViewOnly();
  }

  @computed
  String? get getMoneroError {
    if (wallet.type != WalletType.monero) return null;
    try {
      monero!.monerocCheck();
    } catch (e) {
      return e.toString();
    }
    return null;
  }

  @computed
  String? get getWowneroError {
    if (wallet.type != WalletType.wownero) return null;
    try {
      wow.wownero!.wownerocCheck();
    } catch (e) {
      return e.toString();
    }
    return null;
  }

  List<String> get isMoneroWalletBrokenReasons {
    if (wallet.type != WalletType.monero) return [];
    final keys = monero!.getKeys(wallet);
    List<String> errors = [
      // leaving these commented out for now, I'll be able to fix that properly in the airgap update
      // to not cause work duplication, this will do the job as well, it will be slightly less precise
      // about what happened - but still enough.
      // if (keys['privateSpendKey'] == List.generate(64, (index) => "0").join("")) "Private spend key is 0",
      if (keys['privateViewKey'] == List.generate(64, (index) => "0").join("") && !wallet.isHardwareWallet)
        "private view key is 0",
      // if (keys['publicSpendKey'] == List.generate(64, (index) => "0").join("")) "public spend key is 0",
      if (keys['publicViewKey'] == List.generate(64, (index) => "0").join(""))
        "public view key is 0",
      // if (wallet.seed == null) "wallet seed is null",
      // if (wallet.seed == "") "wallet seed is empty",
      if (monero!.getSubaddressList(wallet).getAll(wallet)[0].address ==
          "41d7FXjswpK1111111111111111111111111111111111111111111111111111111111111111111111111111112KhNi4")
        "primary address is invalid, you won't be able to receive / spend funds",
    ];
    return errors;
  }

  @computed
  bool get hasSilentPayments => wallet.type == WalletType.bitcoin && !wallet.isHardwareWallet;

  @computed
  bool get showSilentPaymentsCard => hasSilentPayments && settingsStore.silentPaymentsCardDisplay;

  final KeyService keyService;
  final SharedPreferences sharedPreferences;

  @observable
  bool silentPaymentsScanningActive = false;

  @action
  void setSilentPaymentsScanning(bool active) {
    silentPaymentsScanningActive = active;

    if (hasSilentPayments) {
      bitcoin!.setScanningActive(wallet, active);
    }
  }

  @computed
  bool get hasMweb =>
      wallet.type == WalletType.litecoin &&
      (Platform.isIOS || Platform.isAndroid) &&
      !wallet.isHardwareWallet;

  @computed
  bool get showMwebCard => hasMweb && settingsStore.mwebCardDisplay && !mwebEnabled;

  @observable
  bool mwebEnabled = false;

  @computed
  bool get hasEnabledMwebBefore => settingsStore.hasEnabledMwebBefore;

  @action
  void setMwebEnabled() {
    if (!hasMweb) {
      return;
    }

    settingsStore.hasEnabledMwebBefore = true;
    mwebEnabled = true;
    bitcoin!.setMwebEnabled(wallet, true);
    balanceViewModel.mwebEnabled = true;
    settingsStore.mwebAlwaysScan = true;
  }

  @action
  void dismissMweb() {
    settingsStore.mwebCardDisplay = false;
    balanceViewModel.mwebEnabled = false;
    settingsStore.mwebAlwaysScan = false;
    mwebEnabled = false;
    bitcoin!.setMwebEnabled(wallet, false);
  }

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

  bool get isBuyEnabled => settingsStore.isBitcoinBuyEnabled;

  bool get shouldShowYatPopup => settingsStore.shouldShowYatPopup;

  @action
  void furtherShowYatPopup(bool shouldShow) => settingsStore.shouldShowYatPopup = shouldShow;

  @computed
  bool get isEnabledExchangeAction => settingsStore.exchangeStatus != ExchangeApiMode.disabled;

  @observable
  bool hasExchangeAction;

  @computed
  bool get isEnabledTradeAction => !settingsStore.disableTradeOption;

  @observable
  bool hasTradeAction;

  @computed
  bool get isEnabledBulletinAction => !settingsStore.disableBulletin;

  ReactionDisposer? _onMoneroAccountChangeReaction;

  ReactionDisposer? _onMoneroBalanceChangeReaction;

  @computed
  bool get hasPowNodes => wallet.type == WalletType.nano || wallet.type == WalletType.banano;

  @computed
  bool get hasSignMessages {
    if (wallet.isHardwareWallet) {
      return false;
    }
    switch (wallet.type) {
      case WalletType.monero:
      case WalletType.litecoin:
      case WalletType.bitcoin:
      case WalletType.bitcoinCash:
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.nano:
      case WalletType.banano:
      case WalletType.tron:
      case WalletType.wownero:
        return true;
      case WalletType.haven:
      case WalletType.none:
        return false;
    }
  }

  bool get showRepWarning {
    if (wallet.type != WalletType.nano) {
      return false;
    }

    if (!settingsStore.shouldShowRepWarning) {
      return false;
    }

    return !nano!.isRepOk(wallet);
  }

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
    } else if (wallet.type == WalletType.wownero) {
      subname = wow.wownero!.getCurrentAccount(wallet).label;

      _onMoneroAccountChangeReaction?.reaction.dispose();
      _onMoneroBalanceChangeReaction?.reaction.dispose();

      _onMoneroAccountChangeReaction = reaction(
          (_) => wow.wownero!.getWowneroWalletDetails(wallet).account,
          (wow.Account account) => _onMoneroAccountChange(wallet));

      _onMoneroBalanceChangeReaction = reaction(
          (_) => wow.wownero!.getWowneroWalletDetails(wallet).balance,
          (wow.WowneroBalance balance) => _onMoneroTransactionsUpdate(wallet));

      _onMoneroTransactionsUpdate(wallet);
    } else {
      // FIX-ME: Check for side effects
      // subname = null;
      subname = '';

      transactions.clear();

      transactions.addAll(
        wallet.transactionHistory.transactions.values.map(
          (transaction) => TransactionListItem(
            transaction: transaction,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore,
            key: ValueKey('${wallet.type.name}_transaction_history_item_${transaction.id}_key'),
          ),
        ),
      );
    }

    connectMapToListWithTransform(
        appStore.wallet!.transactionHistory.transactions,
        transactions,
        (TransactionInfo? transaction) => TransactionListItem(
              transaction: transaction!,
              balanceViewModel: balanceViewModel,
              settingsStore: appStore.settingsStore,
              key: ValueKey(
                '${wallet.type.name}_transaction_history_item_${transaction.id}_key',
              ),
            ), filter: (TransactionInfo? tx) {
      if (tx == null) {
        return false;
      }

      if (wallet.type == WalletType.monero) {
        return monero!.getTransactionInfoAccountId(tx) == monero!.getCurrentAccount(wallet).id;
      }

      if (wallet.type == WalletType.wownero) {
        return wow.wownero!.getTransactionInfoAccountId(tx) ==
            wow.wownero!.getCurrentAccount(wallet).id;
      }

      return true;
    });
  }

  @action
  void _onMoneroAccountChange(WalletBase wallet) {
    if (wallet.type == WalletType.monero) {
      subname = monero!.getCurrentAccount(wallet).label;
    } else if (wallet.type == WalletType.wownero) {
      subname = wow.wownero!.getCurrentAccount(wallet).label;
    }
    _onMoneroTransactionsUpdate(wallet);
  }

  @action
  void _onMoneroTransactionsUpdate(WalletBase wallet) {
    transactions.clear();
    if (wallet.type == WalletType.monero) {
      final _accountTransactions = monero!
          .getTransactionHistory(wallet)
          .transactions
          .values
          .where((tx) =>
              monero!.getTransactionInfoAccountId(tx) == monero!.getCurrentAccount(wallet).id)
          .toList();

      transactions.addAll(
        _accountTransactions.map(
          (transaction) => TransactionListItem(
            transaction: transaction,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore,
            key: ValueKey('monero_transaction_history_item_${transaction.id}_key'),
          ),
        ),
      );
    } else if (wallet.type == WalletType.wownero) {
      final _accountTransactions = wow.wownero!
          .getTransactionHistory(wallet)
          .transactions
          .values
          .where((tx) =>
              wow.wownero!.getTransactionInfoAccountId(tx) ==
              wow.wownero!.getCurrentAccount(wallet).id)
          .toList();

      transactions.addAll(
        _accountTransactions.map(
          (transaction) => TransactionListItem(
            transaction: transaction,
            balanceViewModel: balanceViewModel,
            settingsStore: appStore.settingsStore,
            key: ValueKey('wownero_transaction_history_item_${transaction.id}_key'),
          ),
        ),
      );
    }
  }

  void updateActions() {
    hasExchangeAction = !isHaven;
    hasTradeAction = !isHaven;
  }

  @computed
  SyncMode get syncMode => settingsStore.currentSyncMode;

  @action
  void setSyncMode(SyncMode syncMode) => settingsStore.currentSyncMode = syncMode;

  @computed
  bool get syncAll => settingsStore.currentSyncAll;

  @computed
  bool get builtinTor => settingsStore.currentBuiltinTor;

  @action
  void setBuiltinTor(bool value, BuildContext context) {
    settingsStore.currentBuiltinTor = value;
    if (value) {
      unawaited(ensureTorStarted(context: context).then((_) async {
        if (settingsStore.currentBuiltinTor == false) return; // return when tor got disabled in the meantime;
        await wallet.connectToNode(node: appStore.settingsStore.getCurrentNode(wallet.type));
      }));
    } else {
      unawaited(ensureTorStopped(context: context).then((_) async {
        if (settingsStore.currentBuiltinTor == true) return; // return when tor got enabled in the meantime;
        await wallet.connectToNode(node: appStore.settingsStore.getCurrentNode(wallet.type));
      }));
    }
  }
  
  @action
  void setSyncAll(bool value) => settingsStore.currentSyncAll = value;

  Future<List<String>> checkForHavenWallets() async {
    final walletInfoSource = await CakeHive.openBox<WalletInfo>(WalletInfo.boxName);
    return walletInfoSource.values
        .where((element) => element.type == WalletType.haven)
        .map((e) => e.name)
        .toList();
  }

  Future<List<String>> checkAffectedWallets() async {
    try {
      // await load file
      final vulnerableSeedsString = await rootBundle
          .loadString('assets/text/cakewallet_weak_bitcoin_seeds_hashed_sorted_version1.txt');
      final vulnerableSeeds = vulnerableSeedsString.split("\n");

      final walletInfoSource = await CakeHive.openBox<WalletInfo>(WalletInfo.boxName);

      List<String> affectedWallets = [];
      for (var walletInfo in walletInfoSource.values) {
        if (walletInfo.type == WalletType.bitcoin) {
          final password = await keyService.getWalletPassword(walletName: walletInfo.name);
          final path = await pathForWallet(name: walletInfo.name, type: walletInfo.type);
          final jsonSource = await read(path: path, password: password);
          final data = json.decode(jsonSource) as Map;
          final mnemonic = data['mnemonic'] as String?;

          if (mnemonic == null) continue;

          final hash = await Cryptography.instance.sha256().hash(utf8.encode(mnemonic));
          final seedSha = bytesToHex(hash.bytes);

          if (vulnerableSeeds.contains(seedSha)) {
            affectedWallets.add(walletInfo.name);
          }
        }
      }

      return affectedWallets;
    } catch (_) {
      return [];
    }
  }

  Future<ServicesResponse> getServicesStatus() async {
    try {
      if (isEnabledBulletinAction) {
        final uri = Uri.https(
          "service-api.cakewallet.com",
          "/v1/active-notices",
          {'key': secrets.fiatApiKey},
        );

        final res = await ProxyWrapper().get(clearnetUri: uri);
        final responseString = await res.transform(utf8.decoder).join();
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw responseString;
        }

        final oldSha = sharedPreferences.getString(PreferencesKey.serviceStatusShaKey);

        final hash = await Cryptography.instance.sha256().hash(utf8.encode(responseString));
        final currentSha = bytesToHex(hash.bytes);

        final hasUpdates = oldSha != currentSha;

        return ServicesResponse.fromJson(
          json.decode(responseString) as Map<String, dynamic>,
          hasUpdates,
          currentSha,
        );
      } else {
        return ServicesResponse([], false, '');
      }
    } catch (e) {
      return ServicesResponse([], false, '');
    }
  }

  String getTransactionType(TransactionInfo tx) {
    if (wallet.type == WalletType.bitcoin) {
      if (tx.isReplaced == true) return ' (replaced)';
    }

    if (wallet.type == WalletType.ethereum && tx.evmSignatureName == 'approval')
      return ' (${tx.evmSignatureName})';
    return '';
  }

  Future<void> refreshDashboard() async {
    reconnect();
  }
}
