import 'dart:io';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:hive/hive.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/mnemonic_is_incorrect_exception.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_bitcoin/litecoin_wallet.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:collection/collection.dart';
import 'package:bip39/bip39.dart' as bip39;

class LitecoinWalletService extends WalletService<
    BitcoinNewWalletCredentials,
    BitcoinRestoreWalletFromSeedCredentials,
    BitcoinRestoreWalletFromWIFCredentials,
    BitcoinNewWalletCredentials> {
  LitecoinWalletService(this.walletInfoSource, this.unspentCoinsInfoSource, this.isDirect);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final bool isDirect;

  @override
  WalletType getType() => WalletType.litecoin;

  @override
  Future<LitecoinWallet> create(BitcoinNewWalletCredentials credentials, {bool? isTestnet}) async {
    final wallet = await LitecoinWalletBase.create(
      mnemonic: await generateElectrumMnemonic(),
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
    final currentWallet = await LitecoinWalletBase.open(
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
  Future<LitecoinWallet> restoreFromHardwareWallet(BitcoinNewWalletCredentials credentials) {
    throw UnimplementedError(
        "Restoring a Litecoin wallet from a hardware wallet is not yet supported!");
  }

  @override
  Future<LitecoinWallet> restoreFromKeys(BitcoinRestoreWalletFromWIFCredentials credentials,
          {bool? isTestnet}) async =>
      throw UnimplementedError();

  @override
  Future<LitecoinWallet> restoreFromSeed(BitcoinRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    if (!validateElectrumMnemonic(credentials.mnemonic) && !bip39.validateMnemonic(credentials.mnemonic)) {
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
