import 'package:cw_zano/api/model/transfer.dart';

class RecentHistory {
  final List<Transfer>? history;
  final int lastItemIndex;
  final int totalHistoryItems;

  RecentHistory(
      {required this.history,
      required this.lastItemIndex,
      required this.totalHistoryItems});

  factory RecentHistory.fromJson(Map<String, dynamic> json) => RecentHistory(
        history: json['history'] == null ? null : (json['history'] as List<dynamic>)
            .map((e) => Transfer.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastItemIndex: json['last_item_index'] as int? ?? 0,
        totalHistoryItems: json['total_history_items'] as int? ?? 0,
      );
}
