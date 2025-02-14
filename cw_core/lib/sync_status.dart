abstract class SyncStatus {
  const SyncStatus();
  double progress();

  String formattedProgress() {
    return "${(progress() * 100).toStringAsFixed(2)}%";
  }
}

class StartingScanSyncStatus extends SyncStatus {
  StartingScanSyncStatus(this.beginHeight);

  final int beginHeight;
  @override
  double progress() => 0.0;
}

class SyncingSyncStatus extends SyncStatus {
  SyncingSyncStatus(this.blocksLeft, this.ptc) {
    updateEtaHistory(blocksLeft);
  }

  double ptc;
  int blocksLeft;

  @override
  double progress() => ptc;

  @override
  String toString() => '$blocksLeft';

  factory SyncingSyncStatus.fromHeightValues(int chainTip, int initialSyncHeight, int syncHeight) {
    final track = chainTip - initialSyncHeight;
    final diff = track - (chainTip - syncHeight);
    final ptc = diff <= 0 ? 0.0 : diff / track;
    final left = chainTip - syncHeight;
    updateEtaHistory(left + 1);

    // sum 1 because if at the chain tip, will say "0 blocks left"
    return SyncingSyncStatus(left + 1, ptc);
  }

  static void updateEtaHistory(int blocksLeft) {
    blockHistory[DateTime.now()] = blocksLeft;
    // keep only the last 25 entries
    while (blockHistory.length > 25) {
      blockHistory.remove(blockHistory.keys.first);
    }
  }

  static Map<DateTime, int> blockHistory = {};
  static Duration? lastEtaDuration;

  DateTime calculateEta() {
    double rate = _calculateBlockRate();
    if (rate == 0) {
      return DateTime.now().add(const Duration(days: 2));
    }
    int remainingBlocks = this.blocksLeft;
    double timeRemainingSeconds = remainingBlocks / rate;
    return DateTime.now().add(Duration(seconds: timeRemainingSeconds.round()));
  }

  Duration getEtaDuration() {
    DateTime now = DateTime.now();
    DateTime? completionTime = calculateEta();
    return completionTime.difference(now);
  }

  String? getFormattedEta() {
    // throw out any entries that are more than a minute old:
    blockHistory.removeWhere(
        (key, value) => key.isBefore(DateTime.now().subtract(const Duration(minutes: 1))));

    // don't show eta if we don't have enough data:
    if (blockHistory.length < 3) {
      return null;
    }

    Duration? duration = getEtaDuration();

    // just show the block count if it's really long:
    if (duration.inDays > 0) {
      return null;
    }

    // show the blocks count if the eta is less than a minute or we only have a few blocks left:
    if (duration.inMinutes < 1 || blocksLeft < 1000) {
      return null;
    }

    // if our new eta is more than a minute off from the last one, only update the by 1 minute so it doesn't jump all over the place
    if (lastEtaDuration != null) {
      bool isIncreasing = duration.inSeconds > lastEtaDuration!.inSeconds;
      bool diffMoreThanOneMinute = (duration.inSeconds - lastEtaDuration!.inSeconds).abs() > 60;
      bool diffMoreThanOneHour = (duration.inSeconds - lastEtaDuration!.inSeconds).abs() > 3600;
      if (diffMoreThanOneHour) {
        duration = Duration(minutes: lastEtaDuration!.inMinutes + (isIncreasing ? 1 : -1));
      } else if (diffMoreThanOneMinute) {
        duration = Duration(seconds: lastEtaDuration!.inSeconds + (isIncreasing ? 1 : -1));
      } else {
        // if the diff is less than a minute don't change it:
        duration = lastEtaDuration!;
      }
    }

    lastEtaDuration = duration;

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours == '00') {
      return '${minutes}m${seconds}s';
    }
    return '${hours}h${minutes}m${seconds}s';
  }

  // Calculate the rate of block processing (blocks per second)
  double _calculateBlockRate() {
    List<DateTime> timestamps = blockHistory.keys.toList();
    List<int> blockCounts = blockHistory.values.toList();

    double totalTime = 0;
    int totalBlocksProcessed = 0;

    for (int i = 0; i < blockCounts.length - 1; i++) {
      int blocksProcessed = blockCounts[i] - blockCounts[i + 1];
      Duration timeDifference = timestamps[i + 1].difference(timestamps[i]);
      totalTime += timeDifference.inMicroseconds;
      totalBlocksProcessed += blocksProcessed;
    }

    if (totalTime == 0 || totalBlocksProcessed == 0) {
      return 0;
    }

    double blocksPerSecond = totalBlocksProcessed / (totalTime / 1000000);
    return blocksPerSecond;
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

class SyncronizingSyncStatus extends SyncStatus {
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
