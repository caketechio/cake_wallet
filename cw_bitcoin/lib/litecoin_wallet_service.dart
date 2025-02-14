import 'dart:io';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_mnemonics_bip39.dart';
import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_bitcoin/mnemonic_is_incorrect_exception.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:hive/hive.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_bitcoin/litecoin_wallet.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:collection/collection.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:path_provider/path_provider.dart';

class LitecoinWalletService extends WalletService<
    BitcoinNewWalletCredentials,
    BitcoinRestoreWalletFromSeedCredentials,
    BitcoinRestoreWalletFromWIFCredentials,
    BitcoinRestoreWalletFromHardware> {
  LitecoinWalletService(
      this.walletInfoSource, this.unspentCoinsInfoSource, this.alwaysScan, this.isDirect);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool alwaysScan;
  final bool isDirect;

  @override
  WalletType getType() => WalletType.litecoin;

  @override
  Future<LitecoinWallet> create(BitcoinNewWalletCredentials credentials, {bool? isTestnet}) async {
    final String mnemonic;
    switch (credentials.walletInfo?.derivationInfo?.derivationType) {
      case DerivationType.bip39:
        final strength = credentials.seedPhraseLength == 24 ? 256 : 128;

        mnemonic = credentials.mnemonic ?? await MnemonicBip39.generate(strength: strength);
        break;
      case DerivationType.electrum:
      default:
        mnemonic = await generateElectrumMnemonic();
        break;
    }

    final wallet = await LitecoinWalletBase.create(
      mnemonic: mnemonic,
      password: credentials.password!,
      passphrase: credentials.passphrase,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );
    await wallet.save();
    await wallet.init();

    return wallet;
  }

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<LitecoinWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(name, getType()))!;

    try {
      final wallet = await LitecoinWalletBase.open(
        password: password,
        name: name,
        walletInfo: walletInfo,
        unspentCoinsInfo: unspentCoinsInfoSource,
        alwaysScan: alwaysScan,
        encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      );
      await wallet.init();
      saveBackup(name);
      return wallet;
    } catch (_) {
      await restoreWalletFilesFromBackup(name);
      final wallet = await LitecoinWalletBase.open(
        password: password,
        name: name,
        walletInfo: walletInfo,
        unspentCoinsInfo: unspentCoinsInfoSource,
        alwaysScan: alwaysScan,
        encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      );
      await wallet.init();
      return wallet;
    }
  }

  @override
  Future<void> remove(String wallet) async {
    File(await pathForWalletDir(name: wallet, type: getType())).delete(recursive: true);
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(wallet, getType()))!;
    await walletInfoSource.delete(walletInfo.key);

    // if there are no more litecoin wallets left, cleanup the neutrino db and other files created by mwebd:
    if (walletInfoSource.values.where((info) => info.type == WalletType.litecoin).isEmpty) {
      final appDirPath = (await getApplicationSupportDirectory()).path;
      File neturinoDb = File('$appDirPath/neutrino.db');
      File blockHeaders = File('$appDirPath/block_headers.bin');
      File regFilterHeaders = File('$appDirPath/reg_filter_headers.bin');
      File mwebdLogs = File('$appDirPath/logs/debug.log');
      if (neturinoDb.existsSync()) {
        neturinoDb.deleteSync();
      }
      if (blockHeaders.existsSync()) {
        blockHeaders.deleteSync();
      }
      if (regFilterHeaders.existsSync()) {
        regFilterHeaders.deleteSync();
      }
      if (mwebdLogs.existsSync()) {
        mwebdLogs.deleteSync();
      }
    }

    final unspentCoinsToDelete = unspentCoinsInfoSource.values
        .where((unspentCoin) => unspentCoin.walletId == walletInfo.id)
        .toList();

    final keysToDelete = unspentCoinsToDelete.map((unspentCoin) => unspentCoin.key).toList();

    if (keysToDelete.isNotEmpty) {
      await unspentCoinsInfoSource.deleteAll(keysToDelete);
    }
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    final currentWalletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(currentName, getType()))!;
    final currentWallet = await LitecoinWalletBase.open(
      password: password,
      name: currentName,
      walletInfo: currentWalletInfo,
      unspentCoinsInfo: unspentCoinsInfoSource,
      alwaysScan: alwaysScan,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );

    await currentWallet.renameWalletFiles(newName);
    await saveBackup(newName);

    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<LitecoinWallet> restoreFromHardwareWallet(BitcoinRestoreWalletFromHardware credentials,
      {bool? isTestnet}) async {
    final network = isTestnet == true ? LitecoinNetwork.testnet : LitecoinNetwork.mainnet;
    credentials.walletInfo?.network = network.value;
    credentials.walletInfo?.derivationInfo?.derivationPath =
        credentials.hwAccountData.derivationPath;

    final hdWallets = await ElectrumWalletBase.getAccountHDWallets(
      walletInfo: credentials.walletInfo!,
      network: network,
      xpub: credentials.hwAccountData.xpub,
    );

    final wallet = await LitecoinWallet(
      password: credentials.password!,
      xpub: credentials.hwAccountData.xpub,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      hdWallets: hdWallets,
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }

  @override
  Future<LitecoinWallet> restoreFromKeys(BitcoinRestoreWalletFromWIFCredentials credentials,
          {bool? isTestnet}) async =>
      throw UnimplementedError();

  @override
  Future<LitecoinWallet> restoreFromSeed(BitcoinRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    if (!validateMnemonic(credentials.mnemonic) && !bip39.validateMnemonic(credentials.mnemonic)) {
      throw LitecoinMnemonicIsIncorrectException();
    }

    final wallet = await LitecoinWalletBase.create(
      password: credentials.password!,
      passphrase: credentials.passphrase,
      mnemonic: credentials.mnemonic,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }
}
