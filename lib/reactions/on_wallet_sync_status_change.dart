import 'package:cake_wallet/entities/update_haven_rate.dart';
import 'package:cake_wallet/store/dashboard/fiat_conversion_store.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/sync_status.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

ReactionDisposer? _onWalletSyncStatusChangeReaction;

void startWalletSyncStatusChangeReaction(
    WalletBase<Balance, TransactionHistoryBase<TransactionInfo>, TransactionInfo> wallet,
    FiatConversionStore fiatConversionStore) {
  _onWalletSyncStatusChangeReaction?.reaction.dispose();
  _onWalletSyncStatusChangeReaction = reaction((_) => wallet.syncStatus, (SyncStatus status) async {
    try {
      if (status is ConnectedSyncStatus) {
        await wallet.startSync();

        if (wallet.type == WalletType.haven) {
          await updateHavenRate(fiatConversionStore);
        }
      }
      if (status is SyncingSyncStatus || status is ProcessingSyncStatus) {
        await WakelockPlus.enable();
      }
      if (status is SyncedSyncStatus || status is FailedSyncStatus) {
        await WakelockPlus.disable();
      }
    } catch (e) {
      printV(e.toString());
    }
  });
}
