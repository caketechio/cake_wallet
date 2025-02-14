import 'dart:io';
import 'package:cw_core/root_dir.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:path_provider/path_provider.dart';

Future<String> pathForWalletDir({required String name, required  WalletType type}) async {
  final root = await getAppDir();
  final prefix = walletTypeToString(type).toLowerCase();
  final walletsDir = Directory('${root.path}/wallets');
  final walletDire = Directory('${walletsDir.path}/$prefix/$name');

  if (!walletDire.existsSync()) {
    walletDire.createSync(recursive: true);
  }

  return walletDire.path;
}

Future<bool> walletsDirExists() async {
  final root = await getAppDir();
  final walletsDir = Directory('${root.path}/wallets');
  return walletsDir.existsSync();
}

Future<String> pathForWallet({required String name, required WalletType type}) async =>
    await pathForWalletDir(name: name, type: type)
        .then((path) => path + '/$name');

Future<String> outdatedAndroidPathForWalletDir({required String name}) async {
  final directory = await getAppDir();
  final pathDir = directory.path + '/$name';

  return pathDir;
}
