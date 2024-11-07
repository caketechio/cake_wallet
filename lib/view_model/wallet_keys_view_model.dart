import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:cake_wallet/haven/haven.dart';
import 'package:cake_wallet/monero/monero.dart';
import 'package:cake_wallet/reactions/wallet_connect.dart';
import 'package:cake_wallet/src/screens/transaction_details/standart_list_item.dart';
import 'package:cake_wallet/store/app_store.dart';
import 'package:cake_wallet/wownero/wownero.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_monero/monero_wallet.dart';
import 'package:mobx/mobx.dart';
import 'package:polyseed/polyseed.dart';

part 'wallet_keys_view_model.g.dart';

class WalletKeysViewModel = WalletKeysViewModelBase with _$WalletKeysViewModel;

abstract class WalletKeysViewModelBase with Store {
  WalletKeysViewModelBase(this._appStore)
      : title = _appStore.wallet!.type == WalletType.bitcoin ||
                _appStore.wallet!.type == WalletType.litecoin ||
                _appStore.wallet!.type == WalletType.bitcoinCash
            ? S.current.wallet_seed
            : S.current.wallet_keys,
        _restoreHeight = _appStore.wallet!.walletInfo.restoreHeight,
        _restoreHeightByTransactions = 0,
        items = ObservableList<StandartListItem>() {
    _populateItems();

    reaction((_) => _appStore.wallet, (WalletBase? _wallet) {
      _populateItems();
    });

    if (_appStore.wallet!.type == WalletType.monero ||
        _appStore.wallet!.type == WalletType.haven ||
        _appStore.wallet!.type == WalletType.wownero) {
      final accountTransactions = _getWalletTransactions(_appStore.wallet!);
      if (accountTransactions.isNotEmpty) {
        final incomingAccountTransactions =
            accountTransactions.where((tx) => tx.direction == TransactionDirection.incoming);
        if (incomingAccountTransactions.isNotEmpty) {
          incomingAccountTransactions.toList().sort((a, b) => a.date.compareTo(b.date));
          _restoreHeightByTransactions = _getRestoreHeightByTransactions(
              _appStore.wallet!.type, incomingAccountTransactions.first.date);
        }
      }
    }
  }

  final ObservableList<StandartListItem> items;

  final String title;

  final AppStore _appStore;

  final int _restoreHeight;

  int _restoreHeightByTransactions;

  void _populateItems() {
    items.clear();

    if (_appStore.wallet!.type == WalletType.monero) {
      final keys = monero!.getKeys(_appStore.wallet!);

      items.addAll([
        if (keys['publicSpendKey'] != null)
          StandartListItem(title: S.current.spend_key_public, value: keys['publicSpendKey']!),
        if (keys['privateSpendKey'] != null)
          StandartListItem(title: S.current.spend_key_private, value: keys['privateSpendKey']!),
        if (keys['publicViewKey'] != null)
          StandartListItem(title: S.current.view_key_public, value: keys['publicViewKey']!),
        if (keys['privateViewKey'] != null)
          StandartListItem(title: S.current.view_key_private, value: keys['privateViewKey']!),
        StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
      ]);

      if (_appStore.wallet?.seed != null && Polyseed.isValidSeed(_appStore.wallet!.seed!)) {
        final lang = PolyseedLang.getByPhrase(_appStore.wallet!.seed!);
        items.add(StandartListItem(
            title: S.current.wallet_seed_legacy,
            value: (_appStore.wallet as MoneroWalletBase).seedLegacy(lang.nameEnglish)));
      }

      final restoreHeight = monero!.getRestoreHeight(_appStore.wallet!);
      if (restoreHeight != null) {
        items.add(StandartListItem(
            title: S.current.wallet_recovery_height, value: restoreHeight.toString()));
      }
    }

    if (_appStore.wallet!.type == WalletType.haven) {
      final keys = haven!.getKeys(_appStore.wallet!);

      items.addAll([
        if (keys['publicSpendKey'] != null)
          StandartListItem(title: S.current.spend_key_public, value: keys['publicSpendKey']!),
        if (keys['privateSpendKey'] != null)
          StandartListItem(title: S.current.spend_key_private, value: keys['privateSpendKey']!),
        if (keys['publicViewKey'] != null)
          StandartListItem(title: S.current.view_key_public, value: keys['publicViewKey']!),
        if (keys['privateViewKey'] != null)
          StandartListItem(title: S.current.view_key_private, value: keys['privateViewKey']!),
        StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
      ]);
    }

    if (_appStore.wallet!.type == WalletType.wownero) {
      final keys = wownero!.getKeys(_appStore.wallet!);

      items.addAll([
        if (keys['publicSpendKey'] != null)
          StandartListItem(title: S.current.spend_key_public, value: keys['publicSpendKey']!),
        if (keys['privateSpendKey'] != null)
          StandartListItem(title: S.current.spend_key_private, value: keys['privateSpendKey']!),
        if (keys['publicViewKey'] != null)
          StandartListItem(title: S.current.view_key_public, value: keys['publicViewKey']!),
        if (keys['privateViewKey'] != null)
          StandartListItem(title: S.current.view_key_private, value: keys['privateViewKey']!),
        StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
      ]);

      if (_appStore.wallet?.seed != null && Polyseed.isValidSeed(_appStore.wallet!.seed!)) {
        final lang = PolyseedLang.getByPhrase(_appStore.wallet!.seed!);
        items.add(StandartListItem(
            title: S.current.wallet_seed_legacy,
            value: wownero!.getLegacySeed(_appStore.wallet!, lang.nameEnglish)));
      }
    }

    if (_appStore.wallet!.type == WalletType.bitcoin ||
        _appStore.wallet!.type == WalletType.litecoin ||
        _appStore.wallet!.type == WalletType.bitcoinCash) {
      final keys = bitcoin!.getWalletKeys(_appStore.wallet!);

      items.addAll([
        if (keys['wif'] != null) StandartListItem(title: "WIF", value: keys['wif']!),
        if (keys['privateKey'] != null)
          StandartListItem(title: S.current.private_key, value: keys['privateKey']!),
        if (keys['p2wpkhMainnetPrivKey'] != null)
          StandartListItem(
              title: S.current.private_key + ' (mainnet P2WPKH)',
              value: keys['p2wpkhMainnetPrivKey']!),
        if (keys['publicKey'] != null)
          StandartListItem(title: S.current.public_key, value: keys['publicKey']!),
        if (keys['p2wpkhMainnetPubKey'] != null)
          StandartListItem(
              title: S.current.public_key + ' (mainnet P2WPKH)',
              value: keys['p2wpkhMainnetPubKey']!),
        StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
      ]);
    }

    if (isEVMCompatibleChain(_appStore.wallet!.type) ||
        _appStore.wallet!.type == WalletType.solana ||
        _appStore.wallet!.type == WalletType.tron) {
      items.addAll([
        if (_appStore.wallet!.privateKey != null)
          StandartListItem(title: S.current.private_key, value: _appStore.wallet!.privateKey!),
        if (_appStore.wallet!.seed != null)
          StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
      ]);
    }

    bool nanoBased =
        _appStore.wallet!.type == WalletType.nano || _appStore.wallet!.type == WalletType.banano;

    if (nanoBased) {
      // we always have the hex version of the seed and private key:
      items.addAll([
        if (_appStore.wallet!.seed != null)
          StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
        if (_appStore.wallet!.hexSeed != null)
          StandartListItem(title: S.current.seed_hex_form, value: _appStore.wallet!.hexSeed!),
        if (_appStore.wallet!.privateKey != null)
          StandartListItem(title: S.current.private_key, value: _appStore.wallet!.privateKey!),
      ]);
    }
  }

