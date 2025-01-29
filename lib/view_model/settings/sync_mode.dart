enum SyncType { minutes, oneHour, threeHours, sixHours, twelveHours }

class SyncMode {
  SyncMode(this.name, this.type, this.frequency);

  final String name;
  final SyncType type;
  final Duration frequency;

  static final all = [
    SyncMode("15 Minutes", SyncType.minutes, Duration(minutes: 15)),
    SyncMode("1 Hour", SyncType.oneHour, Duration(hours: 1)),
    SyncMode("3 Hours", SyncType.threeHours, Duration(hours: 3)),
    SyncMode("6 Hours", SyncType.sixHours, Duration(hours: 6)),
    SyncMode("12 Hours", SyncType.twelveHours, Duration(hours: 12)),
  ];
}
