import 'dart:io';

import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_type.dart';

abstract class WalletService<N extends WalletCredentials, RFS extends WalletCredentials,
    RFK extends WalletCredentials, RFH extends WalletCredentials> {
  WalletType getType();

  Future<WalletBase> create(N credentials);

  Future<WalletBase> restoreFromHardwareWallet(RFH credentials);

  Future<WalletBase> restoreFromSeed(RFS credentials);

  Future<WalletBase> restoreFromKeys(RFK credentials);

  Future<WalletBase> openWallet(String name, String password);

  Future<bool> isWalletExit(String name);

  Future<void> remove(String wallet);

  Future<void> rename(String currentName, String password, String newName);

  Future<void> restoreWalletFilesFromBackup(String name) async {
    final backupWalletDirPath = await pathForWalletDir(name: "$name.backup", type: getType());
    final walletDirPath = await pathForWalletDir(name: name, type: getType());

    if (File(backupWalletDirPath).existsSync()) {
      await File(backupWalletDirPath).copy(walletDirPath);
    }
  }

  Future<void> saveBackup(String name) async {
    final backupWalletDirPath = await pathForWalletDir(name: "$name.backup", type: getType());
    final walletDirPath = await pathForWalletDir(name: name, type: getType());

    if (File(walletDirPath).existsSync()) {
      await File(walletDirPath).copy(backupWalletDirPath);
    }
  }
}
