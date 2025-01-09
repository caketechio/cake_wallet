import 'dart:io';

import 'package:cake_wallet/core/wallet_loading_service.dart';
import 'package:cake_wallet/entities/preferences_key.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/utils/device_info.dart';
import 'package:cake_wallet/utils/feature_flag.dart';
import 'package:cake_wallet/utils/tor.dart';
import 'package:cake_wallet/view_model/settings/sync_mode.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_item.dart';
import 'package:cake_wallet/view_model/wallet_list/wallet_list_view_model.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cake_wallet/main.dart';
import 'package:cake_wallet/di.dart';

const moneroSyncTaskKey = "com.fotolockr.cakewallet.monero_sync_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      switch (task) {
        case moneroSyncTaskKey:

          /// The work manager runs on a separate isolate from the main flutter isolate.
          /// thus we initialize app configs first; hive, getIt, etc...
          await initializeAppConfigs();

          final walletLoadingService = getIt.get<WalletLoadingService>();

          final typeRaw = getIt.get<SharedPreferences>().getInt(PreferencesKey.currentWalletType);

          WalletBase? wallet;

          if (inputData!['sync_all'] as bool) {
            /// get all Monero wallets of the user and sync them
            final List<WalletListItem> moneroWallets = getIt
                .get<WalletListViewModel>()
                .wallets
                .where((element) => [WalletType.monero, WalletType.wownero].contains(element.type))
                .toList();

            for (int i = 0; i < moneroWallets.length; i++) {
              wallet =
                  await walletLoadingService.load(moneroWallets[i].type, moneroWallets[i].name);
              final node = getIt.get<SettingsStore>().getCurrentNode(moneroWallets[i].type);
              final settingsStore = getIt.get<SettingsStore>();
              if (settingsStore.builtinTor) {
                await ensureTorStarted(context: null);
              }
              await wallet.connectToNode(node: node);
              await wallet.startSync();
            }
          } else {
            /// if the user chose to sync only active wallet
            /// if the current wallet is monero; sync it only
            if (typeRaw == WalletType.monero.index || typeRaw == WalletType.wownero.index) {
              final name =
                  getIt.get<SharedPreferences>().getString(PreferencesKey.currentWalletName);

              wallet = await walletLoadingService.load(WalletType.values[typeRaw!], name!);
              final node = getIt.get<SettingsStore>().getCurrentNode(WalletType.values[typeRaw]);
              final settingsStore = getIt.get<SettingsStore>();
              if (settingsStore.builtinTor) {
                await ensureTorStarted(context: null);
              }
      
              await wallet.connectToNode(node: node);
              await wallet.startSync();
            }
          }

          if (wallet?.syncStatus.progress() == null) {
            return Future.error("No Monero/Wownero wallet found");
          }

          for (int i = 0;; i++) {
            await Future<void>.delayed(const Duration(seconds: 1));
            if (wallet?.syncStatus.progress() == 1.0) {
              break;
            }
            if (i > 600) {
              return Future.error("Synchronization Timed out");
            }
          }
          break;
      }

      return Future.value(true);
    } catch (error, stackTrace) {
      printV(error);
      printV(stackTrace);
      return Future.error(error);
    }
  });
}

class BackgroundTasks {
  void registerSyncTask({bool changeExisting = false}) async {
    try {
      bool hasMonero = getIt
          .get<WalletListViewModel>()
          .wallets
          .any((element) => element.type == WalletType.monero);

      /// if its not android nor ios, or the user has no monero wallets; exit
      if (!DeviceInfo.instance.isMobile || !hasMonero) {
        return;
      }

      final settingsStore = getIt.get<SettingsStore>();

      final SyncMode syncMode = settingsStore.currentSyncMode;
      final bool syncAll = settingsStore.currentSyncAll;

      if (syncMode.type == SyncType.disabled || !FeatureFlag.isBackgroundSyncEnabled) {
        cancelSyncTask();
        return;
      }

      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );

      final inputData = <String, dynamic>{"sync_all": syncAll};
      final constraints = Constraints(
        networkType:
            syncMode.type == SyncType.unobtrusive ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: syncMode.type == SyncType.unobtrusive,
        requiresCharging: syncMode.type == SyncType.unobtrusive,
        requiresDeviceIdle: syncMode.type == SyncType.unobtrusive,
      );

      if (Platform.isIOS) {
        await Workmanager().registerOneOffTask(
          moneroSyncTaskKey,
          moneroSyncTaskKey,
          initialDelay: syncMode.frequency,
          existingWorkPolicy: ExistingWorkPolicy.replace,
          inputData: inputData,
          constraints: constraints,
        );
        return;
      }

      await Workmanager().registerPeriodicTask(
        moneroSyncTaskKey,
        moneroSyncTaskKey,
        initialDelay: syncMode.frequency,
        frequency: syncMode.frequency,
        existingWorkPolicy: changeExisting ? ExistingWorkPolicy.replace : ExistingWorkPolicy.keep,
        inputData: inputData,
        constraints: constraints,
      );
    } catch (error, stackTrace) {
      printV(error);
      printV(stackTrace);
    }
  }

  void cancelSyncTask() {
    try {
      Workmanager().cancelByUniqueName(moneroSyncTaskKey);
    } catch (error, stackTrace) {
      printV(error);
      printV(stackTrace);
    }
  }
}
