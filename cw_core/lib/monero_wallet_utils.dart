import 'dart:io';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_type.dart';

String backupFileName(String originalPath) {
  final pathParts = originalPath.split('/');
  final newName = '#_${pathParts.last}';
  pathParts.removeLast();
  pathParts.add(newName);
  return pathParts.join('/');
}

Future<void> backupWalletFiles(String name, bool isFlatpak) async {
  final path = await pathForWallet(name: name, type: WalletType.monero, isFlatpak: isFlatpak);
  final cacheFile = File(path);
  final keysFile = File('$path.keys');
  final addressListFile = File('$path.address.txt');
  final newCacheFilePath = backupFileName(cacheFile.path);
  final newKeysFilePath = backupFileName(keysFile.path);
  final newAddressListFilePath = backupFileName(addressListFile.path);

  if (cacheFile.existsSync()) {
    await cacheFile.copy(newCacheFilePath);
  }

  if (keysFile.existsSync()) {
    await keysFile.copy(newKeysFilePath);
  }

  if (addressListFile.existsSync()) {
    await addressListFile.copy(newAddressListFilePath);
  }
}

Future<void> restoreWalletFiles(String name, bool isFlatpak) async {
  final walletDirPath =
      await pathForWalletDir(name: name, type: WalletType.monero, isFlatpak: isFlatpak);
  final cacheFilePath = '$walletDirPath/$name';
  final keysFilePath = '$walletDirPath/$name.keys';
  final addressListFilePath = '$walletDirPath/$name.address.txt';
  final backupCacheFile = File(backupFileName(cacheFilePath));
  final backupKeysFile = File(backupFileName(keysFilePath));
  final backupAddressListFile = File(backupFileName(addressListFilePath));

  if (backupCacheFile.existsSync()) {
    await backupCacheFile.copy(cacheFilePath);
  }

  if (backupKeysFile.existsSync()) {
    await backupKeysFile.copy(keysFilePath);
  }

  if (backupAddressListFile.existsSync()) {
    await backupAddressListFile.copy(addressListFilePath);
  }
}

Future<bool> backupWalletFilesExists(String name, bool isFlatpak) async {
  final walletDirPath =
      await pathForWalletDir(name: name, type: WalletType.monero, isFlatpak: isFlatpak);
  final cacheFilePath = '$walletDirPath/$name';
  final keysFilePath = '$walletDirPath/$name.keys';
  final addressListFilePath = '$walletDirPath/$name.address.txt';
  final backupCacheFile = File(backupFileName(cacheFilePath));
  final backupKeysFile = File(backupFileName(keysFilePath));
  final backupAddressListFile = File(backupFileName(addressListFilePath));

  return backupCacheFile.existsSync() &&
      backupKeysFile.existsSync() &&
      backupAddressListFile.existsSync();
}

Future<void> removeCache(String name, bool isFlatpak) async {
  final path = await pathForWallet(name: name, type: WalletType.monero, isFlatpak: isFlatpak);
  final cacheFile = File(path);

  if (cacheFile.existsSync()) {
    cacheFile.deleteSync();
  }
}

Future<void> restoreOrResetWalletFiles(String name, bool isFlatpak) async {
  final backupsExists = await backupWalletFilesExists(name, isFlatpak);

  if (backupsExists) {
    await restoreWalletFiles(name, isFlatpak);
  }

  removeCache(name, isFlatpak);
}
