import 'dart:convert';
import 'dart:io';
import 'package:cw_decred/api/libdcrwallet.dart';
import 'package:cw_decred/wallet_creation_credentials.dart';
import 'package:cw_decred/wallet.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:hive/hive.dart';
import 'package:collection/collection.dart';
import 'package:cw_core/unspent_coins_info.dart';

class DecredWalletService extends WalletService<
    DecredNewWalletCredentials,
    DecredRestoreWalletFromSeedCredentials,
    DecredRestoreWalletFromPubkeyCredentials,
    DecredRestoreWalletFromHardwareCredentials> {
  DecredWalletService(this.walletInfoSource, this.unspentCoinsInfoSource);

  final Box<WalletInfo> walletInfoSource;
  final Box<UnspentCoinsInfo> unspentCoinsInfoSource;
  final seedRestorePath = "m/44'/42'";
  static final seedRestorePathTestnet = "m/44'/1'";
  static final pubkeyRestorePath = "m/44'/42'/0'";
  static final pubkeyRestorePathTestnet = "m/44'/1'/0'";
  final mainnet = "mainnet";
  final testnet = "testnet";

  static void init() async {
    // Use the general path for all dcr wallets as the general log directory.
    // Individual wallet paths may be removed if the wallet is deleted.
    final dcrLogDir = await pathForWalletDir(name: '', type: WalletType.decred);
    initLibdcrwallet(dcrLogDir);
  }

  @override
  WalletType getType() => WalletType.decred;

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<DecredWallet> create(DecredNewWalletCredentials credentials, {bool? isTestnet}) async {
    final config = {
      "name": credentials.walletInfo!.name,
      "datadir": credentials.walletInfo!.dirPath,
      "pass": credentials.password!,
      "net": isTestnet == true ? testnet : mainnet,
      "unsyncedaddrs": true,
    };
    await createWalletAsync(jsonEncode(config));
    final di = DerivationInfo(
        derivationPath: isTestnet == true ? seedRestorePathTestnet : seedRestorePath);
    credentials.walletInfo!.derivationInfo = di;
    final wallet =
        DecredWallet(credentials.walletInfo!, credentials.password!, this.unspentCoinsInfoSource);
    await wallet.init();
    return wallet;
  }

  @override
  Future<DecredWallet> openWallet(String name, String password) async {
    final walletInfo = walletInfoSource.values
        .firstWhereOrNull((info) => info.id == WalletBase.idFor(name, getType()))!;
    final network = walletInfo.derivationInfo?.derivationPath == seedRestorePathTestnet ||
            walletInfo.derivationInfo?.derivationPath == pubkeyRestorePathTestnet
        ? testnet
        : mainnet;

    final walletDirExists = Directory(walletInfo.dirPath).existsSync();
    if (!walletDirExists) {
      walletInfo.dirPath = await pathForWalletDir(name: name, type: getType());
    }

    final config = {
      "name": walletInfo.name,
      "datadir": walletInfo.dirPath,
      "net": network,
      "unsyncedaddrs": true,
    };
    await loadWalletAsync(jsonEncode(config));
    final wallet = DecredWallet(walletInfo, password, this.unspentCoinsInfoSource);
    await wallet.init();
    return wallet;
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
    final network = currentWalletInfo.derivationInfo?.derivationPath == seedRestorePathTestnet ||
            currentWalletInfo.derivationInfo?.derivationPath == pubkeyRestorePathTestnet
        ? testnet
        : mainnet;
    final currentWallet = DecredWallet(currentWalletInfo, password, this.unspentCoinsInfoSource);

    await currentWallet.renameWalletFiles(newName);

    final newDirPath = await pathForWalletDir(name: newName, type: getType());
    final newWalletInfo = currentWalletInfo;
    newWalletInfo.id = WalletBase.idFor(newName, getType());
    newWalletInfo.name = newName;
    newWalletInfo.dirPath = newDirPath;
    newWalletInfo.network = network;

    await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<DecredWallet> restoreFromSeed(DecredRestoreWalletFromSeedCredentials credentials,
      {bool? isTestnet}) async {
    final config = {
      "name": credentials.walletInfo!.name,
      "datadir": credentials.walletInfo!.dirPath,
      "pass": credentials.password!,
      "mnemonic": credentials.mnemonic,
      "net": isTestnet == true ? testnet : mainnet,
      "unsyncedaddrs": true,
    };
    await createWalletAsync(jsonEncode(config));
    final di = DerivationInfo(
        derivationPath: isTestnet == true ? seedRestorePathTestnet : seedRestorePath);
    credentials.walletInfo!.derivationInfo = di;
    final wallet =
        DecredWallet(credentials.walletInfo!, credentials.password!, this.unspentCoinsInfoSource);
    await wallet.init();
    return wallet;
  }

  // restoreFromKeys only supports restoring a watch only wallet from an account
  // pubkey.
  @override
  Future<DecredWallet> restoreFromKeys(DecredRestoreWalletFromPubkeyCredentials credentials,
      {bool? isTestnet}) async {
    final config = {
      "name": credentials.walletInfo!.name,
      "datadir": credentials.walletInfo!.dirPath,
      "pubkey": credentials.pubkey,
      "net": isTestnet == true ? testnet : mainnet,
      "unsyncedaddrs": true,
    };
    createWatchOnlyWallet(jsonEncode(config));
    final di = DerivationInfo(
        derivationPath: isTestnet == true ? pubkeyRestorePathTestnet : pubkeyRestorePath);
    credentials.walletInfo!.derivationInfo = di;
    final wallet =
        DecredWallet(credentials.walletInfo!, credentials.password!, this.unspentCoinsInfoSource);
    await wallet.init();
    return wallet;
  }

  @override
  Future<DecredWallet> restoreFromHardwareWallet(
          DecredRestoreWalletFromHardwareCredentials credentials) async =>
      throw UnimplementedError();
}
