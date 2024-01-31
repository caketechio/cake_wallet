import 'dart:io';

import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_ethereum/ethereum_mnemonics.dart';
import 'package:cw_polygon/polygon_wallet.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:hive/hive.dart';
import 'polygon_wallet_creation_credentials.dart';
import 'package:collection/collection.dart';

class PolygonWalletService extends WalletService<PolygonNewWalletCredentials,
    PolygonRestoreWalletFromSeedCredentials, PolygonRestoreWalletFromPrivateKey> {
  PolygonWalletService(this.walletInfoSource, this.isDirect, this.isFlatpak);

  final Box<WalletInfo> walletInfoSource;
  final bool isDirect;
  final bool isFlatpak;

  @override
  Future<PolygonWallet> create(PolygonNewWalletCredentials credentials) async {
    final strength = credentials.seedPhraseLength == 24 ? 256 : 128;

    final mnemonic = bip39.generateMnemonic(strength: strength);
    final wallet = PolygonWallet(
      walletInfo: credentials.walletInfo!,
      mnemonic: mnemonic,
      password: credentials.password!,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );

    await wallet.init();
    wallet.addInitialTokens();
    await wallet.save();

    return wallet;
  }

  @override
  WalletType getType() => WalletType.polygon;

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType(), isFlatpak: isFlatpak)).existsSync();

  @override
  Future<PolygonWallet> openWallet(String name, String password) async {
    final walletInfo =
        walletInfoSource.values.firstWhere((info) => info.id == WalletBase.idFor(name, getType()));
    final wallet = await PolygonWalletBase.open(
      name: name,
      password: password,
      walletInfo: walletInfo,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );

    await wallet.init();
    await wallet.save();

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
  Future<PolygonWallet> restoreFromKeys(PolygonRestoreWalletFromPrivateKey credentials) async {
    final wallet = PolygonWallet(
      password: credentials.password!,
      privateKey: credentials.privateKey,
      walletInfo: credentials.walletInfo!,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );

    await wallet.init();
    wallet.addInitialTokens();
    await wallet.save();

    return wallet;
  }

  @override
  Future<PolygonWallet> restoreFromSeed(PolygonRestoreWalletFromSeedCredentials credentials) async {
    if (!bip39.validateMnemonic(credentials.mnemonic)) {
      throw EthereumMnemonicIsIncorrectException();
    }

    final wallet = PolygonWallet(
      password: credentials.password!,
      mnemonic: credentials.mnemonic,
      walletInfo: credentials.walletInfo!,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );

    await wallet.init();
    wallet.addInitialTokens();
    await wallet.save();

    return wallet;
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    final currentWalletInfo = walletInfoSource.values
        .firstWhere((info) => info.id == WalletBase.idFor(currentName, getType()));
    final currentWallet = await PolygonWalletBase.open(
      password: password,
      name: currentName,
      walletInfo: currentWalletInfo,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
      isFlatpak: isFlatpak,
    );

    await currentWallet.renameWalletFiles(newName);

    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }
}
