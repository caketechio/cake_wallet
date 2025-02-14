import 'package:cake_wallet/generated/i18n.dart';
import 'package:cw_core/sync_status.dart';

String syncStatusTitle(SyncStatus syncStatus) {
  if (syncStatus is SyncingSyncStatus) {
    if (syncStatus.blocksLeft == 1) {
      return S.current.block_remaining;
    }

    String eta = syncStatus.getFormattedEta() ?? '';

    if (eta.isEmpty) {
      return S.current.Blocks_remaining('${syncStatus.blocksLeft}');
    } else {
      return "${syncStatus.formattedProgress()} - $eta";
    }
  }

  if (syncStatus is SyncedTipSyncStatus) {
    return S.current.silent_payments_scanned_tip(syncStatus.tip.toString());
  }

  if (syncStatus is SyncedSyncStatus) {
    return S.current.sync_status_syncronized;
  }

  if (syncStatus is FailedSyncStatus) {
    if (syncStatus.error != null) {
      return syncStatus.error!;
    }
    return S.current.sync_status_failed_connect;
  }

  if (syncStatus is NotConnectedSyncStatus) {
    return S.current.sync_status_not_connected;
  }

  if (syncStatus is AttemptingSyncStatus) {
    return S.current.sync_status_attempting_sync;
  }

  if (syncStatus is ConnectingSyncStatus) {
    return S.current.sync_status_connecting;
  }

  if (syncStatus is ConnectedSyncStatus) {
    return S.current.sync_status_connected;
  }

  if (syncStatus is LostConnectionSyncStatus) {
    return S.current.sync_status_failed_connect;
  }

  if (syncStatus is UnsupportedSyncStatus) {
    return S.current.sync_status_unsupported;
  }

  if (syncStatus is TimedOutSyncStatus) {
    return S.current.sync_status_timed_out;
  }

  if (syncStatus is SyncronizingSyncStatus) {
    return S.current.sync_status_syncronizing;
  }

  if (syncStatus is StartingScanSyncStatus) {
    return S.current.sync_status_starting_scan(syncStatus.beginHeight.toString());
  }

  if (syncStatus is AttemptingScanSyncStatus) {
    return S.current.sync_status_attempting_scan;
  }

  return '';
}
