import 'package:cake_wallet/core/seed_validator.dart';
import 'package:cake_wallet/entities/parse_address_from_domain.dart';
import 'package:cake_wallet/entities/qr_scanner.dart';
import 'package:cake_wallet/routes.dart';
import 'package:cake_wallet/src/widgets/alert_with_one_action.dart';
import 'package:cake_wallet/utils/show_pop_up.dart';
import 'package:cake_wallet/view_model/restore/restore_mode.dart';
import 'package:cake_wallet/view_model/restore/restore_wallet.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/cupertino.dart';
import 'package:cake_wallet/generated/i18n.dart';
import 'package:collection/collection.dart';
import 'package:polyseed/polyseed.dart';

class WalletRestoreFromQRCode {
  WalletRestoreFromQRCode();

  static const Map<String, WalletType> _walletTypeMap = {
    'monero': WalletType.monero,
    'monero-wallet': WalletType.monero,
    'monero_wallet': WalletType.monero,
    'bitcoin': WalletType.bitcoin,
    'bitcoin-wallet': WalletType.bitcoin,
    'bitcoin_wallet': WalletType.bitcoin,
    'lightning': WalletType.lightning,
    'lightning-wallet': WalletType.lightning,
    'lightning_wallet': WalletType.lightning,
    'litecoin': WalletType.litecoin,
    'litecoin-wallet': WalletType.litecoin,
    'litecoin_wallet': WalletType.litecoin,
    'ethereum-wallet': WalletType.ethereum,
    'polygon-wallet': WalletType.polygon,
    'nano-wallet': WalletType.nano,
    'nano_wallet': WalletType.nano,
    'bitcoincash': WalletType.bitcoinCash,
    'bitcoincash-wallet': WalletType.bitcoinCash,
    'bitcoincash_wallet': WalletType.bitcoinCash,
    'solana-wallet': WalletType.solana,
    'tron': WalletType.tron,
    'tron-wallet': WalletType.tron,
    'tron_wallet': WalletType.tron,
    'wownero': WalletType.wownero,
    'wownero-wallet': WalletType.wownero,
    'wownero_wallet': WalletType.wownero,
  };

  static bool _containsAssetSpecifier(String code) => _extractWalletType(code) != null;

  static WalletType? _extractWalletType(String code) {
    final sortedKeys = _walletTypeMap.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

    final extracted = sortedKeys.firstWhereOrNull((key) => code.toLowerCase().contains(key));

    return _walletTypeMap[extracted];
  }

  static String? _extractAddressFromUrl(String rawString, WalletType type) {
    return AddressResolver.extractAddressByType(
        raw: rawString, type: walletTypeToCryptoCurrency(type));
  }

  static String? _extractSeedPhraseFromUrl(String rawString, WalletType walletType) {
    RegExp _getPattern(int wordCount) =>
        RegExp(r'(?<=\W|^)((?:\w+\s+){' + (wordCount - 1).toString() + r'}\w+)(?=\W|$)');

    List<int> patternCounts = walletType == WalletType.monero || walletType == WalletType.wownero
        ? [25, 16, 14, 13]
        : [24, 18, 12];

    for (final count in patternCounts) {
      final pattern = _getPattern(count);
      final match = pattern.firstMatch(rawString);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }
    return null;
  }

  static Future<RestoredWallet> scanQRCodeForRestoring(BuildContext context) async {
    String code = await presentQRScanner();
    if (code.isEmpty) throw Exception('Unexpected scan QR code value: value is empty');

    WalletType? walletType;
    String formattedUri = '';

    if (!_containsAssetSpecifier(code)) {
      await _specifyWalletAssets(context, "Can't determine wallet type, please pick it manually");
      walletType =
          await Navigator.pushNamed(context, Routes.restoreWalletTypeFromQR) as WalletType?;
      if (walletType == null) throw Exception("Failed to determine wallet type.");

      final seedPhrase = _extractSeedPhraseFromUrl(code, walletType);

      formattedUri = seedPhrase != null
          ? '$walletType:?seed=$seedPhrase'
          : throw Exception('Failed to determine valid seed phrase');
    } else {
      walletType = _extractWalletType(code);
      final index = code.indexOf(':');
      final query = code.substring(index + 1).replaceAll('?', '&');
      formattedUri = '$walletType:?$query';
    }

    final uri = Uri.parse(formattedUri);
    Map<String, dynamic> queryParameters = {...uri.queryParameters};

    if (queryParameters['seed'] == null) {
      queryParameters['seed'] = _extractSeedPhraseFromUrl(code, walletType!);
    }
    if (queryParameters['address'] == null) {
      queryParameters['address'] = _extractAddressFromUrl(code, walletType!);
    }

    Map<String, dynamic> credentials = {'type': walletType, ...queryParameters};

    credentials['mode'] = _determineWalletRestoreMode(credentials);

    switch (credentials['mode']) {
      case WalletRestoreMode.txids:
        return RestoredWallet.fromTxIds(credentials);
      case WalletRestoreMode.seed:
        return RestoredWallet.fromSeed(credentials);
      case WalletRestoreMode.keys:
        return RestoredWallet.fromKey(credentials);
      default:
        throw Exception('Unexpected restore mode: ${credentials['mode']}');
    }
  }

