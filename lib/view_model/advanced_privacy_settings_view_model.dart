import 'package:cake_wallet/entities/exchange_api_mode.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/seed_phrase_length.dart';
import 'package:cake_wallet/entities/seed_type.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';

part 'advanced_privacy_settings_view_model.g.dart';

class AdvancedPrivacySettingsViewModel = AdvancedPrivacySettingsViewModelBase
    with _$AdvancedPrivacySettingsViewModel;

abstract class AdvancedPrivacySettingsViewModelBase with Store {
  AdvancedPrivacySettingsViewModelBase(this.type, this._settingsStore) : _addCustomNode = false;

  @computed
  ExchangeApiMode get exchangeStatus => _settingsStore.exchangeStatus;

  @computed
  FiatApiMode get fiatApiMode => _settingsStore.fiatApiMode;

  @computed
  bool get disableBulletin => _settingsStore.disableBulletin;

  @observable
  bool _addCustomNode = false;

  final WalletType type;

  final SettingsStore _settingsStore;

  bool get hasSeedPhraseLengthOption {
    // convert to switch case so that it give a syntax error when adding a new wallet type
    // thus we don't forget about it
    switch (type) {
      case WalletType.ethereum:
      case WalletType.bitcoinCash:
      case WalletType.polygon:
      case WalletType.solana:
      case WalletType.tron:
      case WalletType.lightning:
        return true;
      case WalletType.monero:
      case WalletType.wownero:
      case WalletType.none:
      case WalletType.bitcoin:
      case WalletType.litecoin:
      case WalletType.haven:
      case WalletType.nano:
      case WalletType.banano:
        return false;
    }
  }

  bool get hasSeedTypeOption => type == WalletType.monero || type == WalletType.wownero;

  @computed
  bool get addCustomNode => _addCustomNode;

  @computed
  SeedPhraseLength get seedPhraseLength => _settingsStore.seedPhraseLength;

  @computed
  bool get isPolySeed => _settingsStore.moneroSeedType == SeedType.polyseed;

  @action
  void setFiatApiMode(FiatApiMode fiatApiMode) => _settingsStore.fiatApiMode = fiatApiMode;

  @action
  void setExchangeApiMode(ExchangeApiMode value) => _settingsStore.exchangeStatus = value;

  @action
  void setDisableBulletin(bool value) => _settingsStore.disableBulletin = value;

  @action
  void toggleAddCustomNode() => _addCustomNode = !_addCustomNode;

  @action
  void setSeedPhraseLength(SeedPhraseLength length) => _settingsStore.seedPhraseLength = length;
}
