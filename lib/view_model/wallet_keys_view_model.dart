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
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:polyseed/polyseed.dart';

part 'wallet_keys_view_model.g.dart';

class WalletKeysViewModel = WalletKeysViewModelBase with _$WalletKeysViewModel;

abstract class WalletKeysViewModelBase with Store {
  WalletKeysViewModelBase(this._appStore)
      : title = S.current.wallet_keys,
        _wallet = _appStore.wallet!,
        _walletName = _appStore.wallet!.type.name,
        _restoreHeight = _appStore.wallet!.walletInfo.restoreHeight,
        _restoreHeightByTransactions = 0,
        items = ObservableList<StandartListItem>() {
    _populateKeysItems();

    reaction((_) => _appStore.wallet, (WalletBase? _wallet) {
      _populateKeysItems();
    });

    if (_wallet.type == WalletType.monero ||
        _wallet.type == WalletType.haven ||
        _wallet.type == WalletType.wownero) {
      final accountTransactions = _getWalletTransactions(_wallet);
      if (accountTransactions.isNotEmpty) {
        final incomingAccountTransactions =
            accountTransactions.where((tx) => tx.direction == TransactionDirection.incoming);
        if (incomingAccountTransactions.isNotEmpty) {
          incomingAccountTransactions.toList().sort((a, b) => a.date.compareTo(b.date));
          _restoreHeightByTransactions =
              _getRestoreHeightByTransactions(_wallet.type, incomingAccountTransactions.first.date);
        }
      }
    }
  }

  final ObservableList<StandartListItem> items;

  final String title;
  final WalletBase _wallet;
  final String _walletName;
  final AppStore _appStore;
  final int _restoreHeight;

  int _restoreHeightByTransactions;

  AppStore get appStore => _appStore;

  String get seed => _wallet.seed != null ? _wallet.seed! : '';

  bool get isLegacySeedOnly =>
      (_wallet.type == WalletType.monero || _wallet.type == WalletType.wownero) &&
          _wallet.seed != null &&
          !Polyseed.isValidSeed(_wallet.seed!);

  String get legacySeed {
    if ((_wallet.type == WalletType.monero || _wallet.type == WalletType.wownero) &&
        _wallet.seed != null &&
        Polyseed.isValidSeed(_wallet.seed!)) {
      final langName = PolyseedLang.getByPhrase(_wallet.seed!).nameEnglish;

      if (_wallet.type == WalletType.monero) {
        return (_wallet as MoneroWalletBase).seedLegacy(langName);
      } else if (_wallet.type == WalletType.wownero) {
        return wownero!.getLegacySeed(_wallet, langName);
      }
    }
    return '';
  }

  String get legacyRestoreHeight {
    if (_wallet.type == WalletType.monero) {
      return monero!.getRestoreHeight(_wallet)?.toString() ?? '';
    }
    return '';
  }

  /// The Regex split the words based on any whitespace character.
  ///
  /// Either standard ASCII space (U+0020) or the full-width space character (U+3000) used by the Japanese.
  List<String> get seedSplit => seed.isNotEmpty ? seed.split(RegExp(r'\s+')) : [];

  List<String> get legacySeedSplit => legacySeed.isNotEmpty ? legacySeed.split(RegExp(r'\s+')) : [];

