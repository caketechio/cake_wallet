import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/exchange/sideshift/sideshift_exchange_provider.dart';
import 'package:cake_wallet/exchange/sideshift/sideshift_request.dart';
import 'package:cake_wallet/exchange/simpleswap/simpleswap_exchange_provider.dart';
import 'package:cake_wallet/exchange/simpleswap/simpleswap_request.dart';
import 'package:cake_wallet/exchange/trocador/trocador_exchange_provider.dart';
import 'package:cake_wallet/exchange/trocador/trocador_request.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/exchange/exchange_provider.dart';
import 'package:cake_wallet/exchange/limits.dart';
import 'package:cake_wallet/exchange/trade.dart';
import 'package:cake_wallet/exchange/limits_state.dart';
import 'package:cake_wallet/store/dashboard/trades_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:hive/hive.dart';
import 'package:cake_wallet/exchange/exchange_trade_state.dart';
import 'package:cake_wallet/exchange/changenow/changenow_exchange_provider.dart';
import 'package:cake_wallet/exchange/changenow/changenow_request.dart';
import 'package:cake_wallet/exchange/trade_request.dart';
import 'package:cake_wallet/exchange/xmrto/xmrto_exchange_provider.dart';
import 'package:cake_wallet/exchange/xmrto/xmrto_trade_request.dart';
import 'package:cake_wallet/exchange/morphtoken/morphtoken_exchange_provider.dart';
import 'package:cake_wallet/exchange/morphtoken/morphtoken_request.dart';
import 'package:cake_wallet/store/templates/exchange_template_store.dart';
import 'package:cake_wallet/exchange/exchange_template.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'exchange_view_model.g.dart';

class ExchangeViewModel = ExchangeViewModelBase with _$ExchangeViewModel;

abstract class ExchangeViewModelBase with Store {
  ExchangeViewModelBase(this.wallet, this.trades, this._exchangeTemplateStore,
      this.tradesStore, this._settingsStore, this.sharedPreferences)
    : _cryptoNumberFormat = NumberFormat(),
      isFixedRateMode = false,
      isReceiveAmountEntered = false,
      depositAmount = '',
      receiveAmount = '',
      receiveAddress = '',
      depositAddress = '',
      isDepositAddressEnabled = false,
      isReceiveAddressEnabled = false,
      isReceiveAmountEditable = false,
      _useTorOnly = false,
      receiveCurrencies = <CryptoCurrency>[],
      depositCurrencies = <CryptoCurrency>[],
      limits = Limits(min: 0, max: 0),
      tradeState = ExchangeTradeStateInitial(),
      limitsState = LimitsInitialState(),
      receiveCurrency = wallet.currency,
      depositCurrency = wallet.currency,
      providerList = [],
      selectedProviders = ObservableList<ExchangeProvider>() {
    _useTorOnly = _settingsStore.exchangeStatus == ExchangeApiMode.torOnly;
    _setProviders();
    const excludeDepositCurrencies = [CryptoCurrency.btt, CryptoCurrency.nano];
    const excludeReceiveCurrencies = [CryptoCurrency.xlm, CryptoCurrency.xrp,
      CryptoCurrency.bnb, CryptoCurrency.btt, CryptoCurrency.nano];
    _initialPairBasedOnWallet();

    final Map<String, dynamic> exchangeProvidersSelection = json
        .decode(sharedPreferences.getString(PreferencesKey.exchangeProvidersSelection) ?? "{}") as Map<String, dynamic>;

    /// if the provider is not in the user settings (user's first time or newly added provider)
    /// then use its default value decided by us
    selectedProviders = ObservableList.of(providersForCurrentPair().where(
            (element) => exchangeProvidersSelection[element.title] == null
            ? element.isEnabled
            : (exchangeProvidersSelection[element.title] as bool))
        .toList());

    _setAvailableProviders();
    _calculateBestRate();

    bestRateSync = Timer.periodic(Duration(seconds: 10), (timer) => _calculateBestRate());

    isDepositAddressEnabled = !(depositCurrency == wallet.currency);
    isReceiveAddressEnabled = !(receiveCurrency == wallet.currency);
    depositAmount = '';
    receiveAmount = '';
    receiveAddress = '';
    depositAddress = depositCurrency == wallet.currency
        ? wallet.walletAddresses.address : '';
    _cryptoNumberFormat = NumberFormat()..maximumFractionDigits = wallet.type == WalletType.bitcoin ? 8 : 12;
    provider = providersForCurrentPair().first;
    final initialProvider = provider;
    provider!.checkIsAvailable().then((bool isAvailable) {
      if (!isAvailable && provider == initialProvider) {
        provider = providerList.firstWhere(
            (provider) => provider is ChangeNowExchangeProvider,
            orElse: () => providerList.last);
        _onPairChange();
      }
    });
    receiveCurrencies = CryptoCurrency.all
      .where((cryptoCurrency) => !excludeReceiveCurrencies.contains(cryptoCurrency))
      .toList();
    depositCurrencies = CryptoCurrency.all
      .where((cryptoCurrency) => !excludeDepositCurrencies.contains(cryptoCurrency))
      .toList();
    _defineIsReceiveAmountEditable();
    loadLimits();
    reaction(
      (_) => isFixedRateMode,
      (Object _) {
        loadLimits();
        _bestRate = 0;
        _calculateBestRate();
      });
  }
  bool _useTorOnly;
  final WalletBase wallet;
  final Box<Trade> trades;
  final ExchangeTemplateStore _exchangeTemplateStore;
  final TradesStore tradesStore;
  final SharedPreferences sharedPreferences;

