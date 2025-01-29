import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/sort_balance_types.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/entities/balance_display_mode.dart';
import 'package:cake_wallet/entities/calculate_fiat_amount.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:mobx/mobx.dart';

part 'balance_view_model.g.dart';

class BalanceRecord {
  const BalanceRecord(
      {
        required this.availableBalance,
      required this.additionalBalance,
      required this.secondAvailableBalance,
      required this.secondAdditionalBalance,
      required this.frozenBalance,
      required this.fiatAvailableBalance,
      required this.fiatAdditionalBalance,
      required this.fiatFrozenBalance,
      required this.fiatSecondAvailableBalance,
      required this.fiatSecondAdditionalBalance,
      required this.asset,
      required this.formattedAssetTitle});

  final String fiatAdditionalBalance;
  final String fiatAvailableBalance;
  final String fiatFrozenBalance;
  final String additionalBalance;
  final String availableBalance;
  final String frozenBalance;
  final String secondAvailableBalance;
  final String secondAdditionalBalance;
  final String fiatSecondAdditionalBalance;
  final String fiatSecondAvailableBalance;
  final CryptoCurrency asset;
  final String formattedAssetTitle;
}

class BalanceViewModel = BalanceViewModelBase with _$BalanceViewModel;

abstract class BalanceViewModelBase with Store {
  BalanceViewModelBase(
      {required this.appStore, required this.settingsStore, required this.fiatConvertationStore})
      : isReversing = false,
        isShowCard = appStore.wallet!.walletInfo.isShowIntroCakePayCard,
        wallet = appStore.wallet! {
    reaction((_) => appStore.wallet, (wallet) {
      _onWalletChange(wallet);
      _checkMweb();
    });

    _checkMweb();

    reaction((_) => settingsStore.mwebAlwaysScan, (bool value) {
      _checkMweb();
    });
  }

  void _checkMweb() {
    if (wallet.type == WalletType.litecoin) {
      mwebEnabled = bitcoin!.getMwebEnabled(wallet);
    }
  }

  final AppStore appStore;
  final SettingsStore settingsStore;
  final FiatConversionStore fiatConvertationStore;

  bool get canReverse => false;

  @observable
  bool isReversing;

  @observable
  WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet;

  @computed
  bool get hasSilentPayments => wallet.type == WalletType.bitcoin && !wallet.isHardwareWallet;

  @computed
  double get price {
    final price = fiatConvertationStore.prices[appStore.wallet!.currency];

    if (price == null) {
      // price should update on next fetch:
      return 0;
    }

    return price;
  }

  @computed
  BalanceDisplayMode get savedDisplayMode => settingsStore.balanceDisplayMode;

  @computed
  bool get isFiatDisabled => settingsStore.fiatApiMode == FiatApiMode.disabled;

  @computed
  bool get isHomeScreenSettingsEnabled =>
      isEVMCompatibleChain(wallet.type) ||
      wallet.type == WalletType.solana ||
      wallet.type == WalletType.tron ||
      wallet.type == WalletType.zano;

  @computed
  bool get hasAccounts => wallet.type == WalletType.monero || wallet.type == WalletType.wownero;

  @computed
  SortBalanceBy get sortBalanceBy => settingsStore.sortBalanceBy;

  @computed
  bool get pinNativeToken => settingsStore.pinNativeTokenAtTop;

  @computed
  String get asset {
    final typeFormatted = walletTypeToString(appStore.wallet!.type);

    switch (wallet.type) {
      case WalletType.haven:
        return '$typeFormatted Assets';
      default:
        return typeFormatted;
    }
  }

  @computed
  BalanceDisplayMode get displayMode {
    if (isReversing) {
      if (savedDisplayMode == BalanceDisplayMode.hiddenBalance) {
        return BalanceDisplayMode.displayableBalance;
      } else {
        return BalanceDisplayMode.hiddenBalance;
      }
    }

    return savedDisplayMode;
  }

  @computed
  String get availableBalanceLabel {

    if (displayMode == BalanceDisplayMode.hiddenBalance) {
      return S.current.show_balance;
    }
    else {
      return S.current.xmr_available_balance;
    }
  }

  @computed
  String get additionalBalanceLabel {

    switch (wallet.type) {
      case WalletType.haven:
      case WalletType.ethereum:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.tron:
        return S.current.xmr_full_balance;
      case WalletType.nano:
      case WalletType.banano:
        return S.current.receivable_balance;
      default:
        return S.current.unconfirmed;
    }
  }

