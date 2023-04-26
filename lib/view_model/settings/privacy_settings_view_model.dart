import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:mobx/mobx.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';

part 'privacy_settings_view_model.g.dart';

class PrivacySettingsViewModel = PrivacySettingsViewModelBase with _$PrivacySettingsViewModel;

abstract class PrivacySettingsViewModelBase with Store {
  PrivacySettingsViewModelBase(this._settingsStore, this.wallet);

  final SettingsStore _settingsStore;

  final WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet;

  @computed
  ExchangeApiMode get exchangeStatus => _settingsStore.exchangeStatus;

  @computed
  bool get enableAutoGenerateSubaddresses =>
      _settingsStore.autoGenerateSubaddressStatus != AutoGenerateSubaddressStatus.disabled;

  @action
  void setAutoGenerateSubaddresses(bool value) {
    wallet.enableAutoGenerate = value;
    if (value) {
      _settingsStore.autoGenerateSubaddressStatus = AutoGenerateSubaddressStatus.enabled;
    } else {
      _settingsStore.autoGenerateSubaddressStatus = AutoGenerateSubaddressStatus.disabled;
    }
  }

  @computed
  bool get shouldSaveRecipientAddress => _settingsStore.shouldSaveRecipientAddress;

  @computed
  FiatApiMode get fiatApiMode => _settingsStore.fiatApiMode;

  @computed
  bool get isAppSecure => _settingsStore.isAppSecure;

  @action
  void setShouldSaveRecipientAddress(bool value) =>
      _settingsStore.shouldSaveRecipientAddress = value;

  @action
  void setExchangeApiMode(ExchangeApiMode value) => _settingsStore.exchangeStatus = value;

  @action
  void setFiatMode(FiatApiMode fiatApiMode) => _settingsStore.fiatApiMode = fiatApiMode;

  @action
  void setIsAppSecure(bool value) => _settingsStore.isAppSecure = value;

}