  List<ExchangeProvider> get _allProviders => [
        ChangeNowExchangeProvider(),
        SideShiftExchangeProvider(),
        SimpleSwapExchangeProvider(),
        TrocadorExchangeProvider(useTorOnly: _useTorOnly),
      ];

  @observable
  ExchangeProvider? provider;

  /// Maps in dart are not sorted by default
  /// SplayTreeMap is a map sorted by keys
  /// will use it to sort available providers
  /// based on the rate they yield for the current trade
  ///
  ///
  /// initialize with descending comparator
  /// since we want largest rate first
  final SplayTreeMap<double, ExchangeProvider> _sortedAvailableProviders =
          SplayTreeMap<double, ExchangeProvider>((double a, double b) => b.compareTo(a));

  final List<ExchangeProvider> _tradeAvailableProviders = [];

  @observable
  ObservableList<ExchangeProvider> selectedProviders;

  @observable
  List<ExchangeProvider> providerList;

  @observable
  CryptoCurrency depositCurrency;

  @observable
  CryptoCurrency receiveCurrency;

  @observable
  LimitsState limitsState;

  @observable
  ExchangeTradeState tradeState;

  @observable
  String depositAmount;

  @observable
  String receiveAmount;

  @observable
  String depositAddress;

  @observable
  String receiveAddress;

  @observable
  bool isDepositAddressEnabled;

  @observable
  bool isReceiveAddressEnabled;

  @observable
  bool isReceiveAmountEntered;

  @observable
  bool isReceiveAmountEditable;

  @observable
  bool isFixedRateMode;

  @computed
  SyncStatus get status => wallet.syncStatus;

  @computed
  ObservableList<ExchangeTemplate> get templates =>
      _exchangeTemplateStore.templates;


  @computed
  TransactionPriority get transactionPriority {
    final priority = _settingsStore.priority[wallet.type];

    if (priority == null) {
      throw Exception('Unexpected type ${wallet.type.toString()}');
    }

    return priority;
  }


  bool get hasAllAmount =>
      wallet.type == WalletType.bitcoin && depositCurrency == wallet.currency;

  bool get isMoneroWallet  => wallet.type == WalletType.monero;

  bool get isLowFee  {
    switch (wallet.type) {
      case WalletType.monero:
      case WalletType.haven:
        return transactionPriority == monero!.getMoneroTransactionPrioritySlow();
      case WalletType.bitcoin:
        return transactionPriority == bitcoin!.getBitcoinTransactionPrioritySlow();
      case WalletType.litecoin:
        return transactionPriority == bitcoin!.getLitecoinTransactionPrioritySlow();
      default:
        return false;
    }
  }

  List<CryptoCurrency> receiveCurrencies;

  List<CryptoCurrency> depositCurrencies;

  Limits limits;

  NumberFormat _cryptoNumberFormat;

  final SettingsStore _settingsStore;

  double _bestRate = 0.0;

  late Timer bestRateSync;

  @action
  void changeDepositCurrency({required CryptoCurrency currency}) {
    depositCurrency = currency;
    isFixedRateMode = false;
    _onPairChange();
    isDepositAddressEnabled = !(depositCurrency == wallet.currency);
    isReceiveAddressEnabled = !(receiveCurrency == wallet.currency);
  }

  @action
  void changeReceiveCurrency({required CryptoCurrency currency}) {
    receiveCurrency = currency;
    isFixedRateMode = false;
    _onPairChange();
    isDepositAddressEnabled = !(depositCurrency == wallet.currency);
    isReceiveAddressEnabled = !(receiveCurrency == wallet.currency);
  }

