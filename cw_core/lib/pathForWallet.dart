import 'dart:io';
import 'package:cw_core/root_dir.dart';
import 'package:cw_core/wallet_type.dart';

Future<String> pathForWalletDir(
    {required String name, required WalletType type, required bool isFlatpak}) async {
  final root = await getAppDir(isFlatpak: isFlatpak);
  final prefix = walletTypeToString(type).toLowerCase();
  final walletsDir = Directory('${root.path}/wallets');
  final walletDire = Directory('${walletsDir.path}/$prefix/$name');

  if (!walletDire.existsSync()) {
    walletDire.createSync(recursive: true);
  }

  return walletDire.path;
}

Future<String> pathForWallet(
        {required String name, required WalletType type, required bool isFlatpak}) async =>
    await pathForWalletDir(name: name, type: type, isFlatpak: isFlatpak)
        .then((path) => path + '/$name');

Future<String> outdatedAndroidPathForWalletDir({required String name, required bool isFlatpak}) async {
  final directory = await getAppDir(isFlatpak: isFlatpak);
  final pathDir = directory.path + '/$name';

  return pathDir;
}
