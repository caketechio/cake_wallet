import 'dart:io';
import 'dart:math';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/mnemonic_is_incorrect_exception.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_lightning/lightning_wallet.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:bip39/bip39.dart' as bip39;

class LightningWalletService extends WalletService<
    BitcoinNewWalletCredentials,
    BitcoinRestoreWalletFromSeedCredentials,
    BitcoinRestoreWalletFromWIFCredentials,
    BitcoinRestoreWalletFromHardware> {
  LightningWalletService(this.walletInfoSource, this.unspentCoinsInfoSource, this.isDirect);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool isDirect;

  @override
  WalletType getType() => WalletType.lightning;

  @override
  Future<LightningWallet> create(BitcoinNewWalletCredentials credentials, {bool? isTestnet}) async {
    final strength = credentials.seedPhraseLength == 24 ? 256 : 128;
    late String mnemonic;
    // keep generating bip39 mnemonics until it is NOT a valid electrum mnemonic
    do {
      mnemonic = bip39.generateMnemonic(strength: strength);
    } while (validateElectrumMnemonic(mnemonic));

    final wallet = await LightningWalletBase.create(
      mnemonic: mnemonic,
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
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<LightningWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(name, getType()))!;
    try {
      final wallet = await LightningWalletBase.open(
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
      final wallet = await LightningWalletBase.open(
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
  Future<LightningWallet> restoreFromHardwareWallet(BitcoinRestoreWalletFromHardware credentials,
      {bool? isTestnet}) {
    throw UnimplementedError(
        "Restoring a Lightning wallet from a hardware wallet is not yet supported!");
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
    final currentWallet = await LightningWalletBase.open(
      password: password,
      name: currentName,
      walletInfo: currentWalletInfo,
      unspentCoinsInfo: unspentCoinsInfoSource,
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
  Future<LightningWallet> restoreFromKeys(BitcoinRestoreWalletFromWIFCredentials credentials,
          {bool? isTestnet}) async =>
      throw UnimplementedError();

  @override
  Future<LightningWallet> restoreFromSeed(BitcoinRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    if (!bip39.validateMnemonic(credentials.mnemonic) &&
        !validateElectrumMnemonic(credentials.mnemonic)) {
      throw BitcoinMnemonicIsIncorrectException();
    }

    final network = isTestnet == true ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    credentials.walletInfo?.network = network.value;

    final wallet = await LightningWalletBase.create(
      password: credentials.password!,
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