  @computed
  String get secondAvailableBalanceLabel {
    switch (wallet.type) {
      case WalletType.litecoin:
        return S.current.mweb_confirmed;
      default:
        return S.current.confirmed;
    }
  }

  @computed
  String get secondAdditionalBalanceLabel {
    switch (wallet.type) {
      case WalletType.litecoin:
        return S.current.mweb_unconfirmed;
      default:
        return S.current.unconfirmed;
    }
  }

  String additionalBalance(CryptoCurrency cryptoCurrency) {
    final balance = _currencyBalance(cryptoCurrency);

    if (displayMode == BalanceDisplayMode.hiddenBalance) {
      return '0.0';
    }

    return balance.formattedAdditionalBalance;
  }

  @computed
  Map<CryptoCurrency, BalanceRecord> get balances {
    return wallet.balance.map((key, value) {
      if (displayMode == BalanceDisplayMode.hiddenBalance) {
        final fiatCurrency = settingsStore.fiatCurrency;
        return MapEntry(
            key,
            BalanceRecord(
                availableBalance: '●●●●●●',
                additionalBalance: additionalBalance(key),
                frozenBalance: '',
                secondAvailableBalance: '●●●●●●',
                secondAdditionalBalance: '●●●●●●',
                fiatAdditionalBalance: isFiatDisabled ? '' : '${fiatCurrency.toString()} ●●●●●',
                fiatAvailableBalance: isFiatDisabled ? '' : '${fiatCurrency.toString()} ●●●●●',
                fiatFrozenBalance: isFiatDisabled ? '' : '',
                fiatSecondAvailableBalance: isFiatDisabled ? '' : '${fiatCurrency.toString()} ●●●●●',
                fiatSecondAdditionalBalance: isFiatDisabled ? '' : '${fiatCurrency.toString()} ●●●●●',
                asset: key,
                formattedAssetTitle: _formatterAsset(key)));
      }
      final fiatCurrency = settingsStore.fiatCurrency;
      final price = fiatConvertationStore.prices[key] ?? 0;

      // if (price == null) {
      //   throw Exception('Price is null for: $key');
      // }

      final additionalFiatBalance = isFiatDisabled
          ? ''
          : (fiatCurrency.toString() +
              ' ' +
              _getFiatBalance(price: price, cryptoAmount: value.formattedAdditionalBalance));

      final availableFiatBalance = isFiatDisabled
          ? ''
          : (fiatCurrency.toString() +
              ' ' +
              _getFiatBalance(price: price, cryptoAmount: value.formattedAvailableBalance));

      final frozenFiatBalance = isFiatDisabled
          ? ''
          : (fiatCurrency.toString() +
              ' ' +
              _getFiatBalance(price: price, cryptoAmount: getFormattedFrozenBalance(value)));

      final secondAdditionalFiatBalance = isFiatDisabled
          ? ''
          : (fiatCurrency.toString() +
              ' ' +
              _getFiatBalance(price: price, cryptoAmount: value.formattedSecondAdditionalBalance));

      final secondAvailableFiatBalance = isFiatDisabled
          ? ''
          : (fiatCurrency.toString() +
              ' ' +
              _getFiatBalance(price: price, cryptoAmount: value.formattedSecondAvailableBalance));

      return MapEntry(
          key,
          BalanceRecord(
              availableBalance: value.formattedAvailableBalance,
              additionalBalance: value.formattedAdditionalBalance,
              frozenBalance: getFormattedFrozenBalance(value),
              secondAvailableBalance: value.formattedSecondAvailableBalance,
              secondAdditionalBalance: value.formattedSecondAdditionalBalance,
              fiatAdditionalBalance: additionalFiatBalance,
              fiatAvailableBalance: availableFiatBalance,
              fiatFrozenBalance: frozenFiatBalance,
              fiatSecondAvailableBalance: secondAvailableFiatBalance,
              fiatSecondAdditionalBalance: secondAdditionalFiatBalance,
              asset: key,
              formattedAssetTitle: _formatterAsset(key)));
    });
  }

  @observable
  bool mwebEnabled = false;

  bool hasAdditionalBalance(CryptoCurrency currency) {
    bool isWalletTypeActivated = _hasAdditionalBalanceForWalletType(wallet.type);
    bool isNotZeroAmount = additionalBalance(currency) != "0.0";

    return isWalletTypeActivated && isNotZeroAmount;
  }

  @computed
  bool get hasSecondAdditionalBalance =>
      mwebEnabled && _hasSecondAdditionalBalanceForWalletType(wallet.type);