  static WalletRestoreMode _determineWalletRestoreMode(Map<String, dynamic> credentials) {
    final type = credentials['type'] as WalletType;
    if (credentials.containsKey('tx_payment_id')) {
      final txIdValue = credentials['tx_payment_id'] as String? ?? '';
      if (txIdValue.isNotEmpty) return WalletRestoreMode.txids;
      throw Exception('Unexpected restore mode: tx_payment_id is invalid');
    }

    if (credentials['seed'] != null) {
      final seedValue = credentials['seed'] as String;
      final words = SeedValidator.getWordList(type: type, language: 'english');

      if ((type == WalletType.monero || type == WalletType.wownero) &&
          Polyseed.isValidSeed(seedValue)) {
        return WalletRestoreMode.seed;
      }

      seedValue.split(' ').forEach((element) {
        if (!words.contains(element)) {
          throw Exception(
              "Unexpected restore mode: mnemonic_seed is invalid or doesn't match wallet type");
        }
      });
      return WalletRestoreMode.seed;
    }

    if (credentials.containsKey('spend_key') || credentials.containsKey('view_key')) {
      final spendKeyValue = credentials['spend_key'] as String? ?? '';
      final viewKeyValue = credentials['view_key'] as String? ?? '';

      return spendKeyValue.isNotEmpty || viewKeyValue.isNotEmpty
          ? WalletRestoreMode.keys
          : throw Exception('Unexpected restore mode: spend_key or view_key is invalid');
    }

    if (type == WalletType.ethereum && credentials.containsKey('private_key')) {
      final privateKey = credentials['private_key'] as String;
      if (privateKey.isEmpty) {
        throw Exception('Unexpected restore mode: private_key');
      }
      return WalletRestoreMode.keys;
    }

    if (type == WalletType.polygon && credentials.containsKey('private_key')) {
      final privateKey = credentials['private_key'] as String;
      if (privateKey.isEmpty) {
        throw Exception('Unexpected restore mode: private_key');
      }
      return WalletRestoreMode.keys;
    }

    if ((type == WalletType.nano || type == WalletType.banano) &&
        credentials.containsKey('hexSeed')) {
      final hexSeed = credentials['hexSeed'] as String;
      if (hexSeed.isEmpty) {
        throw Exception('Unexpected restore mode: hexSeed');
      }
      return WalletRestoreMode.seed;
    }

    if (type == WalletType.solana && credentials.containsKey('private_key')) {
      final privateKey = credentials['private_key'] as String;
      if (privateKey.isEmpty) {
        throw Exception('Unexpected restore mode: private_key');
      }
      return WalletRestoreMode.keys;
    }

    if (type == WalletType.tron && credentials.containsKey('private_key')) {
      final privateKey = credentials['private_key'] as String;
      if (privateKey.isEmpty) {
        throw Exception('Unexpected restore mode: private_key');
      }
      return WalletRestoreMode.keys;
    }

    throw Exception('Unexpected restore mode: restore params are invalid');
  }
}

Future<void> _specifyWalletAssets(BuildContext context, String error) async {
  await showPopUp<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertWithOneAction(
            alertTitle: S.current.error,
            alertContent: error,
            buttonText: S.of(context).ok,
            buttonAction: () => Navigator.of(context).pop());
      });
}
