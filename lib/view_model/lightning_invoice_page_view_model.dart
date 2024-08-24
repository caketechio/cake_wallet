import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/lightning/lightning.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/view_model/lightning_view_model.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/currency.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'lightning_invoice_page_view_model.g.dart';

class LightningInvoicePageViewModel = LightningInvoicePageViewModelBase
    with _$LightningInvoicePageViewModel;

abstract class LightningInvoicePageViewModelBase with Store {
  LightningInvoicePageViewModelBase(
    this.settingsStore,
    this._wallet,
    this.sharedPreferences,
    this.lightningViewModel, {
    required this.useTorOnly,
  })  : description = '',
        amount = '',
        state = InitialExecutionState(),
        selectedCurrency = walletTypeToCryptoCurrency(_wallet.type),
        cryptoCurrency = walletTypeToCryptoCurrency(_wallet.type) {
    fetchLimits();
  }

  List<Currency> get currencies => [walletTypeToCryptoCurrency(_wallet.type), ...FiatCurrency.all];
  final SettingsStore settingsStore;
  final WalletBase _wallet;
  final SharedPreferences sharedPreferences;
  final LightningViewModel lightningViewModel;
  final bool useTorOnly;

  @observable
  Currency selectedCurrency;

  CryptoCurrency cryptoCurrency;

  @observable
  String description;

  @observable
  String amount;

  @observable
  ExecutionState state;

  @computed
  int get selectedCurrencyIndex => currencies.indexOf(selectedCurrency);

  @observable
  double minimum = 2500;

  @observable
  double maximum = 4000000;

  @observable
  double fiatRate = 1;

  @observable
  String minimumCurrency = '...';

  @action
  Future<void> selectCurrency(Currency currency) async {
    selectedCurrency = currency;
    if (currency is CryptoCurrency) {
      cryptoCurrency = currency;
    } else {
      cryptoCurrency = walletTypeToCryptoCurrency(_wallet.type);
    }

    await fetchLimits();
  }

  @computed
  int? get satAmount {
    final inputAmount = double.tryParse(amount);
    if (inputAmount == null) {
      return null;
    }
    int amt = inputAmount.round();
    if (selectedCurrency is FiatCurrency) {
      amt = (inputAmount / fiatRate).round();
    }
    return amt;
  }

  @action
  Future<void> createInvoice() async {
    state = IsExecutingState();
    if (amount.isEmpty) {
      state = FailureState('Amount cannot be empty');
      return;
    }

    if (satAmount == null) {
      state = FailureState('Amount entered is invalid');
      return;
    }

    if (satAmount! < minimum) {
      state = FailureState('Amount is too small');
      return;
    }

    // if (satAmount! > maximum && maximum != 0) {
    //   state = FailureState('Amount is too big');
    //   return;
    // }

    try {
      String bolt11 = await lightningViewModel.createInvoice(
        amountSats: satAmount.toString(),
        description: description,
      );
      state = ExecutedSuccessfullyState(payload: bolt11);
    } catch (e) {
      state = FailureState(e.toString());
    }
  }

  @action
  void setRequestParams({
    required String inputAmount,
    required String inputDescription,
  }) {
    description = inputDescription;
    amount = inputAmount;
  }

  @action
  Future<void> fetchFiatRate() async {
    late FiatCurrency fiatCurrency;
    if (selectedCurrency is FiatCurrency) {
      fiatCurrency = selectedCurrency as FiatCurrency;
    } else {
      fiatCurrency = settingsStore.fiatCurrency;
    }
    fiatRate = await FiatConversionService.fetchPrice(
          crypto: CryptoCurrency.btc,
          fiat: fiatCurrency,
          torOnly: useTorOnly,
        ) /
        100000000;
  }

  @action
  Future<void> fetchLimits() async {
    final limits = await lightningViewModel.invoiceSoftLimitsSats();
    // we definitely already have an open channel:
    if (limits.balance > 0 || limits.inboundLiquidity > 0) {
      minimum = 0;
    } else {
      minimum = limits.minFee.toDouble();
    }
    maximum = limits.inboundLiquidity.toDouble();

    if (minimum == 0) {
      minimumCurrency = '';
      return;
    }

    if (selectedCurrency is FiatCurrency) {
      await fetchFiatRate();
      minimumCurrency = (minimum * fiatRate).toStringAsFixed(2);
    } else {
      minimumCurrency = lightning!.satsToLightningString(minimum.round());
    }
  }

  @action
  void reset() {
    selectedCurrency = walletTypeToCryptoCurrency(_wallet.type);
    cryptoCurrency = walletTypeToCryptoCurrency(_wallet.type);
    description = '';
    amount = '';
    try {
      fetchLimits();
    } catch (_) {}
  }

  void updateTransactions() {
    // internally calls updateTransactions():
    _wallet.rescan(height: 0);
  }
}
