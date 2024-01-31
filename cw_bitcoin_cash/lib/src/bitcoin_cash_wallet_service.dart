import 'dart:io';

import 'package:bip39/bip39.dart';
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

class BitcoinCashWalletService extends WalletService<BitcoinCashNewWalletCredentials,
    BitcoinCashRestoreWalletFromSeedCredentials, BitcoinCashRestoreWalletFromWIFCredentials> {
  BitcoinCashWalletService(
      this.walletInfoSource, this.unspentCoinsInfoSource, this.isDirect, this.isFlatpak);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool isDirect;
  final bool isFlatpak;

  @override
  WalletType getType() => WalletType.bitcoinCash;

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType(), isFlatpak: isFlatpak)).existsSync();

  @override
  Future<BitcoinCashWallet> create(credentials) async {
    final strength = (credentials.seedPhraseLength == 12)
        ? 128
        : (credentials.seedPhraseLength == 24)
            ? 256
            : 128;
    final wallet = await BitcoinCashWalletBase.create(
      mnemonic: await Mnemonic.generate(strength: strength),
      password: credentials.password!,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }

  @override
  Future<BitcoinCashWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(name, getType()))!;
    final wallet = await BitcoinCashWalletBase.open(
      password: password,
      name: name,
      walletInfo: walletInfo,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );
    await wallet.init();
    return wallet;
  }

  @override
  Future<void> remove(String wallet) async {
    File(await pathForWalletDir(name: wallet, type: getType(), isFlatpak: isFlatpak))
        .delete(recursive: true);
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
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );

    await currentWallet.renameWalletFiles(newName);

    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<BitcoinCashWallet> restoreFromKeys(credentials) {
    // TODO: implement restoreFromKeys
    throw UnimplementedError('restoreFromKeys() is not implemented');
  }

  @override
  Future<BitcoinCashWallet> restoreFromSeed(
      BitcoinCashRestoreWalletFromSeedCredentials credentials) async {
    if (!validateMnemonic(credentials.mnemonic)) {
      throw BitcoinCashMnemonicIsIncorrectException();
    }

    final wallet = await BitcoinCashWalletBase.create(
      password: credentials.password!,
      mnemonic: credentials.mnemonic,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }
}
