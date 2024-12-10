import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/core/wallet_change_listener_view_model.dart';
import 'package:cake_wallet/entities/auto_generate_subaddress_status.dart';
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
import 'package:cake_wallet/utils/list_item.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_account_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_header.dart';
import 'package:cake_wallet/view_model/wallet_address_list/wallet_address_list_item.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cw_bitcoin/bitcoin_payjoin.dart';
import 'package:cw_core/amount_converter.dart';
import 'package:cw_core/currency.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/material.dart';
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
  MoneroURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'monero:' + address;

    if (amount.isNotEmpty) {
      base += '?tx_amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class HavenURI extends PaymentURI {
  HavenURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'haven:' + address;

    if (amount.isNotEmpty) {
      base += '?tx_amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class BitcoinURI extends PaymentURI {
  BitcoinURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'bitcoin:' + address;

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class PayjoinBitcoinURI extends PaymentURI {
  PayjoinBitcoinURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = address;

    return base;
  }
}

class LitecoinURI extends PaymentURI {
  LitecoinURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'litecoin:' + address;

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class EthereumURI extends PaymentURI {
  EthereumURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'ethereum:' + address;

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class BitcoinCashURI extends PaymentURI {
  BitcoinCashURI({required String amount, required String address})
      : super(amount: amount, address: address);

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
  NanoURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'nano:' + address;
    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class PolygonURI extends PaymentURI {
  PolygonURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'polygon:' + address;

    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class SolanaURI extends PaymentURI {
  SolanaURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'solana:' + address;
    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class TronURI extends PaymentURI {
  TronURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'tron:' + address;
    if (amount.isNotEmpty) {
      base += '?amount=${amount.replaceAll(',', '.')}';
    }

    return base;
  }
}

class WowneroURI extends PaymentURI {
  WowneroURI({required String amount, required String address})
      : super(amount: amount, address: address);

  @override
  String toString() {
    var base = 'wownero:' + address;

    if (amount.isNotEmpty) {
      base += '?tx_amount=${amount.replaceAll(',', '.')}';
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
        hasAccounts = appStore.wallet!.type == WalletType.monero ||
            appStore.wallet!.type == WalletType.wownero ||
            appStore.wallet!.type == WalletType.haven,
        amount = '',
        _settingsStore = appStore.settingsStore,
        super(appStore: appStore) {
    _init();
  }

  @override
  void onWalletChange(wallet) {
    _init();

    selectedCurrency = walletTypeToCryptoCurrency(wallet.type);
    hasAccounts = wallet.type == WalletType.monero ||
        wallet.type == WalletType.wownero ||
        wallet.type == WalletType.haven;
  }

  static const String _cryptoNumberPattern = '0.00000000';

  final NumberFormat _cryptoNumberFormat;

  final FiatConversionStore fiatConversionStore;
  final SettingsStore _settingsStore;

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
    if (wallet.type == WalletType.monero) {
      return MoneroURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.haven) {
      return HavenURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.bitcoin && isPayjoinOption) {
      print(
          '[+] wallet_address_list_view_model.dart || PaymentURI => isPayjoinOption: $isPayjoinOption');
      return PayjoinBitcoinURI(amount: amount, address: payjoinUri);
    }

    if (wallet.type == WalletType.bitcoin) {
      return BitcoinURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.litecoin) {
      return LitecoinURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.ethereum) {
      return EthereumURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.bitcoinCash) {
      return BitcoinCashURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.nano) {
      return NanoURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.polygon) {
      return PolygonURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.solana) {
      return SolanaURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.tron) {
      return TronURI(amount: amount, address: address.address);
    }

    if (wallet.type == WalletType.wownero) {
      return WowneroURI(amount: amount, address: address.address);
    }

    throw Exception('Unexpected type: ${type.toString()}');
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
            address: subaddress.address);
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
        final addressItems = bitcoin!.getSubAddresses(wallet).map((subaddress) {
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

  @observable
  bool hasAccounts;

  @computed
  String get accountLabel {
    if (wallet.type == WalletType.monero) {
      return monero!.getCurrentAccount(wallet).label;
    }

    if (wallet.type == WalletType.wownero) {
      return wownero!.getCurrentAccount(wallet).label;
    }

    if (wallet.type == WalletType.haven) {
      return haven!.getCurrentAccount(wallet).label;
    }

    return '';
  }

  @computed
  bool get hasAddressList =>
      wallet.type == WalletType.monero ||
      wallet.type == WalletType.wownero ||
      wallet.type == WalletType.haven ||
      wallet.type == WalletType.bitcoinCash ||
      wallet.type == WalletType.bitcoin ||
      wallet.type == WalletType.litecoin;

  @computed
  bool get isElectrumWallet =>
      wallet.type == WalletType.bitcoin ||
      wallet.type == WalletType.litecoin ||
      wallet.type == WalletType.bitcoinCash;

  @computed
  bool get isSilentPayments =>
      wallet.type == WalletType.bitcoin &&
      bitcoin!.hasSelectedSilentPayments(wallet);

  @computed
  bool get isAutoGenerateSubaddressEnabled =>
      _settingsStore.autoGenerateSubaddressStatus !=
          AutoGenerateSubaddressStatus.disabled &&
      !isSilentPayments;

  List<ListItem> _baseItems;

  final YatStore yatStore;

  @action
  void setAddress(WalletAddressListItem address) =>
      wallet.walletAddresses.address = address.address;

  @action
  Future<void> setAddressType(dynamic option) async {
    if (wallet.type == WalletType.bitcoin) {
      await bitcoin!.setAddressType(wallet, option);
    }
  }

  void _init() {
    _baseItems = [];

    if (wallet.type == WalletType.monero ||
        wallet.type == WalletType.wownero ||
        wallet.type == WalletType.haven) {
      _baseItems.add(WalletAccountListHeader());
    }

    if (wallet.type != WalletType.nano && wallet.type != WalletType.banano) {
      _baseItems.add(WalletAddressListHeader());
    }
  }

  @action
  void selectCurrency(Currency currency) {
    selectedCurrency = currency;
  }

  @action
  void changeAmount(String amount) {
    this.amount = amount;
    if (selectedCurrency is FiatCurrency) {
      _convertAmountToCrypto();
    } else if (isPayjoinOption) {
      buildV2PjStr();
    }
  }

  @action
  void updateSearchText(String text) {
    searchText = text;
  }

  void _convertAmountToCrypto() {
    final cryptoCurrency = walletTypeToCryptoCurrency(wallet.type);
    try {
      final crypto = double.parse(amount.replaceAll(',', '.')) /
          fiatConversionStore.prices[cryptoCurrency]!;
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

  @observable
  String payjoinUri = '';

  @observable
  Receiver? session;

  @observable
  PayjoinProposal? payjoinProposal;

  @observable
  UncheckedProposal? uncheckedProposal;

  @observable
  PayjoinException? pjException;

  @computed
  bool get isPayjoinOption => payjoinUri.trim().isNotEmpty && session != null;

  @action
  Future<void> buildV2PjStr() async {
    print('[+] wallet_address_list_view_model.dart || buildV2PjStr()');
    final btcAmount =
        !(selectedCurrency is FiatCurrency) ? double.tryParse(amount) : null;
    final satsAmount =
        btcAmount != null ? (btcAmount * 100000000).round() : null;

    print(
        '[+] wallet_address_list_view_model.dart || buildV2PjStr() => satsAmount: $satsAmount');

    try {
      final expireAfter = BigInt.from(60 * 5); // 5 minutes

      final res = await bitcoin!.buildV2PjStr(
        amount: satsAmount,
        address: address.address,
        isTestnet: wallet.isTestnet,
        expireAfter: expireAfter,
      );
      payjoinUri = res['pjUri'] as String;
      session = res['session'] as Receiver;

      print(
          '[+] wallet_address_list_view_model.dart || buildV2PjStr() => payjoinUri: $payjoinUri');

      final proposal = await bitcoin!.handleReceiverSession(session!);
      uncheckedProposal = proposal;

      final originalTx = await bitcoin!.extractOriginalTransaction(proposal);

      // Handle the request and send back the payjoin proposal
      final finalizedProposal = await bitcoin!.processProposal(
        proposal: proposal,
        receiverWallet: wallet,
      );
      payjoinProposal = finalizedProposal;

      final proposalTxId = await bitcoin!.sendFinalProposal(finalizedProposal);

      final receivedTxId = await waitForTransaction(
        originalTxId: await originalTx,
        proposalTxId: proposalTxId,
      );

      disposePayjoinSession();

      if (receivedTxId.isNotEmpty) {
        final msg =
            '${receivedTxId == proposalTxId ? 'Payjoin' : 'Original'} tx received!';
        print('[+] wallet_address_list_vm.dart => msg: $msg');
      }
    } catch (e, st) {
      debugPrint('[!] WALLETADDRESSLISTVM => buildV2PjStr() - ${e.toString()}');

      if (e is PayjoinException) {
        // TODO: Handle the error appropriately
        debugPrint(
            '[!] WALLETADDRESSLISTVM => buildV2PjStr() - e: $e, st: $st');
        pjException = e;
        disposePayjoinSession();
      }
    }
  }

  @action
  void disposePayjoinSession() {
    // payjoinUri = '';
    session = null;
    uncheckedProposal = null;
    payjoinProposal = null;
  }

  Future<String> waitForTransaction({
    required String originalTxId,
    required String proposalTxId,
    int timeout = 1,
  }) async {
    final txs = wallet.transactionHistory.transactions;

    try {
      final tx = txs.values
          .firstWhere((tx) => tx.id == originalTxId || tx.id == proposalTxId);
      return tx.id;
    } catch (e) {
      if (session == null) {
        return '';
      }

      // Wait for the specified timeout duration before retrying
      await Future.delayed(Duration(seconds: timeout));

      // Recursively call `waitForTransaction` to continue polling for the transaction
      return waitForTransaction(
        originalTxId: originalTxId,
        proposalTxId: proposalTxId,
      );
    }
  }
}
