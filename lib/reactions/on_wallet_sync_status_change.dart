import 'package:cake_wallet/di.dart';
import 'package:cake_wallet/entities/update_haven_rate.dart';
import 'package:cake_wallet/entities/wake_lock.dart';
import 'package:cake_wallet/store/settings_store.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/sync_status.dart';

ReactionDisposer? _onWalletSyncStatusChangeReaction;

void startWalletSyncStatusChangeReaction(WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet,
    FiatConversionStore fiatConversionStore, SettingsStore settingsStore) {
  final _wakeLock = getIt.get<WakeLock>();
  _onWalletSyncStatusChangeReaction?.reaction.dispose();
  _onWalletSyncStatusChangeReaction =
      reaction((_) => wallet.syncStatus, (SyncStatus status) async {
    try {
      if (status is ConnectedSyncStatus) {
        await wallet.startSync();

        if (wallet.type == WalletType.haven) {
          await updateHavenRate(fiatConversionStore);
        }
      }
      if (status is SyncingSyncStatus) {
        await _wakeLock.enableWake();
      }
      if (status is SyncedSyncStatus || status is FailedSyncStatus) {
        await _wakeLock.disableWake();
      }
    } catch(e) {
      print(e.toString());
    }

    if (status is SyncedSyncStatus) {
      wallet.feeEstimate.update(priority: settingsStore.priority[wallet.type]!);
    }
  });
}
