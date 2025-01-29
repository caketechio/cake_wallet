import 'dart:ffi';
import 'dart:io';

import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_core/monero_wallet_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_monero/api/exceptions/wallet_opening_exception.dart';
import 'package:cw_core/get_height_by_date.dart';
import 'package:cw_monero/api/account_list.dart';
import 'package:cw_monero/api/wallet_manager.dart' as monero_wallet_manager;
import 'package:cw_monero/api/wallet_manager.dart';
import 'package:cw_monero/ledger.dart';
import 'package:cw_monero/monero_wallet.dart';
import 'package:collection/collection.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:monero/monero.dart' as monero;
import 'package:polyseed/polyseed.dart';

class MoneroNewWalletCredentials extends WalletCredentials {
  MoneroNewWalletCredentials(
      {required String name, required this.language, required this.isPolyseed, String? password})
      : super(name: name, password: password);

  final String language;
  final bool isPolyseed;
}

class MoneroRestoreWalletFromHardwareCredentials extends WalletCredentials {
  MoneroRestoreWalletFromHardwareCredentials({required String name,
    required this.ledgerConnection,
    int height = 0,
    String? password})
      : super(name: name, password: password, height: height);
  LedgerConnection ledgerConnection;
}

class MoneroRestoreWalletFromSeedCredentials extends WalletCredentials {
  MoneroRestoreWalletFromSeedCredentials(
      {required String name,
      required this.mnemonic,
      required this.passphrase,
      int height = 0,
      String? password})
      : super(name: name, password: password, height: height);

  final String mnemonic;
  final String passphrase;
}

class MoneroWalletLoadingException implements Exception {
  @override
  String toString() => 'Failure to load the wallet.';
}

