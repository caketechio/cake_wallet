import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/entities/buy_provider_types.dart';
import 'package:cake_wallet/entities/exchange_provider_types.dart';
import 'package:cake_wallet/entities/priority_for_wallet_type.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:package_info/package_info.dart';

part 'other_settings_view_model.g.dart';

class OtherSettingsViewModel = OtherSettingsViewModelBase with _$OtherSettingsViewModel;

abstract class OtherSettingsViewModelBase with Store {
  OtherSettingsViewModelBase(this._settingsStore, this._wallet)
      : walletType = _wallet.type,
        currentVersion = '' {
    PackageInfo.fromPlatform()
        .then((PackageInfo packageInfo) => currentVersion = packageInfo.version);

    final priority = _settingsStore.priority[_wallet.type];
    final priorities = priorityForWalletType(_wallet.type);

    if (!priorities.contains(priority) && priorities.isNotEmpty) {
      _settingsStore.priority[_wallet.type] = priorities.first;
    }
  }

  final WalletType walletType;
  final WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> _wallet;

  @observable
  String currentVersion;

  final SettingsStore _settingsStore;

  @computed
  TransactionPriority get transactionPriority {
    final priority = _settingsStore.priority[walletType];

    if (priority == null) {
      throw Exception('Unexpected type ${walletType.toString()}');
    }

    return priority;
  }

  @computed
  bool get changeRepresentativeEnabled {
    if (_wallet.type == WalletType.nano || _wallet.type == WalletType.banano) {
      return true;
    }

    return false;
  }

  BuyProviderType get buyProviderType {
    return _settingsStore.defaultBuyProvider;
  }

  ExchangeProviderType get exchangeProviderType {
    return _settingsStore.defaultExchangeProvider;
  }

  String getDisplayPriority(dynamic priority) {
    final _priority = priority as TransactionPriority;

    if (_wallet.type == WalletType.bitcoin ||
        _wallet.type == WalletType.litecoin ||
        _wallet.type == WalletType.bitcoinCash) {
      final rate = bitcoin!.getFeeRate(_wallet, _priority);
      return bitcoin!.bitcoinTransactionPriorityWithLabel(_priority, rate);
    }

    return priority.toString();
  }

  String getBuyProviderType(dynamic buyProviderType) {
    final _buyProviderType = buyProviderType as BuyProviderType;

    return _buyProviderType.toString();
  }

  String getExchangeProviderType(dynamic exchangeProviderType) {
    final _exchangeProviderType = exchangeProviderType as ExchangeProviderType;

    return _exchangeProviderType.toString();
  }

  void onDisplayPrioritySelected(TransactionPriority priority) =>
      _settingsStore.priority[_wallet.type] = priority;

  void onBuyProviderTypeSelected(BuyProviderType buyProviderType) =>
      _settingsStore.defaultBuyProvider = buyProviderType;

  void onExchangeProviderTypeSelected(ExchangeProviderType exchangeProviderType) =>
      _settingsStore.defaultExchangeProvider = exchangeProviderType;
}
