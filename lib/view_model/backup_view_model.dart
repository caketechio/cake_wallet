import 'dart:io';
import 'package:cake_wallet/core/backup_service.dart';
import 'package:cake_wallet/core/execution_state.dart';
import 'package:cake_wallet/entities/secret_store_key.dart';
import 'package:cake_wallet/store/secret_store.dart';
import 'package:cw_core/root_dir.dart';
import 'package:flutter/foundation.dart';
import 'package:cake_wallet/core/secure_storage.dart';
import 'package:mobx/mobx.dart';
import 'package:intl/intl.dart';
import 'package:cake_wallet/wallet_type_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cake_wallet/core/flatpak.dart';

part 'backup_view_model.g.dart';

class BackupExportFile {
  BackupExportFile(this.content, {required this.name});

  final String name;
  final List<int> content;
}

class BackupViewModel = BackupViewModelBase with _$BackupViewModel;

abstract class BackupViewModelBase with Store {
  BackupViewModelBase(this.secureStorage, this.secretStore, this.backupService)
      : isBackupPasswordVisible = false,
        backupPassword = '',
        state = InitialExecutionState() {
    final key = generateStoreKeyFor(key: SecretStoreKey.backupPassword);
    secretStore.values.observe((change) {
      if (change.key == key) {
        backupPassword = secretStore.read(key);
      }
    }, fireImmediately: true);
  }

  final SecureStorage secureStorage;
  final SecretStore secretStore;
  final BackupService backupService;

  @observable
  ExecutionState state;

  @observable
  bool isBackupPasswordVisible;

  @observable
  String backupPassword;

  @action
  Future<void> init() async {
    final key = generateStoreKeyFor(key: SecretStoreKey.backupPassword);
    backupPassword = (await secureStorage.read(key: key))!;
  }

  @action
  Future<BackupExportFile?> exportBackup() async {
    try {
      state = IsExecutingState();
      final backupContent = await backupService.exportBackup(backupPassword);
      state = ExecutedSuccessfullyState();
      final now = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd_Hm');
      final snakeAppName = approximatedAppName.replaceAll(' ', '_').toLowerCase();
      final fileName = '${snakeAppName}_backup_${formatter.format(now)}';

      return BackupExportFile(backupContent.toList(), name: fileName);
    } catch (e) {
      print(e.toString());
      state = FailureState(e.toString());
      return null;
    }
  }

  Future<String> saveBackupFileLocally(BackupExportFile backup) async {
    final appDir = await getAppDir(isFlatpak: isFlatpak);
    final path = '${appDir.path}/${backup.name}';
    final backupFile = File(path);
    await backupFile.writeAsBytes(backup.content);
    return path;
  }

  Future<void> removeBackupFileLocally(BackupExportFile backup) async {
    final appDir = await getAppDir(isFlatpak: isFlatpak);
    final path = '${appDir.path}/${backup.name}';
    final backupFile = File(path);
    await backupFile.delete();
  }

  @action
  void showMasterPassword() => isBackupPasswordVisible = true;

  @action
  Future<void> saveToDownload(String name, List<int> content) async {
    const downloadDirPath = '/storage/emulated/0/Download'; // For Android
    final filePath = '$downloadDirPath/${name}';
    final file = File(filePath);
    await file.writeAsBytes(content);
  }
}
