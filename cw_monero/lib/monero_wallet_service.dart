import 'dart:io';
import 'package:cw_core/monero_wallet_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_monero/api/exceptions/wallet_opening_exception.dart';
import 'package:cw_monero/api/wallet_manager.dart' as monero_wallet_manager;
import 'package:cw_monero/monero_wallet.dart';
import 'package:hive/hive.dart';
import 'package:polyseed/polyseed.dart';

class MoneroNewWalletCredentials extends WalletCredentials {
  MoneroNewWalletCredentials(
      {required String name, required this.language, required this.isPolyseed, String? password})
      : super(name: name, password: password);

  final String language;
  final bool isPolyseed;
}

class MoneroRestoreWalletFromSeedCredentials extends WalletCredentials {
  MoneroRestoreWalletFromSeedCredentials(
      {required String name, required this.mnemonic, int height = 0, String? password})
      : super(name: name, password: password, height: height);

  final String mnemonic;
}

class MoneroWalletLoadingException implements Exception {
  @override
  String toString() => 'Failure to load the wallet.';
}

class MoneroRestoreWalletFromKeysCredentials extends WalletCredentials {
  MoneroRestoreWalletFromKeysCredentials(
      {required String name,
      required String password,
      required this.language,
      required this.address,
      required this.viewKey,
      required this.spendKey,
      int height = 0})
      : super(name: name, password: password, height: height);

  final String language;
  final String address;
  final String viewKey;
  final String spendKey;
}

