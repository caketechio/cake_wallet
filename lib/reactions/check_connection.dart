import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cake_wallet/store/settings_store.dart';

Timer? _checkConnectionTimer;

void startCheckConnectionReaction(WalletBase wallet, SettingsStore settingsStore,
    {int timeInterval = 5}) {
  _checkConnectionTimer?.cancel();
  // TODO: check the validity of this code, and if it's working fine, then no need for
  // having the connect function in electrum.dart when the syncstatus is lost or failed and add the not connected state
  _checkConnectionTimer = Timer.periodic(Duration(seconds: timeInterval), (_) async {
    if (wallet.type == WalletType.bitcoin && wallet.syncStatus is SyncingSyncStatus) {
      return;
    }
    if (wallet.type == WalletType.decred && wallet.syncStatus is ProcessingSyncStatus) {
      return;
    }

    try {
      final connectivityResult = await (Connectivity().checkConnectivity());

      if (connectivityResult == ConnectivityResult.none) {
        wallet.syncStatus = FailedSyncStatus();
        return;
      }

      if (wallet.type != WalletType.bitcoin &&
          (wallet.syncStatus is LostConnectionSyncStatus ||
              wallet.syncStatus is FailedSyncStatus)) {
        final alive = await settingsStore.getCurrentNode(wallet.type).requestNode();

        if (alive) {
          await wallet.connectToNode(node: settingsStore.getCurrentNode(wallet.type));
        }
      }
    } catch (e) {
      printV(e.toString());
    }
  });
}
