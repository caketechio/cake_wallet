import 'dart:io';
import 'package:path_provider/path_provider.dart';

String? _rootDirPath;

void setRootDirFromEnv() => _rootDirPath = Platform.environment['CAKE_WALLET_DIR'];

Future<Directory> getAppDir({String appName = 'cake_wallet', required bool isFlatpak}) async {
  Directory dir;

  if (_rootDirPath != null && _rootDirPath!.isNotEmpty) {
    dir = Directory.fromUri(Uri.file(_rootDirPath!));
    dir.create(recursive: true);
  } else {
    if (Platform.isLinux) {
      String appDirPath = '';

      if (isFlatpak) {
        appDirPath =
            '/home/${Platform.environment['USER']}/.var/app/com.cakewallet.CakeWallet/data/.$appName';
      } else {
        final homePath = '/home/${Platform.environment['USER']}/.$appName';

        if (await Directory(homePath).exists()) {
          appDirPath = homePath;
        } else {
          final docPath = await getApplicationDocumentsDirectory();

          if (await docPath.exists()) {
            appDirPath = docPath.path;
          }
        }
      }

      dir = Directory.fromUri(Uri.file(appDirPath));
      await dir.create(recursive: true);
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
  }

  return dir;
}