  @computed
  bool get hasSecondAvailableBalance =>
      mwebEnabled && _hasSecondAvailableBalanceForWalletType(wallet.type);

  bool _hasAdditionalBalanceForWalletType(WalletType type) {
    switch (type) {
      case WalletType.monero:
      case WalletType.wownero:
      case WalletType.zano:
        return true;
      default:
        return false;
    }
  }

  bool _hasSecondAdditionalBalanceForWalletType(WalletType type) {
    if (wallet.type == WalletType.litecoin) {
      if ((wallet.balance[CryptoCurrency.ltc]?.secondAdditional ?? 0) != 0) {
        return true;
      }
    }
    return false;
  }

  bool _hasSecondAvailableBalanceForWalletType(WalletType type) {
    if (wallet.type == WalletType.litecoin) {
      return true;
    }
    return false;
  }

  @computed
  List<BalanceRecord> get formattedBalances {
    final balance = balances.values.toList();

    balance.sort((BalanceRecord a, BalanceRecord b) {
      if (wallet.currency == CryptoCurrency.xhv) {
        if (b.asset == CryptoCurrency.xhv) {
          return 1;
        }

        if (b.asset == CryptoCurrency.xusd) {
          if (a.asset == CryptoCurrency.xhv) {
            return -1;
          }

          return 1;
        }

        if (b.asset == CryptoCurrency.xbtc) {
          return 1;
        }

        if (b.asset == CryptoCurrency.xeur) {
          return 1;
        }

        return 0;
      }

      if (pinNativeToken) {
        if (b.asset == wallet.currency) return 1;
        if (a.asset == wallet.currency) return -1;
      }

      switch (sortBalanceBy) {
        case SortBalanceBy.FiatBalance:
          final aFiatBalance = _getFiatBalance(
              price: fiatConvertationStore.prices[a.asset] ?? 0, cryptoAmount: a.availableBalance);
          final bFiatBalance = _getFiatBalance(
              price: fiatConvertationStore.prices[b.asset] ?? 0, cryptoAmount: b.availableBalance);

          return (double.tryParse(bFiatBalance) ?? 0)
              .compareTo((double.tryParse(aFiatBalance)) ?? 0);
        case SortBalanceBy.GrossBalance:
          return (double.tryParse(b.availableBalance) ?? 0)
              .compareTo(double.tryParse(a.availableBalance) ?? 0);
        case SortBalanceBy.Alphabetical:
          return a.asset.title.compareTo(b.asset.title);
      }
    });

    return balance;
  }

  Balance _currencyBalance(CryptoCurrency cryptoCurrency) {
    final balance = wallet.balance[cryptoCurrency];

    if (balance == null) {
      throw Exception('No balance for ${wallet.currency}');
    }

    return balance;
  }


  @observable
  bool isShowCard;

  ReactionDisposer? _onCurrentWalletChangeReaction;

  @action
  void _onWalletChange(
      WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo>? wallet) {
    if (wallet == null) {
      return;
    }

    this.wallet = wallet;
    _onCurrentWalletChangeReaction?.reaction.dispose();
    isShowCard = wallet.walletInfo.isShowIntroCakePayCard;
  }

  @action
  Future<void> disableIntroCakePayCard() async {
    const cardDisplayStatus = false;
    wallet.walletInfo.showIntroCakePayCard = cardDisplayStatus;
    await wallet.walletInfo.save();
    isShowCard = cardDisplayStatus;
  }

  @action
  void switchBalanceValue() {
    if (settingsStore.balanceDisplayMode == BalanceDisplayMode.displayableBalance) {
      settingsStore.balanceDisplayMode = BalanceDisplayMode.hiddenBalance;
    } else {
      settingsStore.balanceDisplayMode = BalanceDisplayMode.displayableBalance;
    }
  }

  String _getFiatBalance({required double price, String? cryptoAmount}) {
    if (cryptoAmount == null || cryptoAmount.isEmpty || double.tryParse(cryptoAmount) == null) {
      return '0.00';
    }

    return calculateFiatAmount(price: price, cryptoAmount: cryptoAmount);
  }

  String _formatterAsset(CryptoCurrency asset) {
    switch (wallet.type) {
      case WalletType.haven:
        final assetStringified = asset.toString();

        if (asset != CryptoCurrency.xhv && assetStringified[0].toUpperCase() == 'X') {
          return assetStringified.replaceFirst('X', 'x');
        }

        return asset.toString();
      default:
        return asset.toString();
    }
  }

  String getFormattedFrozenBalance(Balance walletBalance) =>
      walletBalance.formattedUnAvailableBalance;
}
