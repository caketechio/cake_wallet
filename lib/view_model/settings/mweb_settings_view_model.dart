import 'dart:io';

import 'package:cake_wallet/bitcoin/bitcoin.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/exception_handler.dart';
import 'package:cw_core/root_dir.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:flutter/widgets.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';

part 'mweb_settings_view_model.g.dart';

class MwebSettingsViewModel = MwebSettingsViewModelBase with _$MwebSettingsViewModel;

abstract class MwebSettingsViewModelBase with Store {
  MwebSettingsViewModelBase(this._settingsStore, this._wallet) {
    mwebEnabled = bitcoin!.getMwebEnabled(_wallet);
    _settingsStore.mwebAlwaysScan = mwebEnabled;
  }

  final SettingsStore _settingsStore;
  final WalletBase _wallet;

  @computed
  bool get mwebCardDisplay => _settingsStore.mwebCardDisplay;

  @observable
  late bool mwebEnabled;

  @computed
  String get mwebNodeUri => _settingsStore.mwebNodeUri;

  @action
  void setMwebCardDisplay(bool value) {
    _settingsStore.mwebCardDisplay = value;
  }

  @action
  void setMwebNodeUri(String value) {
    _settingsStore.mwebNodeUri = value;
  }

  @action
  void setMwebEnabled(bool value) {
    mwebEnabled = value;
    bitcoin!.setMwebEnabled(_wallet, value);
    _settingsStore.mwebAlwaysScan = value;
  }

  Future<String> getAbbreviatedLogs() async {
    final appSupportPath = (await getApplicationSupportDirectory()).path;
    final logsFile = File("$appSupportPath/logs/debug.log");
    if (!logsFile.existsSync()) {
      return "";
    }
    final logs = logsFile.readAsStringSync();
    // return last 10000 characters:
    return logs.substring(logs.length > 10000 ? logs.length - 10000 : 0);
  }

  Future<void> removeLogsLocally(String filePath) async {
    final logsFile = File(filePath);
    if (logsFile.existsSync()) {
      await logsFile.delete();
    }
  }
}