  void _populateKeysItems() {
    items.clear();

    if (_wallet.type == WalletType.monero) {
      final keys = monero!.getKeys(_wallet);

      items.addAll([
        if (keys['primaryAddress'] != null)
          StandartListItem(
              key: ValueKey('${_walletName}_wallet_primary_address_item_key'),
              title: S.current.primary_address,
              value: keys['primaryAddress']!),
        if (keys['publicSpendKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_public_spend_key_item_key'),
            title: S.current.spend_key_public,
            value: keys['publicSpendKey']!,
          ),
        if (keys['privateSpendKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_spend_key_item_key'),
            title: S.current.spend_key_private,
            value: keys['privateSpendKey']!,
          ),
        if (keys['publicViewKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_public_view_key_item_key'),
            title: S.current.view_key_public,
            value: keys['publicViewKey']!,
          ),
        if (keys['privateViewKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_view_key_item_key'),
            title: S.current.view_key_private,
            value: keys['privateViewKey']!,
          ),
      ]);
    }

    if (_wallet.type == WalletType.haven) {
      final keys = haven!.getKeys(_wallet);

      items.addAll([
        if (keys['primaryAddress'] != null)
          StandartListItem(
              key: ValueKey('${_walletName}_wallet_primary_address_item_key'),
              title: S.current.primary_address,
              value: keys['primaryAddress']!),
        if (keys['publicSpendKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_public_spend_key_item_key'),
            title: S.current.spend_key_public,
            value: keys['publicSpendKey']!,
          ),
        if (keys['privateSpendKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_spend_key_item_key'),
            title: S.current.spend_key_private,
            value: keys['privateSpendKey']!,
          ),
        if (keys['publicViewKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_public_view_key_item_key'),
            title: S.current.view_key_public,
            value: keys['publicViewKey']!,
          ),
        if (keys['privateViewKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_view_key_item_key'),
            title: S.current.view_key_private,
            value: keys['privateViewKey']!,
          ),
      ]);
    }

    if (_wallet.type == WalletType.wownero) {
      final keys = wownero!.getKeys(_wallet);

      items.addAll([
        if (keys['primaryAddress'] != null)
          StandartListItem(
              key: ValueKey('${_walletName}_wallet_primary_address_item_key'),
              title: S.current.primary_address,
              value: keys['primaryAddress']!),
        if (keys['publicSpendKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_public_spend_key_item_key'),
            title: S.current.spend_key_public,
            value: keys['publicSpendKey']!,
          ),
        if (keys['privateSpendKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_spend_key_item_key'),
            title: S.current.spend_key_private,
            value: keys['privateSpendKey']!,
          ),
        if (keys['publicViewKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_public_view_key_item_key'),
            title: S.current.view_key_public,
            value: keys['publicViewKey']!,
          ),
        if (keys['privateViewKey'] != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_view_key_item_key'),
            title: S.current.view_key_private,
            value: keys['privateViewKey']!,
          ),
      ]);
    }

    // if (_wallet.type == WalletType.bitcoin ||
    //     _wallet.type == WalletType.litecoin ||
    //     _wallet.type == WalletType.bitcoinCash) {
    //   final keys = bitcoin!.getWalletKeys(_appStore.wallet!);
    //
    //   items.addAll([
    //     if (keys['wif'] != null)
    //       StandartListItem(title: "WIF", value: keys['wif']!),
    //     if (keys['privateKey'] != null)
    //       StandartListItem(title: S.current.private_key, value: keys['privateKey']!),
    //     if (keys['publicKey'] != null)
    //       StandartListItem(title: S.current.public_key, value: keys['publicKey']!),
    //   ]);
    // }

    if (isEVMCompatibleChain(_wallet.type) ||
        _wallet.type == WalletType.solana ||
        _wallet.type == WalletType.tron) {
      items.addAll([
        if (_wallet.privateKey != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_key_item_key'),
            title: S.current.private_key,
            value: _wallet.privateKey!,
          ),
      ]);
    }

    bool nanoBased = _wallet.type == WalletType.nano || _wallet.type == WalletType.banano;

    if (nanoBased) {
      // we always have the hex version of the seed and private key:
      items.addAll([
        if (_wallet.hexSeed != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_hex_seed_key'),
            title: S.current.seed_hex_form,
            value: _wallet.hexSeed!,
          ),
        if (_wallet.privateKey != null)
          StandartListItem(
            key: ValueKey('${_walletName}_wallet_private_key_item_key'),
            title: S.current.private_key,
            value: _wallet.privateKey!,
          ),
      ]);
    }

    if (_appStore.wallet!.type == WalletType.zano) {
      items.addAll([
        StandartListItem(title: S.current.wallet_seed, value: _appStore.wallet!.seed!),
      ]);
    }
  }

  Future<int?> _currentHeight() async {
    if (_wallet.type == WalletType.haven) {
      return await haven!.getCurrentHeight();
    }
    if (_wallet.type == WalletType.monero) {
      return await monero!.getCurrentHeight();
    }
    if (_wallet.type == WalletType.wownero) {
      return await wownero!.getCurrentHeight();
    }
    return null;
  }

  String get _scheme {
    switch (_wallet.type) {
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
      case WalletType.zano:
        return 'zano-wallet';
      default:
        throw Exception('Unexpected wallet type: ${_wallet.type.toString()}');
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
      if (_wallet.seed != null) 'seed': _wallet.seed!,
      if (_wallet.seed == null && _wallet.hexSeed != null) 'hexSeed': _wallet.hexSeed!,
      if (_wallet.seed == null && _wallet.privateKey != null) 'private_key': _wallet.privateKey!,
      if (restoreHeightResult != null) ...{'height': restoreHeightResult},
      if (_wallet.passphrase != null) 'passphrase': _wallet.passphrase!
    };
  }

  Future<Map<String, String>> get _queryParamsForLegacy async {
    final restoreHeightResult = await restoreHeight;
    return {
      if (legacySeed.isNotEmpty) 'seed': legacySeed,
      if (restoreHeightResult != null) ...{'height': restoreHeightResult},
      if ((_wallet.passphrase ?? '') != '') 'passphrase': _wallet.passphrase!
    };
  }

  Future<Uri> getUrl(bool isLegacySeed) async => Uri(
        scheme: _scheme,
        queryParameters: isLegacySeed ? await _queryParamsForLegacy : await _queryParams,
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
