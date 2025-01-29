import 'dart:developer' as dev;

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/fiat_conversion_service.dart';
import 'package:cake_wallet/core/wallet_change_listener_view_model.dart';
import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
import 'package:cake_wallet/entities/fiat_api_mode.dart';
import 'package:cake_wallet/entities/fiat_currency.dart';
import 'package:cake_wallet/ethereum/ethereum.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/polygon/polygon.dart';
import 'package:cake_wallet/solana/solana.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/yat/yat_store.dart';
import 'package:cake_wallet/tron/tron.dart';
import 'package:cake_wallet/zano/zano.dart';
import 'package:cake_wallet/utils/list_item.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_account_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_hidden_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_item.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cw_core/amount_converter.dart';
import 'package:cw_core/currency.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';

part 'wallet_address_list_view_model.g.dart';

class WalletAddressListViewModel = WalletAddressListViewModelBase
    with _$WalletAddressListViewModel;

abstract class PaymentURI {
  PaymentURI({required this.amount, required this.address});

  final String amount;
  final String address;
}

class MoneroURI extends PaymentURI {
  MoneroURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'monero:$address';

    if (amount.isNotEmpty) {
      base += '?tx_amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class HavenURI extends PaymentURI {
  HavenURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'haven:$address';

    if (amount.isNotEmpty) {
      base += '?tx_amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class BitcoinURI extends PaymentURI {
  BitcoinURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'bitcoin:$address';

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class LitecoinURI extends PaymentURI {
  LitecoinURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'litecoin:$address';

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class EthereumURI extends PaymentURI {
  EthereumURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'ethereum:$address';

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class BitcoinCashURI extends PaymentURI {
  BitcoinCashURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = address;

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class NanoURI extends PaymentURI {
  NanoURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'nano:$address';
    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class PolygonURI extends PaymentURI {
  PolygonURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'polygon:$address';

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class SolanaURI extends PaymentURI {
  SolanaURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'solana:$address';

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class TronURI extends PaymentURI {
  TronURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'tron:$address';

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class WowneroURI extends PaymentURI {
  WowneroURI({required super.amount, required super.address});

  @override
  String toString() {
    var base = 'wownero:$address';

    if (amount.isNotEmpty) {
      base += '?tx_amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class ZanoURI extends PaymentURI {
  ZanoURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'zano:' + address;

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}


abstract class WalletAddressListViewModelBase
    extends WalletChangeListenerViewModel with Store {
  WalletAddressListViewModelBase({
    required AppStore appStore,
    required this.yatStore,
    required this.fiatConversionStore,
  })  : _baseItems = <ListItem>[],
        selectedCurrency = walletTypeToCryptoCurrency(appStore.wallet!.type),
        _cryptoNumberFormat = NumberFormat(_cryptoNumberPattern),
        hasAccounts = [WalletType.monero, WalletType.wownero, WalletType.haven]
            .contains(appStore.wallet!.type),
        amount = '',
        _settingsStore = appStore.settingsStore,
        super(appStore: appStore) {
    _init();
  }

  @override
  void onWalletChange(wallet) {
    _init();

    selectedCurrency = walletTypeToCryptoCurrency(wallet.type);
    hasAccounts = [WalletType.monero, WalletType.wownero, WalletType.haven]
        .contains(wallet.type);
  }

  static const String _cryptoNumberPattern = '0.00000000';

  final NumberFormat _cryptoNumberFormat;

  final FiatConversionStore fiatConversionStore;
  final SettingsStore _settingsStore;

  double? _fiatRate;
  String _rawAmount = '';

  List<Currency> get currencies =>
      [walletTypeToCryptoCurrency(wallet.type), ...FiatCurrency.all];

  String get buttonTitle {
    if (isElectrumWallet) {
      return S.current.addresses;
    }

    return hasAccounts ? S.current.accounts_subaddresses : S.current.addresses;
  }

  @observable
  Currency selectedCurrency;

  @observable
  String searchText = '';

  @computed
  int get selectedCurrencyIndex => currencies.indexOf(selectedCurrency);

  @observable
  String amount;

  @computed
  WalletType get type => wallet.type;

  @computed
  WalletAddressListItem get address => WalletAddressListItem(
        address: wallet.walletAddresses.address, isPrimary: false);

  @computed
  PaymentURI get uri {
    switch (wallet.type) {
      case WalletType.monero:
        return MoneroURI(amount: amount, address: address.address);
      case WalletType.haven:
        return HavenURI(amount: amount, address: address.address);
      case WalletType.bitcoin:
        return BitcoinURI(amount: amount, address: address.address);
      case WalletType.litecoin:
        return LitecoinURI(amount: amount, address: address.address);
      case WalletType.ethereum:
        return EthereumURI(amount: amount, address: address.address);
      case WalletType.bitcoinCash:
        return BitcoinCashURI(amount: amount, address: address.address);
      case WalletType.banano:
        return NanoURI(amount: amount, address: address.address);
      case WalletType.nano:
        return NanoURI(amount: amount, address: address.address);
      case WalletType.polygon:
        return PolygonURI(amount: amount, address: address.address);
      case WalletType.solana:
        return SolanaURI(amount: amount, address: address.address);
      case WalletType.tron:
        return TronURI(amount: amount, address: address.address);
      case WalletType.wownero:
        return WowneroURI(amount: amount, address: address.address);
      case WalletType.zano:
         return ZanoURI(amount: amount, address: address.address);
      case WalletType.none:
        throw Exception('Unexpected type: ${type.toString()}');
    }
  }
  @computed
  ObservableList<ListItem> get items => ObservableList<ListItem>()
    ..addAll(_baseItems)
    ..addAll(addressList);

  @computed
  ObservableList<ListItem> get addressList {
    final addressList = ObservableList<ListItem>();

    if (wallet.type == WalletType.monero) {
      final primaryAddress =
          monero!.getSubaddressList(wallet).subaddresses.first;
      final addressItems =
          monero!.getSubaddressList(wallet).subaddresses.map((subaddress) {
        final isPrimary = subaddress == primaryAddress;

        return WalletAddressListItem(
          id: subaddress.id,
          isPrimary: isPrimary,
          name: subaddress.label,
          address: subaddress.address,
          balance: subaddress.received,
          txCount: subaddress.txCount,
        );
      });
      addressList.addAll(addressItems);
    }

    if (wallet.type == WalletType.wownero) {
      final primaryAddress =
          wownero!.getSubaddressList(wallet).subaddresses.first;
      final addressItems =
          wownero!.getSubaddressList(wallet).subaddresses.map((subaddress) {
        final isPrimary = subaddress == primaryAddress;

        return WalletAddressListItem(
            id: subaddress.id,
            isPrimary: isPrimary,
            name: subaddress.label,
            address: subaddress.address);
      });
      addressList.addAll(addressItems);
    }

    if (wallet.type == WalletType.haven) {
      final primaryAddress =
          haven!.getSubaddressList(wallet).subaddresses.first;
      final addressItems =
          haven!.getSubaddressList(wallet).subaddresses.map((subaddress) {
        final isPrimary = subaddress == primaryAddress;

        return WalletAddressListItem(
            id: subaddress.id,
            isPrimary: isPrimary,
            name: subaddress.label,
            address: subaddress.address);
      });
      addressList.addAll(addressItems);
    }

    if (isElectrumWallet) {
      if (bitcoin!.hasSelectedSilentPayments(wallet)) {
        final addressItems =
            bitcoin!.getSilentPaymentAddresses(wallet).map((address) {
          final isPrimary = address.id == 0;

          return WalletAddressListItem(
            id: address.id,
            isPrimary: isPrimary,
            name: address.name,
            address: address.address,
            txCount: address.txCount,
            balance: AmountConverter.amountIntToString(
                walletTypeToCryptoCurrency(type), address.balance),
            isChange: address.isChange,
          );
        });
        addressList.addAll(addressItems);
        addressList.add(WalletAddressListHeader(title: S.current.received));

        final receivedAddressItems =
            bitcoin!.getSilentPaymentReceivedAddresses(wallet).map((address) {
          return WalletAddressListItem(
            id: address.id,
            isPrimary: false,
            name: address.name,
            address: address.address,
            txCount: address.txCount,
            balance: AmountConverter.amountIntToString(
                walletTypeToCryptoCurrency(type), address.balance),
            isChange: address.isChange,
            isOneTimeReceiveAddress: true,
          );
        });
        addressList.addAll(receivedAddressItems);
      } else {
        var addressItems = bitcoin!.getSubAddresses(wallet).map((subaddress) {
          final isPrimary = subaddress.id == 0;

          return WalletAddressListItem(
              id: subaddress.id,
              isPrimary: isPrimary,
              name: subaddress.name,
              address: subaddress.address,
              txCount: subaddress.txCount,
              balance: AmountConverter.amountIntToString(
                  walletTypeToCryptoCurrency(type), subaddress.balance),
              isChange: subaddress.isChange);
        });

        // don't show all 1000+ mweb addresses:
        if (wallet.type == WalletType.litecoin && addressItems.length >= 1000) {
          // find the index of the last item with a txCount > 0
          final addressItemsList = addressItems.toList();
          int index = addressItemsList
              .lastIndexWhere((item) => (item.txCount ?? 0) > 0);
          if (index == -1) {
            index = 0;
          }
          // show only up to that index + 20:
          addressItems = addressItemsList.sublist(0, index + 20);
        }
        addressList.addAll(addressItems);
      }
    }

    if (wallet.type == WalletType.ethereum) {
      final primaryAddress = ethereum!.getAddress(wallet);

      addressList.add(WalletAddressListItem(
          isPrimary: true, name: null, address: primaryAddress));
    }

    if (wallet.type == WalletType.polygon) {
      final primaryAddress = polygon!.getAddress(wallet);

      addressList.add(WalletAddressListItem(
          isPrimary: true, name: null, address: primaryAddress));
    }

    if (wallet.type == WalletType.solana) {
      final primaryAddress = solana!.getAddress(wallet);

      addressList.add(WalletAddressListItem(
          isPrimary: true, name: null, address: primaryAddress));
    }

    if (wallet.type == WalletType.nano) {
      addressList.add(WalletAddressListItem(
        isPrimary: true,
        name: null,
        address: wallet.walletAddresses.address,
      ));
    }

    if (wallet.type == WalletType.tron) {
      final primaryAddress = tron!.getAddress(wallet);

      addressList.add(WalletAddressListItem(
          isPrimary: true, name: null, address: primaryAddress));
    }

    for (var i = 0; i < addressList.length; i++) {
      if (!(addressList[i] is WalletAddressListItem)) continue;
      (addressList[i] as WalletAddressListItem).isHidden = wallet
          .walletAddresses.hiddenAddresses
          .contains((addressList[i] as WalletAddressListItem).address);
    }

    for (var i = 0; i < addressList.length; i++) {
      if (!(addressList[i] is WalletAddressListItem)) continue;
      (addressList[i] as WalletAddressListItem).isManual = wallet
          .walletAddresses.manualAddresses
          .contains((addressList[i] as WalletAddressListItem).address);
    }

    if (wallet.type == WalletType.zano) {
      final primaryAddress = zano!.getAddress(wallet);

      addressList.add(WalletAddressListItem(isPrimary: true, name: null, address: primaryAddress));
    }

    if (searchText.isNotEmpty) {
      return ObservableList.of(addressList.where((item) {
        if (item is WalletAddressListItem) {
          return item.address.toLowerCase().contains(searchText.toLowerCase());
        }
        return false;
      }));
    }

    return addressList;
  }

  Future<void> toggleHideAddress(WalletAddressListItem item) async {
    if (item.isHidden) {
      wallet.walletAddresses.hiddenAddresses
          .removeWhere((element) => element == item.address);
    } else {
      wallet.walletAddresses.hiddenAddresses.add(item.address);
    }
    await wallet.walletAddresses.saveAddressesInBox();
    if (wallet.type == WalletType.monero) {
      monero!
          .getSubaddressList(wallet)
          .update(wallet, accountIndex: monero!.getCurrentAccount(wallet).id);
    } else if (wallet.type == WalletType.wownero) {
      wownero!
          .getSubaddressList(wallet)
          .update(wallet, accountIndex: wownero!.getCurrentAccount(wallet).id);
    } else if (wallet.type == WalletType.haven) {
      haven!
          .getSubaddressList(wallet)
          .update(wallet, accountIndex: haven!.getCurrentAccount(wallet).id);
    }
  }

  @observable
  bool hasAccounts;

  @computed
  String get accountLabel {
    switch (wallet.type) {
      case WalletType.monero:
        return monero!.getCurrentAccount(wallet).label;
      case WalletType.wownero:
        wownero!.getCurrentAccount(wallet).label;
      case WalletType.haven:
        return haven!.getCurrentAccount(wallet).label;
      default:
        return '';
    }
    return '';
  }

  @computed
  bool get hasAddressList => [
        WalletType.monero,
        WalletType.wownero,
        WalletType.haven,
        WalletType.bitcoinCash,
        WalletType.bitcoin,
        WalletType.litecoin
      ].contains(wallet.type);

  @computed
  bool get isElectrumWallet => [
        WalletType.bitcoin,
        WalletType.litecoin,
        WalletType.bitcoinCash
      ].contains(wallet.type);

  @computed
  bool get isBalanceAvailable => isElectrumWallet;

  @computed
  bool get isReceivedAvailable =>
      [WalletType.monero, WalletType.wownero].contains(wallet.type);

  @computed
  bool get isSilentPayments =>
      wallet.type == WalletType.bitcoin &&
      bitcoin!.hasSelectedSilentPayments(wallet);

  @computed
  bool get isAutoGenerateSubaddressEnabled =>
      _settingsStore.autoGenerateSubaddressStatus !=
          AutoGenerateSubaddressStatus.disabled &&
      !isSilentPayments;

  @computed
  bool get showAddManualAddresses =>
      !isAutoGenerateSubaddressEnabled ||
      [WalletType.monero, WalletType.wownero].contains(wallet.type);

  List<ListItem> _baseItems;

  final YatStore yatStore;

  @action
  void setAddress(WalletAddressListItem address) =>
      wallet.walletAddresses.address = address.address;

  @action
  Future<void> setAddressType(dynamic option) async {
    if ([WalletType.bitcoin, WalletType.litecoin].contains(wallet.type)) {
      await bitcoin!.setAddressType(wallet, option);
    }
  }

  void _init() {
    _baseItems = [];

    if (wallet.walletAddresses.hiddenAddresses.isNotEmpty) {
      _baseItems.add(WalletAddressHiddenListHeader());
    }

    if ([
      WalletType.monero,
      WalletType.wownero,
      WalletType.haven,
    ].contains(wallet.type)) {
      _baseItems.add(WalletAccountListHeader());
    }

    if (![WalletType.nano, WalletType.banano].contains(wallet.type)) {
      _baseItems.add(WalletAddressListHeader());
    }
    if (wallet.isEnabledAutoGenerateSubaddress) {
      wallet.walletAddresses.address = wallet.walletAddresses.latestAddress;
    }
  }

  @action
  void selectCurrency(Currency currency) {
    selectedCurrency = currency;

    if (currency is FiatCurrency && _settingsStore.fiatCurrency != currency) {
      final cryptoCurrency = walletTypeToCryptoCurrency(wallet.type);

      dev.log("Requesting Fiat rate for $cryptoCurrency-$currency");
      FiatConversionService.fetchPrice(
        crypto: cryptoCurrency,
        fiat: currency,
        torOnly: _settingsStore.fiatApiMode == FiatApiMode.torOnly,
      ).then((value) {
        dev.log("Received Fiat rate 1 $cryptoCurrency = $value $currency");
        _fiatRate = value;
        _convertAmountToCrypto();
      });
    }
  }

  @action
  void changeAmount(String amount) {
    this.amount = amount;
    this._rawAmount = amount;
    if (selectedCurrency is FiatCurrency) {
      _convertAmountToCrypto();
    }
  }

  @action
  void updateSearchText(String text) {
    searchText = text;
  }

  @action
  void _convertAmountToCrypto() {
    final cryptoCurrency = walletTypeToCryptoCurrency(wallet.type);
    final fiatRate =
        _fiatRate ?? (fiatConversionStore.prices[cryptoCurrency] ?? 0.0);

    if (fiatRate <= 0.0) {
      dev.log("Invalid Fiat Rate $fiatRate");
      amount = '';
      return;
    }

    try {
      final crypto = double.parse(_rawAmount.replaceAll(',', '.')) / fiatRate;
      final cryptoAmountTmp = _cryptoNumberFormat.format(crypto);
      if (amount != cryptoAmountTmp) {
        amount = cryptoAmountTmp;
      }
    } catch (e) {
      amount = '';
    }
  }

  @action
  void deleteAddress(ListItem item) {
    if (wallet.type == WalletType.bitcoin && item is WalletAddressListItem) {
      bitcoin!.deleteSilentPaymentAddress(wallet, item.address);
    }
  }
}