class MoneroRestoreWalletFromKeysCredentials extends WalletCredentials {
  MoneroRestoreWalletFromKeysCredentials({required String name,
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

class MoneroWalletService extends WalletService<
    MoneroNewWalletCredentials,
    MoneroRestoreWalletFromSeedCredentials,
    MoneroRestoreWalletFromKeysCredentials,
    MoneroRestoreWalletFromHardwareCredentials> {
  MoneroWalletService(this.walletInfoSource, this.unspentCoinsInfoSource);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;

  static bool walletFilesExist(String path) =>
      !File(path).existsSync() && !File('$path.keys').existsSync();

  @override
  WalletType getType() => WalletType.monero;

  @override
  Future<MoneroWallet> create(MoneroNewWalletCredentials credentials, {bool? isTestnet}) async {
    try {
      final path = await pathForWallet(name: credentials.name, type: getType());

      if (credentials.isPolyseed) {
        final polyseed = Polyseed.create();
        final lang = PolyseedLang.getByEnglishName(credentials.language);

        if (credentials.passphrase != null) polyseed.crypt(credentials.passphrase!);

        final heightOverride =
        getMoneroHeigthByDate(date: DateTime.now().subtract(Duration(days: 2)));

        return _restoreFromPolyseed(
            path, credentials.password!, polyseed, credentials.walletInfo!, lang,
            overrideHeight: heightOverride, passphrase: credentials.passphrase);
      }

      await monero_wallet_manager.createWallet(
          path: path, password: credentials.password!, language: credentials.language);
      final wallet = MoneroWallet(
          walletInfo: credentials.walletInfo!,
          unspentCoinsInfo: unspentCoinsInfoSource,
          password: credentials.password!);
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      printV('MoneroWalletsManager Error: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Future<bool> isWalletExit(String name) async {
    try {
      final path = await pathForWallet(name: name, type: getType());
      return monero_wallet_manager.isWalletExist(path: path);
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      printV('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<MoneroWallet> openWallet(String name, String password, {bool? retryOnFailure}) async {
    try {
      final path = await pathForWallet(name: name, type: getType());

      if (walletFilesExist(path)) await repairOldAndroidWallet(name);

      await monero_wallet_manager
          .openWalletAsync({'path': path, 'password': password});
      final walletInfo = walletInfoSource.values
          .firstWhere((info) => info.id == WalletBase.idFor(name, getType()));
      final wallet = MoneroWallet(
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfoSource,
          password: password);
      final isValid = wallet.walletAddresses.validate();

      if (wallet.isHardwareWallet) {
        wallet.setLedgerConnection(gLedger!);
        gLedger = null;
      }

      if (!isValid) {
        await restoreOrResetWalletFiles(name);
        wallet.close(shouldCleanup: false);
        return openWallet(name, password);
      }

      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.

      if (retryOnFailure == false) {
        rethrow;
      }

      await restoreOrResetWalletFiles(name);
      return await openWallet(name, password, retryOnFailure: false);
    }
  }

  @override
  Future<void> remove(String wallet) async {
    final path = await pathForWalletDir(name: wallet, type: getType());
    if (openedWalletsByPath["$path/$wallet"] != null) {
      // NOTE: this is realistically only required on windows.
      printV("closing wallet");
      final wmaddr = wmPtr.address;
      final waddr = openedWalletsByPath["$path/$wallet"]!.address;
      // await Isolate.run(() {
      monero.WalletManager_closeWallet(
          Pointer.fromAddress(wmaddr), Pointer.fromAddress(waddr), false);
      // });
      openedWalletsByPath.remove("$path/$wallet");
      printV("wallet closed");
    }

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
    final currentWalletInfo = walletInfoSource.values.firstWhere(
        (info) => info.id == WalletBase.idFor(currentName, getType()));
    final currentWallet = MoneroWallet(
      walletInfo: currentWalletInfo,
      unspentCoinsInfo: unspentCoinsInfoSource,
      password: password,
    );

    await currentWallet.renameWalletFiles(newName);

    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<MoneroWallet> restoreFromKeys(MoneroRestoreWalletFromKeysCredentials credentials,
      {bool? isTestnet}) async {
    try {
      final path = await pathForWallet(name: credentials.name, type: getType());
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
          password: credentials.password!);
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      printV('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<MoneroWallet> restoreFromHardwareWallet(
      MoneroRestoreWalletFromHardwareCredentials credentials) async {
    try {
      final path = await pathForWallet(name: credentials.name, type: getType());
      final password = credentials.password;
      final height = credentials.height;

      if (wptr == null) monero_wallet_manager.createWalletPointer();

      enableLedgerExchange(wptr!, credentials.ledgerConnection);
      await monero_wallet_manager.restoreWalletFromHardwareWallet(
          path: path,
          password: password!,
          restoreHeight: height!,
          deviceName: 'Ledger');

      final wallet = MoneroWallet(
          walletInfo: credentials.walletInfo!,
          unspentCoinsInfo: unspentCoinsInfoSource,
          password: credentials.password!);
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      printV('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  @override
  Future<MoneroWallet> restoreFromSeed(
      MoneroRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    // Restore from Polyseed
    if (Polyseed.isValidSeed(credentials.mnemonic)) {
      return restoreFromPolyseed(credentials);
    }

    try {
      final path = await pathForWallet(name: credentials.name, type: getType());
      await monero_wallet_manager.restoreFromSeed(
          path: path,
          password: credentials.password!,
          passphrase: credentials.passphrase,
          seed: credentials.mnemonic,
          restoreHeight: credentials.height!);
      final wallet = MoneroWallet(
          walletInfo: credentials.walletInfo!,
          unspentCoinsInfo: unspentCoinsInfoSource,
          password: credentials.password!);
      await wallet.init();

      return wallet;
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      printV('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  Future<MoneroWallet> restoreFromPolyseed(
      MoneroRestoreWalletFromSeedCredentials credentials) async {
    try {
      final path = await pathForWallet(name: credentials.name, type: getType());
      final polyseedCoin = PolyseedCoin.POLYSEED_MONERO;
      final lang = PolyseedLang.getByPhrase(credentials.mnemonic);
      final polyseed =
          Polyseed.decode(credentials.mnemonic, lang, polyseedCoin);

      return _restoreFromPolyseed(
          path, credentials.password!, polyseed, credentials.walletInfo!, lang,
          passphrase: credentials.passphrase);
    } catch (e) {
      // TODO: Implement Exception for wallet list service.
      printV('MoneroWalletsManager Error: $e');
      rethrow;
    }
  }

  Future<MoneroWallet> _restoreFromPolyseed(
      String path, String password, Polyseed polyseed, WalletInfo walletInfo, PolyseedLang lang,
      {PolyseedCoin coin = PolyseedCoin.POLYSEED_MONERO,
      int? overrideHeight,
      String? passphrase}) async {
    
    if (polyseed.isEncrypted == false &&
        (passphrase??'') != "") {
      // Fallback to the different passphrase offset method, when a passphrase
      // was provided but the polyseed is not encrypted.
      monero_wallet_manager.restoreWalletFromPolyseedWithOffset(
        path: path,
        password: password,
        seed: polyseed.encode(lang, coin),
        seedOffset: passphrase??'',
        language: "English");
      
      final wallet = MoneroWallet(
        walletInfo: walletInfo,
        unspentCoinsInfo: unspentCoinsInfoSource,
        password: password,
      );
      await wallet.init();

      return wallet;
    }

    if (polyseed.isEncrypted) polyseed.crypt(passphrase ?? '');

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
    );
    await wallet.init();

    return wallet;
  }

  Future<void> repairOldAndroidWallet(String name) async {
    try {
      if (!Platform.isAndroid) return;

      final oldAndroidWalletDirPath = await outdatedAndroidPathForWalletDir(name: name);
      final dir = Directory(oldAndroidWalletDirPath);

      if (!dir.existsSync()) return;

      final newWalletDirPath = await pathForWalletDir(name: name, type: getType());

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
      printV(e.toString());
    }
  }

  @override
  Future<String> getSeeds(String name, String password, WalletType type) async {
    try {
      final path = await pathForWallet(name: name, type: getType());

      if (walletFilesExist(path)) await repairOldAndroidWallet(name);

      await monero_wallet_manager.openWalletAsync({'path': path, 'password': password});
      final walletInfo = walletInfoSource.values
          .firstWhere((info) => info.id == WalletBase.idFor(name, getType()));
      final wallet = MoneroWallet(
        walletInfo: walletInfo,
        unspentCoinsInfo: unspentCoinsInfoSource,
        password: password,
      );
      return wallet.seed;
    } catch (_) {
      // if the file couldn't be opened or read
      return '';
    }
  }

  @override
  bool requireHardwareWalletConnection(String name) {
    return walletInfoSource.values
            .firstWhereOrNull(
                (info) => info.id == WalletBase.idFor(name, getType()))
            ?.isHardwareWallet ??
        false;
  }
}