  @action
  Future<void> changeReceiveAmount({required String amount}) async {
    receiveAmount = amount;

    if (amount.isEmpty) {
      depositAmount = '';
      receiveAmount = '';
      return;
    }

    final _enteredAmount = double.tryParse(amount.replaceAll(',', '.')) ?? 0;

    if (_bestRate == 0) {
      depositAmount = S.current.fetching;

      await _calculateBestRate();
    }

    depositAmount = _cryptoNumberFormat
        .format(_enteredAmount / _bestRate)
        .toString()
        .replaceAll(RegExp('\\,'), '');
  }

  @action
  Future<void> changeDepositAmount({required String amount}) async {
    depositAmount = amount;

    if (amount.isEmpty) {
      depositAmount = '';
      receiveAmount = '';
      return;
    }

    final _enteredAmount = double.tryParse(amount.replaceAll(',', '.')) ?? 0;

    /// in case the best rate was not calculated yet
    if (_bestRate == 0) {
      receiveAmount = S.current.fetching;

      await _calculateBestRate();
    }

    receiveAmount = _cryptoNumberFormat
        .format(_bestRate * _enteredAmount)
        .toString()
        .replaceAll(RegExp('\\,'), '');
  }

  Future<void> _calculateBestRate() async {
    final amount = double.tryParse(isFixedRateMode ? receiveAmount : depositAmount) ?? 1;

    final _providers = _tradeAvailableProviders
        .where((element) => !isFixedRateMode || element.supportsFixedRate).toList();

    final result = await Future.wait<double>(
        _providers.map((element) => element.fetchRate(
                from: depositCurrency,
                to: receiveCurrency,
                amount: amount,
                isFixedRateMode: isFixedRateMode,
                isReceiveAmount: isFixedRateMode))
    );

    _sortedAvailableProviders.clear();

    for (int i=0;i<result.length;i++) {
      if (result[i] != 0) {
        /// add this provider as its valid for this trade
        try {
          _sortedAvailableProviders[result[i]] = _providers[i];
        } catch (e) {
          // will throw "Concurrent modification during iteration" error if modified at the same
          // time [createTrade] is called, as this is not a normal map, but a sorted map
        }
      }
    }
    if (_sortedAvailableProviders.isNotEmpty) {
      _bestRate = _sortedAvailableProviders.keys.first;
    }
  }

  @action
  Future<void> loadLimits() async {
    if (selectedProviders.isEmpty) {
      return;
    }

    limitsState = LimitsIsLoading();

    final from = isFixedRateMode
        ? receiveCurrency
        : depositCurrency;
    final to = isFixedRateMode
        ? depositCurrency
        : receiveCurrency;

    double? lowestMin = double.maxFinite;
    double? highestMax = 0.0;

    for (var provider in selectedProviders) {
      /// if this provider is not valid for the current pair, skip it
      if (!providersForCurrentPair().contains(provider)) {
        continue;
      }

      try {
        final tempLimits = await provider.fetchLimits(
            from: from,
            to: to,
            isFixedRateMode: isFixedRateMode);

        if (lowestMin != null && (tempLimits.min ?? -1) < lowestMin) {
          lowestMin = tempLimits.min;
        }
        if (highestMax != null && (tempLimits.max ?? double.maxFinite) > highestMax) {
          highestMax = tempLimits.max;
        }
      } catch (e) {
        continue;
      }
    }

    if (lowestMin != double.maxFinite) {
      limits = Limits(min: lowestMin, max: highestMax);

      limitsState = LimitsLoadedSuccessfully(limits: limits);
    } else {
      limitsState = LimitsLoadedFailure(error: 'Limits loading failed');
    }
  }