  Future<int?> _currentHeight() async {
    if (_appStore.wallet!.type == WalletType.haven) {
      return await haven!.getCurrentHeight();
    }
    if (_appStore.wallet!.type == WalletType.monero) {
      return await monero!.getCurrentHeight();
    }
    if (_appStore.wallet!.type == WalletType.wownero) {
      return await wownero!.getCurrentHeight();
    }
    return null;
  }

  String get _scheme {
    switch (_appStore.wallet!.type) {
      case WalletType.monero:
        return 'monero-wallet';
      case WalletType.bitcoin:
        return 'bitcoin-wallet';
      case WalletType.litecoin:
        return 'litecoin-wallet';
      case WalletType.haven:
        return 'haven-wallet';
      case WalletType.ethereum:
        return 'ethereum-wallet';
      case WalletType.bitcoinCash:
        return 'bitcoincash-wallet';
      case WalletType.nano:
        return 'nano-wallet';
      case WalletType.banano:
        return 'banano-wallet';
      case WalletType.polygon:
        return 'polygon-wallet';
      case WalletType.solana:
        return 'solana-wallet';
      case WalletType.tron:
        return 'tron-wallet';
      case WalletType.wownero:
        return 'wownero-wallet';
      default:
        throw Exception('Unexpected wallet type: ${_appStore.wallet!.type.toString()}');
    }
  }

  Future<String?> get restoreHeight async {
    if (_restoreHeightByTransactions != 0)
      return getRoundedRestoreHeight(_restoreHeightByTransactions);
    if (_restoreHeight != 0) return _restoreHeight.toString();

    final currentHeight = await _currentHeight();
    if (currentHeight == null) return null;

    return getRoundedRestoreHeight(currentHeight);
  }

  Future<Map<String, String>> get _queryParams async {
    final restoreHeightResult = await restoreHeight;
    return {
      if (_appStore.wallet!.seed != null) 'seed': _appStore.wallet!.seed!,
      if (_appStore.wallet!.seed == null && _appStore.wallet!.hexSeed != null)
        'hexSeed': _appStore.wallet!.hexSeed!,
      if (_appStore.wallet!.seed == null && _appStore.wallet!.privateKey != null)
        'private_key': _appStore.wallet!.privateKey!,
      if (restoreHeightResult != null) ...{'height': restoreHeightResult},
      if (_appStore.wallet!.passphrase != null) 'passphrase': _appStore.wallet!.passphrase!
    };
  }

  Future<Uri> get url async => Uri(
        scheme: _scheme,
        queryParameters: await _queryParams,
      );

  List<TransactionInfo> _getWalletTransactions(WalletBase wallet) {
    if (wallet.type == WalletType.monero) {
      return monero!.getTransactionHistory(wallet).transactions.values.toList();
    } else if (wallet.type == WalletType.haven) {
      return haven!.getTransactionHistory(wallet).transactions.values.toList();
    } else if (wallet.type == WalletType.wownero) {
      return wownero!.getTransactionHistory(wallet).transactions.values.toList();
    }
    return [];
  }

  int _getRestoreHeightByTransactions(WalletType type, DateTime date) {
    if (type == WalletType.monero) {
      return monero!.getHeightByDate(date: date);
    } else if (type == WalletType.haven) {
      return haven!.getHeightByDate(date: date);
    } else if (type == WalletType.wownero) {
      return wownero!.getHeightByDate(date: date);
    }
    return 0;
  }

  String getRoundedRestoreHeight(int height) => ((height / 1000).floor() * 1000).toString();
}
