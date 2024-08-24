import 'dart:io';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cw_bitcoin_cash/cw_bitcoin_cash.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:collection/collection.dart';
import 'package:hive/hive.dart';

class BitcoinCashWalletService extends WalletService<
    BitcoinCashNewWalletCredentials,
    BitcoinCashRestoreWalletFromSeedCredentials,
    BitcoinCashRestoreWalletFromWIFCredentials,
    BitcoinCashNewWalletCredentials> {
  BitcoinCashWalletService(this.walletInfoSource, this.unspentCoinsInfoSource, this.isDirect);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool isDirect;

  @override
  WalletType getType() => WalletType.bitcoinCash;

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<BitcoinCashWallet> create(credentials, {bool? isTestnet}) async {
    final strength = credentials.seedPhraseLength == 24 ? 256 : 128;

    final wallet = await BitcoinCashWalletBase.create(
        mnemonic: await MnemonicBip39.generate(strength: strength),
      password: credentials.password!,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );
    await wallet.save();
    await wallet.init();

    return wallet;
  }

  @override
  Future<BitcoinCashWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(name, getType()))!;

    try {
      final wallet = await BitcoinCashWalletBase.open(
          password: password,
          name: name,
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfoSource,
          encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      );
      await wallet.init();
      saveBackup(name);
      return wallet;
    } catch (_) {
      await restoreWalletFilesFromBackup(name);
      final wallet = await BitcoinCashWalletBase.open(
          password: password,
          name: name,
          walletInfo: walletInfo,
          unspentCoinsInfo: unspentCoinsInfoSource,
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
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    final currentWalletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(currentName, getType()))!;
    final currentWallet = await BitcoinCashWalletBase.open(
        password: password,
        name: currentName,
        walletInfo: currentWalletInfo,
        unspentCoinsInfo: unspentCoinsInfoSource,
        encryptionFileUtils: encryptionFileUtilsFor(isDirect));

    await currentWallet.renameWalletFiles(newName);
    await saveBackup(newName);

    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<BitcoinCashWallet> restoreFromHardwareWallet(BitcoinCashNewWalletCredentials credentials) {
    throw UnimplementedError(
        "Restoring a Bitcoin Cash wallet from a hardware wallet is not yet supported!");
  }

  @override
  Future<BitcoinCashWallet> restoreFromKeys(credentials, {bool? isTestnet}) {
    // TODO: implement restoreFromKeys
    throw UnimplementedError('restoreFromKeys() is not implemented');
  }

  @override
  Future<BitcoinCashWallet> restoreFromSeed(BitcoinCashRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    if (!bip39.validateMnemonic(credentials.mnemonic)) {
      throw BitcoinCashMnemonicIsIncorrectException();
    }

    final wallet = await BitcoinCashWalletBase.create(
        password: credentials.password!,
        mnemonic: credentials.mnemonic,
        walletInfo: credentials.walletInfo!,
        unspentCoinsInfo: unspentCoinsInfoSource,
        encryptionFileUtils: encryptionFileUtilsFor(isDirect));
    await wallet.save();
    await wallet.init();
    return wallet;
  }
}