  @action
  Future<void> createTrade() async {
    TradeRequest? request;
    String amount = '';

    try {
      for (var provider in _sortedAvailableProviders.values) {
        if (!(await provider.checkIsAvailable())) {
          continue;
        }

        if (provider is SideShiftExchangeProvider) {
          request = SideShiftRequest(
            depositMethod: depositCurrency,
            settleMethod: receiveCurrency,
            depositAmount: depositAmount.replaceAll(',', '.'),
            settleAddress: receiveAddress,
            refundAddress: depositAddress,
          );
          amount = isFixedRateMode ? receiveAmount : depositAmount;
        }

        if (provider is SimpleSwapExchangeProvider) {
          request = SimpleSwapRequest(
            from: depositCurrency,
            to: receiveCurrency,
            amount: depositAmount.replaceAll(',', '.'),
            address: receiveAddress,
            refundAddress: depositAddress,
          );
          amount = isFixedRateMode ? receiveAmount : depositAmount;
        }

        if (provider is XMRTOExchangeProvider) {
          request = XMRTOTradeRequest(
              from: depositCurrency,
              to: receiveCurrency,
              amount: depositAmount.replaceAll(',', '.'),
              receiveAmount: receiveAmount.replaceAll(',', '.'),
              address: receiveAddress,
              refundAddress: depositAddress,
              isBTCRequest: isReceiveAmountEntered);
          amount = isFixedRateMode ? receiveAmount : depositAmount;
        }

        if (provider is ChangeNowExchangeProvider) {
          request = ChangeNowRequest(
              from: depositCurrency,
              to: receiveCurrency,
              fromAmount: depositAmount.replaceAll(',', '.'),
              toAmount: receiveAmount.replaceAll(',', '.'),
              refundAddress: depositAddress,
              address: receiveAddress,
              isReverse: isFixedRateMode);
          amount = isFixedRateMode ? receiveAmount : depositAmount;
        }

        if (provider is MorphTokenExchangeProvider) {
          request = MorphTokenRequest(
              from: depositCurrency,
              to: receiveCurrency,
              amount: depositAmount.replaceAll(',', '.'),
              refundAddress: depositAddress,
              address: receiveAddress);
          amount = isFixedRateMode ? receiveAmount : depositAmount;
        }

        if (provider is TrocadorExchangeProvider) {
          request = TrocadorRequest(
              from: depositCurrency,
              to: receiveCurrency,
              fromAmount: depositAmount.replaceAll(',', '.'),
              toAmount: receiveAmount.replaceAll(',', '.'),
              refundAddress: depositAddress,
              address: receiveAddress,
              isReverse: isFixedRateMode);
          amount = isFixedRateMode ? receiveAmount : depositAmount;
        }

        amount = amount.replaceAll(',', '.');

        if (limitsState is LimitsLoadedSuccessfully) {
          if (limits.max != null && double.parse(amount) < limits.min!) {
            continue;
          } else if (limits.max != null && double.parse(amount) > limits.max!) {
            continue;
          } else {
            try {
              tradeState = TradeIsCreating();
              final trade = await provider.createTrade(
                  request: request!, isFixedRateMode: isFixedRateMode);
              trade.walletId = wallet.id;
              tradesStore.setTrade(trade);
              await trades.add(trade);
              tradeState = TradeIsCreatedSuccessfully(trade: trade);
              /// return after the first successful trade
              return;
            } catch (e) {
              continue;
            }
          }
        }
      }

      /// if the code reached here then none of the providers succeeded
      tradeState = TradeIsCreatedFailure(
          title: S.current.trade_not_created,
          error: S.current.none_of_selected_providers_can_exchange);
    } on ConcurrentModificationError {
      /// if create trade happened at the exact same time of the scheduled rate update
      /// then delay the create trade a bit and try again
      ///
      /// this is because the limitation of the SplayTreeMap that
      /// you can't modify it while iterating through it
      Future.delayed(Duration(milliseconds: 500), createTrade);
    }
  }

  @action
  void reset() {
    _initialPairBasedOnWallet();
    isReceiveAmountEntered = false;
    depositAmount = '';
    receiveAmount = '';
    depositAddress = depositCurrency == wallet.currency
        ? wallet.walletAddresses.address : '';
    receiveAddress = receiveCurrency == wallet.currency
        ? wallet.walletAddresses.address : '';
    isDepositAddressEnabled = !(depositCurrency == wallet.currency);
    isReceiveAddressEnabled = !(receiveCurrency == wallet.currency);
    isFixedRateMode = false;
    _onPairChange();
  }

  @action
  void calculateDepositAllAmount() {
    if (wallet.type == WalletType.bitcoin) {
      final availableBalance = wallet.balance[wallet.currency]!.available;
      final priority = _settingsStore.priority[wallet.type]!;
      final fee = wallet.feeEstimate.get(priority: priority, amount: availableBalance);

      if (availableBalance < fee || availableBalance == 0) {
        return;
      }

      final amount = availableBalance - fee;
      changeDepositAmount(amount: bitcoin!.formatterBitcoinAmountToString(amount: amount));
    }
  }

  void updateTemplate() => _exchangeTemplateStore.update();

  void addTemplate(
          {required String amount,
          required String depositCurrency,
          required String receiveCurrency,
          required String provider,
          required String depositAddress,
          required String receiveAddress}) =>
      _exchangeTemplateStore.addTemplate(
          amount: amount,
          depositCurrency: depositCurrency,
          receiveCurrency: receiveCurrency,
          provider: provider,
          depositAddress: depositAddress,
          receiveAddress: receiveAddress);

