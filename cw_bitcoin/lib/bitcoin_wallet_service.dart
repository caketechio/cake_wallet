import 'dart:io';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/bitcoin_mnemonic.dart';
import 'package:cw_bitcoin/bitcoin_mnemonics_bip39.dart';
import 'package:cw_bitcoin/mnemonic_is_incorrect_exception.dart';
import 'package:cw_bitcoin/bitcoin_wallet_creation_credentials.dart';
import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:cw_core/payjoin_session.dart';
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
  BitcoinWalletService(this.walletInfoSource, this.unspentCoinsInfoSource,
      this.payjoinSessionSource, this.alwaysScan, this.isDirect);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final Box<PayjoinSession> payjoinSessionSource;
  final bool alwaysScan;
  final bool isDirect;

  @override
  WalletType getType() => WalletType.bitcoin;

  @override
  Future<BitcoinWallet> create(BitcoinNewWalletCredentials credentials, {bool? isTestnet}) async {
    final network = isTestnet == true ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
    credentials.walletInfo?.network = network.value;

    final String mnemonic;
    switch ( credentials.walletInfo?.derivationInfo?.derivationType) {
      case DerivationType.bip39:
        final strength = credentials.seedPhraseLength == 24 ? 256 : 128;

        mnemonic = credentials.mnemonic ?? await MnemonicBip39.generate(strength: strength);
        break;
      case DerivationType.electrum:
      default:
        mnemonic = await generateElectrumMnemonic();
        break;
    }

    final wallet = await BitcoinWalletBase.create(
      mnemonic: mnemonic,
      password: credentials.password!,
      passphrase: credentials.passphrase,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      payjoinBox: payjoinSessionSource,
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
        payjoinBox: payjoinSessionSource,
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
        payjoinBox: payjoinSessionSource,
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

    final unspentCoinsToDelete = unspentCoinsInfoSource.values.where(
          (unspentCoin) => unspentCoin.walletId == walletInfo.id).toList();

    final keysToDelete = unspentCoinsToDelete.map((unspentCoin) => unspentCoin.key).toList();

    if (keysToDelete.isNotEmpty) {
      await unspentCoinsInfoSource.deleteAll(keysToDelete);
    }
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
      payjoinBox: payjoinSessionSource,
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

    final payjoinBox = await CakeHive.openBox<PayjoinSession>(PayjoinSession.boxName);

    final wallet = await BitcoinWallet(
      password: credentials.password!,
      xpub: credentials.hwAccountData.xpub,
      walletInfo: credentials.walletInfo!,
      unspentCoinsInfo: unspentCoinsInfoSource,
      networkParam: network,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
        payjoinBox: payjoinBox,
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
    if (!validateMnemonic(credentials.mnemonic) && !bip39.validateMnemonic(credentials.mnemonic)) {
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
      payjoinBox: payjoinSessionSource,
      network: network,
      encryptionFileUtils: encryptionFileUtilsFor(isDirect),
    );
    await wallet.save();
    await wallet.init();
    return wallet;
  }
}
