abstract class SyncStatus {
  const SyncStatus();
  double progress();
}

class StartingScanSyncStatus extends SyncStatus {
  StartingScanSyncStatus(this.beginHeight);

  final int beginHeight;
  @override
  double progress() => 0.0;
}

class SyncingSyncStatus extends SyncStatus {
  SyncingSyncStatus(this.blocksLeft, this.ptc);

  final double ptc;
  final int blocksLeft;

  @override
  double progress() => ptc;

  @override
  String toString() => '$blocksLeft';

  factory SyncingSyncStatus.fromHeightValues(int chainTip, int initialSyncHeight, int syncHeight) {
    final track = chainTip - initialSyncHeight;
    final diff = track - (chainTip - syncHeight);
    final ptc = diff <= 0 ? 0.0 : diff / track;
    final left = chainTip - syncHeight;

    // sum 1 because if at the chain tip, will say "0 blocks left"
    return SyncingSyncStatus(left + 1, ptc);
  }
}

class SyncedSyncStatus extends SyncStatus {
  @override
  double progress() => 1.0;
}

class SyncedTipSyncStatus extends SyncedSyncStatus {
  SyncedTipSyncStatus(this.tip);

  final int tip;
}

class SynchronizingSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class NotConnectedSyncStatus extends SyncStatus {
  const NotConnectedSyncStatus();

  @override
  double progress() => 0.0;
}

class AttemptingSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class AttemptingScanSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class FailedSyncStatus extends NotConnectedSyncStatus {
  String? error;
  FailedSyncStatus({this.error});

  @override
  String toString() => error ?? super.toString();
}

class ConnectingSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class ConnectedSyncStatus extends SyncStatus {
  @override
  double progress() => 0.0;
}

class UnsupportedSyncStatus extends NotConnectedSyncStatus {}

class TimedOutSyncStatus extends NotConnectedSyncStatus {
  @override
  String toString() => 'Timed out';
}

class LostConnectionSyncStatus extends NotConnectedSyncStatus {
  @override
  String toString() => 'Reconnecting';
}

Map<String, dynamic> syncStatusToJson(SyncStatus? status) {
  if (status == null) {
    return {};
  }

  return {
    'progress': status.progress(),
    'type': status.runtimeType.toString(),
    'data': status is SyncingSyncStatus
        ? {'blocksLeft': status.blocksLeft, 'ptc': status.ptc}
        : status is SyncedTipSyncStatus
            ? {'tip': status.tip}
            : status is FailedSyncStatus
                ? {'error': status.error}
                : status is StartingScanSyncStatus
                    ? {'beginHeight': status.beginHeight}
                    : null
  };
}

SyncStatus syncStatusFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  final data = json['data'] as Map<String, dynamic>?;

  switch (type) {
    case 'StartingScanSyncStatus':
      return StartingScanSyncStatus(data!['beginHeight'] as int);
    case 'SyncingSyncStatus':
      return SyncingSyncStatus(data!['blocksLeft'] as int, data['ptc'] as double);
    case 'SyncedTipSyncStatus':
      return SyncedTipSyncStatus(data!['tip'] as int);
    case 'SyncedSyncStatus':
      return SyncedSyncStatus();
    case 'FailedSyncStatus':
      return FailedSyncStatus(error: data!['error'] as String?);
    case 'SynchronizingSyncStatus':
      return SynchronizingSyncStatus();
    case 'NotConnectedSyncStatus':
      return NotConnectedSyncStatus();
    case 'AttemptingSyncStatus':
      return AttemptingSyncStatus();
    case 'AttemptingScanSyncStatus':
      return AttemptingScanSyncStatus();
    case 'ConnectedSyncStatus':
      return ConnectedSyncStatus();
    case 'ConnectingSyncStatus':
      return ConnectingSyncStatus();
    case 'UnsupportedSyncStatus':
      return UnsupportedSyncStatus();
    case 'TimedOutSyncStatus':
      return TimedOutSyncStatus();
    case 'LostConnectionSyncStatus':
      return LostConnectionSyncStatus();
    default:
      throw Exception('Unknown sync status type: $type');
  }
}
