import 'dart:io';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/mnemonic_is_incorrect_exception.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_bitcoin/bitcoin_wallet.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:bip39/bip39.dart' as bip39;

class BitcoinWalletService extends WalletService<
    BitcoinNewWalletCredentials,
    BitcoinRestoreWalletFromSeedCredentials,
    BitcoinRestoreWalletFromWIFCredentials,
    BitcoinRestoreWalletFromHardware> {
  BitcoinWalletService(this.walletInfoSource, this.unspentCoinsInfoSource, this.alwaysScan, this.isDirect);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool alwaysScan;
  final bool isDirect;

  @override
  WalletType getType() => WalletType.bitcoin;

  @override
  Future<BitcoinWallet> create(BitcoinNewWalletCredentials credentials, {bool? isTestnet}) async {
    final network = isTestnet == true ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    credentials.walletInfo?.network = network.value;

    final wallet = await BitcoinWalletBase.create(
      mnemonic: await generateElectrumMnemonic(),
      password: credentials.password!,
      passphrase: credentials.passphrase,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      network: network,
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
  Future<BitcoinWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(name, getType()))!;
    try {
      final wallet = await BitcoinWalletBase.open(
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
      final wallet = await BitcoinWalletBase.open(
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
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    final currentWalletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(currentName, getType()))!;
    final currentWallet = await BitcoinWalletBase.open(
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
  Future<BitcoinWallet> restoreFromHardwareWallet(BitcoinRestoreWalletFromHardware credentials,
      {bool? isTestnet}) async {
    final network = isTestnet == true ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    credentials.walletInfo?.network = network.value;
    credentials.walletInfo?.derivationInfo?.derivationPath =
        credentials.hwAccountData.derivationPath;

    final wallet = await BitcoinWallet(
      password: credentials.password!,
      xpub: credentials.hwAccountData.xpub,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      networkParam: network,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }

  @override
  Future<BitcoinWallet> restoreFromKeys(BitcoinRestoreWalletFromWIFCredentials credentials,
          {bool? isTestnet}) async =>
      throw UnimplementedError();

  @override
  Future<BitcoinWallet> restoreFromSeed(BitcoinRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    if (!validateElectrumMnemonic(credentials.mnemonic) && !bip39.validateMnemonic(credentials.mnemonic)) {
      throw BitcoinMnemonicIsIncorrectException();
    }

    final network = isTestnet == true ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    credentials.walletInfo?.network = network.value;

    final wallet = await BitcoinWalletBase.create(
      password: credentials.password!,
      passphrase: credentials.passphrase,
      mnemonic: credentials.mnemonic,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      network: network,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }
}