  void removeTemplate({required ExchangeTemplate template}) =>
      _exchangeTemplateStore.remove(template: template);

  List<ExchangeProvider> providersForCurrentPair() {
    return _providersForPair(from: depositCurrency, to: receiveCurrency);
  }

  List<ExchangeProvider> _providersForPair(
      {required CryptoCurrency from, required CryptoCurrency to}) {
    final providers = providerList
        .where((provider) => provider.pairList
            .where((pair) =>
                pair.from == from && pair.to == to)
            .isNotEmpty)
        .toList();

    return providers;
  }

  void _onPairChange() {
    depositAmount = '';
    receiveAmount = '';
    loadLimits();
    _setAvailableProviders();
    _bestRate = 0;
    _calculateBestRate();
  }

  void _initialPairBasedOnWallet() {
    switch (wallet.type) {
      case WalletType.monero:
        depositCurrency = CryptoCurrency.xmr;
        receiveCurrency = CryptoCurrency.btc;
        break;
      case WalletType.bitcoin:
        depositCurrency = CryptoCurrency.btc;
        receiveCurrency = CryptoCurrency.xmr;
        break;
      case WalletType.litecoin:
        depositCurrency = CryptoCurrency.ltc;
        receiveCurrency = CryptoCurrency.xmr;
        break;
      case WalletType.haven:
        depositCurrency = CryptoCurrency.xhv;
        receiveCurrency = CryptoCurrency.btc;
        break;
      default:
        break;
    }
  }

  void _defineIsReceiveAmountEditable() {
    /*if ((provider is ChangeNowExchangeProvider)
        &&(depositCurrency == CryptoCurrency.xmr)
        &&(receiveCurrency == CryptoCurrency.btc)) {
      isReceiveAmountEditable = true;
    } else {
      isReceiveAmountEditable = false;
    }*/
    //isReceiveAmountEditable = false;
    // isReceiveAmountEditable = selectedProviders.any((provider) => provider is ChangeNowExchangeProvider);
    // isReceiveAmountEditable = provider is ChangeNowExchangeProvider ||  provider is SimpleSwapExchangeProvider;
    isReceiveAmountEditable = true;
  }

  @action
  void addExchangeProvider(ExchangeProvider provider) {
    selectedProviders.add(provider);
    if (providersForCurrentPair().contains(provider)) {
      _tradeAvailableProviders.add(provider);
    }
  }

  @action
  void removeExchangeProvider(ExchangeProvider provider) {
    selectedProviders.remove(provider);
    _tradeAvailableProviders.remove(provider);
  }

  @action
  void saveSelectedProviders() {
    depositAmount = '';
    receiveAmount = '';
    isFixedRateMode = false;
    _defineIsReceiveAmountEditable();
    loadLimits();
    _bestRate = 0;
    _calculateBestRate();

    final Map<String, dynamic> exchangeProvidersSelection = json
        .decode(sharedPreferences.getString(PreferencesKey.exchangeProvidersSelection) ?? "{}") as Map<String, dynamic>;

    for (var provider in providerList) {
      exchangeProvidersSelection[provider.title] = selectedProviders.contains(provider);
    }

    sharedPreferences.setString(
      PreferencesKey.exchangeProvidersSelection,
      json.encode(exchangeProvidersSelection),
    );
  }

  bool get isAvailableInSelected {
    final providersForPair = providersForCurrentPair();
    return selectedProviders.any((element) => element.isAvailable && providersForPair.contains(element));
  }

  void _setAvailableProviders() {
    _tradeAvailableProviders.clear();

    _tradeAvailableProviders.addAll(
        selectedProviders
            .where((provider) => providersForCurrentPair().contains(provider)));
  }

  @action
  void setDefaultTransactionPriority() {
    switch (wallet.type) {
      case WalletType.monero:
      case WalletType.haven:
        _settingsStore.priority[wallet.type] = monero!.getMoneroTransactionPriorityAutomatic();
        break;
      case WalletType.bitcoin:
        _settingsStore.priority[wallet.type] = bitcoin!.getBitcoinTransactionPriorityMedium();
        break;
      case WalletType.litecoin:
        _settingsStore.priority[wallet.type] = bitcoin!.getLitecoinTransactionPriorityMedium();
        break;
      default:
        break;
    }
  }

  void _setProviders(){
    if (_settingsStore.exchangeStatus == ExchangeApiMode.torOnly) {
      providerList = _allProviders.where((provider) => provider.supportsOnionAddress).toList();
    } else {
      providerList = _allProviders;
    }
  }
}