class MoneroWalletService extends WalletService<MoneroNewWalletCredentials,
    MoneroRestoreWalletFromSeedCredentials, MoneroRestoreWalletFromKeysCredentials> {
  MoneroWalletService(this.walletInfoSource, this.unspentCoinsInfoSource, this.isFlatpak);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool isFlatpak;

  static bool walletFilesExist(String path) =>
      !File(path).existsSync() && !File('$path.keys').existsSync();

  @override
  WalletType getType() => WalletType.monero;

  @override
  Future<MoneroWallet> create(MoneroNewWalletCredentials credentials) async {
    try {
      final path =
          await pathForWallet(name: credentials.name, type: getType(), isFlatpak: isFlatpak);

      if (credentials.isPolyseed) {
        final polyseed = Polyseed.create();
        final lang = PolyseedLang.getByEnglishName(credentials.language);

        final heightOverride =
            getMoneroHeigthByDate(date: DateTime.now().subtract(Duration(days: 2)));

        return _restoreFromPolyseed(
            path, credentials.password!, polyseed, credentials.walletInfo!, lang,
            overrideHeight: heightOverride);
      }

      await monero_wallet_manager.createWallet(
          path: path, password: credentials.password!, language: credentials.language);
      final wallet = MoneroWallet(
        walletInfo: credentials.walletInfo!,
        unspentCoinsInfo: unspentCoinsInfoSource,
        password: credentials.password!,
        isFlatpak: isFlatpak,
      );
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('MoneroWalletsManager Error: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<bool> isWalletExit(String name) async {
    try {
      final path = await pathForWallet(name: name, type: getType(), isFlatpak: isFlatpak);
      return monero_wallet_manager.isWalletExist(path: path);
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<MoneroWallet> openWallet(String name, String password) async {
    try {
      final path = await pathForWallet(name: name, type: getType(), isFlatpak: isFlatpak);

      if (walletFilesExist(path)) {
        await repairOldAndroidWallet(name);
      }

      await monero_wallet_manager.openWalletAsync({'path': path, 'password': password});
      final walletInfo = walletInfoSource.values
          .firstWhere((info) => info.id == WalletBase.idFor(name, getType()));
      final wallet = MoneroWallet(
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfoSource,
          password: password,
          isFlatpak: isFlatpak);
      final isValid = wallet.walletAddresses.validate();

      if (!isValid) {
        await restoreOrResetWalletFiles(name, isFlatpak);
        wallet.close();
        return openWallet(name, password);
      }

      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.

      final bool isBadAlloc = e.toString().contains('bad_alloc') ||
          (e is WalletOpeningException &&
              (e.message == 'std::bad_alloc' || e.message.contains('bad_alloc')));

      final bool doesNotCorrespond = e.toString().contains('does not correspond') ||
          (e is WalletOpeningException && e.message.contains('does not correspond'));

      final bool isMissingCacheFilesIOS = e.toString().contains('basic_string') ||
          (e is WalletOpeningException && e.message.contains('basic_string'));

      final bool isMissingCacheFilesAndroid = e.toString().contains('input_stream') ||
          e.toString().contains('input stream error') ||
          (e is WalletOpeningException &&
              (e.message.contains('input_stream') || e.message.contains('input stream error')));

      final bool invalidSignature = e.toString().contains('invalid signature') ||
          (e is WalletOpeningException && e.message.contains('invalid signature'));

      if (isBadAlloc ||
          doesNotCorrespond ||
          isMissingCacheFilesIOS ||
          isMissingCacheFilesAndroid ||
          invalidSignature) {
        await restoreOrResetWalletFiles(name, isFlatpak);
        return openWallet(name, password);
      }

      rethrow;
    }
  }

  @override
  Future<void> remove(String wallet) async {
    final path = await pathForWalletDir(name: wallet, type: getType(), isFlatpak: isFlatpak);
    final file = Directory(path);
    final isExist = file.existsSync();

    if (isExist) {
      await file.delete(recursive: true);
    }

    final walletInfo = walletInfoSource.values
        .firstWhere((info) => info.id == WalletBase.idFor(wallet, getType()));
    await walletInfoSource.delete(walletInfo.key);
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    final currentWalletInfo = walletInfoSource.values
        .firstWhere((info) => info.id == WalletBase.idFor(currentName, getType()));
    final currentWallet = MoneroWallet(
      walletInfo: currentWalletInfo,
      unspentCoinsInfo: unspentCoinsInfoSource,
      password: password,
      isFlatpak: isFlatpak,
    );

    await currentWallet.renameWalletFiles(newName);

    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<MoneroWallet> restoreFromKeys(MoneroRestoreWalletFromKeysCredentials credentials) async {
    try {
      final path =
          await pathForWallet(name: credentials.name, type: getType(), isFlatpak: isFlatpak);
      await monero_wallet_manager.restoreFromKeys(
          path: path,
          password: credentials.password!,
          language: credentials.language,
          restoreHeight: credentials.height!,
          address: credentials.address,
          viewKey: credentials.viewKey,
          spendKey: credentials.spendKey);
      final wallet = MoneroWallet(
        walletInfo: credentials.walletInfo!,
        unspentCoinsInfo: unspentCoinsInfoSource,
        password: credentials.password!,
        isFlatpak: isFlatpak,
      );
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<MoneroWallet> restoreFromSeed(MoneroRestoreWalletFromSeedCredentials credentials) async {
    // Restore from Polyseed
    if (Polyseed.isValidSeed(credentials.mnemonic)) {
      return restoreFromPolyseed(credentials);
    }

    try {
      final path =
          await pathForWallet(name: credentials.name, type: getType(), isFlatpak: isFlatpak);
      await monero_wallet_manager.restoreFromSeed(
          path: path,
          password: credentials.password!,
          seed: credentials.mnemonic,
          restoreHeight: credentials.height!);
      final wallet = MoneroWallet(
        walletInfo: credentials.walletInfo!,
        unspentCoinsInfo: unspentCoinsInfoSource,
        password: credentials.password!,
        isFlatpak: isFlatpak,
      );
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  Future<MoneroWallet> restoreFromPolyseed(
      MoneroRestoreWalletFromSeedCredentials credentials) async {
    try {
      final path =
          await pathForWallet(name: credentials.name, type: getType(), isFlatpak: isFlatpak);
      final polyseedCoin = PolyseedCoin.POLYSEED_MONERO;
      final lang = PolyseedLang.getByPhrase(credentials.mnemonic);
      final polyseed = Polyseed.decode(credentials.mnemonic, lang, polyseedCoin);

      return _restoreFromPolyseed(
          path, credentials.password!, polyseed, credentials.walletInfo!, lang);
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      print('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  Future<MoneroWallet> _restoreFromPolyseed(
      String path, String password, Polyseed polyseed, WalletInfo walletInfo, PolyseedLang lang,
      {PolyseedCoin coin = PolyseedCoin.POLYSEED_MONERO, int? overrideHeight}) async {
    final height = overrideHeight ??
        getMoneroHeigthByDate(date: DateTime.fromMillisecondsSinceEpoch(polyseed.birthday * 1000));
    final spendKey = polyseed.generateKey(coin, 32).toHexString();
    final seed = polyseed.encode(lang, coin);

    walletInfo.isRecovery = true;
    walletInfo.restoreHeight = height;

    await monero_wallet_manager.restoreFromSpendKey(
        path: path,
        password: password,
        seed: seed,
        language: lang.nameEnglish,
        restoreHeight: height,
        spendKey: spendKey);

    final wallet = MoneroWallet(
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfoSource,
      password: password,
      isFlatpak: isFlatpak,
    );
    await wallet.init();

    return wallet;
  }

  Future<void> repairOldAndroidWallet(String name) async {
    try {
      if (!Platform.isAndroid) {
        return;
      }

      final oldAndroidWalletDirPath =
          await outdatedAndroidPathForWalletDir(name: name, isFlatpak: isFlatpak);
      final dir = Directory(oldAndroidWalletDirPath);

      if (!dir.existsSync()) {
        return;
      }

      final newWalletDirPath =
          await pathForWalletDir(name: name, type: getType(), isFlatpak: isFlatpak);

      dir.listSync().forEach((f) {
        final file = File(f.path);
        final name = f.path.split('/').last;
        final newPath = newWalletDirPath + '/$name';
        final newFile = File(newPath);

        if (!newFile.existsSync()) {
          newFile.createSync();
        }
        newFile.writeAsBytesSync(file.readAsBytesSync());
      });
    } catch (e) {
      print(e.toString());
    }
  }
}
