import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';

part 'privacy_settings_view_model.g.dart';

class PrivacySettingsViewModel = PrivacySettingsViewModelBase with _$PrivacySettingsViewModel;

abstract class PrivacySettingsViewModelBase with Store {
  PrivacySettingsViewModelBase(this._settingsStore, this._wallet);

  final SettingsStore _settingsStore;
  final WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> _wallet;

  @computed
  ExchangeApiMode get exchangeStatus => _settingsStore.exchangeStatus;

  @computed
  bool get isAutoGenerateSubaddressesEnabled =>
      _settingsStore.autoGenerateSubaddressStatus != AutoGenerateSubaddressStatus.disabled;

  @action
  void setAutoGenerateSubaddresses(bool value) {
    _wallet.isEnabledAutoGenerateSubaddress = value;
    if (value) {
      _settingsStore.autoGenerateSubaddressStatus = AutoGenerateSubaddressStatus.enabled;
    } else {
      _settingsStore.autoGenerateSubaddressStatus = AutoGenerateSubaddressStatus.disabled;
    }
  }

  bool get isAutoGenerateSubaddressesVisible =>
      _wallet.type == WalletType.monero ||
      _wallet.type == WalletType.wownero ||
      _wallet.type == WalletType.bitcoin ||
      _wallet.type == WalletType.litecoin ||
      _wallet.type == WalletType.bitcoinCash ||
      _wallet.type == WalletType.decred;

  bool get isMoneroWallet => _wallet.type == WalletType.monero;

  @computed
  bool get shouldSaveRecipientAddress => _settingsStore.shouldSaveRecipientAddress;

  @computed
  FiatApiMode get fiatApiMode => _settingsStore.fiatApiMode;

  @computed
  bool get isAppSecure => _settingsStore.isAppSecure;

  @computed
  bool get disableTradeOption => _settingsStore.disableTradeOption;

  @computed
  bool get disableBulletin => _settingsStore.disableBulletin;

  @computed
  bool get useEtherscan => _settingsStore.useEtherscan;

  @computed
  bool get usePolygonScan => _settingsStore.usePolygonScan;

  @computed
  bool get useTronGrid => _settingsStore.useTronGrid;

  @computed
  bool get useMempoolFeeAPI => _settingsStore.useMempoolFeeAPI;

  @computed
  bool get lookupTwitter => _settingsStore.lookupsTwitter;

  @computed
  bool get lookupsZanoAlias => _settingsStore.lookupsZanoAlias;

  @computed
  bool get looksUpMastodon => _settingsStore.lookupsMastodon;

  @computed
  bool get looksUpYatService => _settingsStore.lookupsYatService;

  @computed
  bool get looksUpUnstoppableDomains => _settingsStore.lookupsUnstoppableDomains;

  @computed
  bool get looksUpOpenAlias => _settingsStore.lookupsOpenAlias;

  @computed
  bool get looksUpENS => _settingsStore.lookupsENS;

  @computed
  bool get looksUpWellKnown => _settingsStore.lookupsWellKnown;

  bool get canUseEtherscan => _wallet.type == WalletType.ethereum;

  bool get canUsePolygonScan => _wallet.type == WalletType.polygon;

  bool get canUseTronGrid => _wallet.type == WalletType.tron;

  bool get canUseMempoolFeeAPI => _wallet.type == WalletType.bitcoin;

  @action
  void setShouldSaveRecipientAddress(bool value) =>
      _settingsStore.shouldSaveRecipientAddress = value;

  @action
  void setExchangeApiMode(ExchangeApiMode value) => _settingsStore.exchangeStatus = value;

  @action
  void setFiatMode(FiatApiMode fiatApiMode) => _settingsStore.fiatApiMode = fiatApiMode;

  @action
  void setIsAppSecure(bool value) => _settingsStore.isAppSecure = value;

  @action
  void setDisableTradeOption(bool value) => _settingsStore.disableTradeOption = value;

  @action
  void setDisableBulletin(bool value) => _settingsStore.disableBulletin = value;

  @action
  void setLookupsTwitter(bool value) => _settingsStore.lookupsTwitter = value;

  @action
  void setLookupsZanoAlias(bool value) => _settingsStore.lookupsZanoAlias = value;

  @action
  void setLookupsMastodon(bool value) => _settingsStore.lookupsMastodon = value;

  @action
  void setLookupsENS(bool value) => _settingsStore.lookupsENS = value;

  @action
  void setLookupsWellKnown(bool value) => _settingsStore.lookupsWellKnown = value;
  
  @action
  void setLookupsYatService(bool value) => _settingsStore.lookupsYatService = value;

  @action
  void setLookupsUnstoppableDomains(bool value) => _settingsStore.lookupsUnstoppableDomains = value;

  @action
  void setLookupsOpenAlias(bool value) => _settingsStore.lookupsOpenAlias = value;

  @action
  void setUseEtherscan(bool value) {
    _settingsStore.useEtherscan = value;
    ethereum!.updateEtherscanUsageState(_wallet, value);
  }

  @action
  void setUsePolygonScan(bool value) {
    _settingsStore.usePolygonScan = value;
    polygon!.updatePolygonScanUsageState(_wallet, value);
  }

  @action
  void setUseTronGrid(bool value) {
    _settingsStore.useTronGrid = value;
    tron!.updateTronGridUsageState(_wallet, value);
  }

  @action
  void setUseMempoolFeeAPI(bool value) {
    _settingsStore.useMempoolFeeAPI = value;
  }
}
