import 'package:cw_zano/zano_formatter.dart';

class Receive {
  final BigInt amount;
  final String assetId;
  final int index;

  Receive({required this.amount, required this.assetId, required this.index});

  factory Receive.fromJson(Map<String, dynamic> json) => Receive(
        amount: ZanoFormatter.bigIntFromDynamic(json['amount']),
        assetId: json['asset_id'] as String? ?? '',
        index: json['index'] as int? ?? 0,
      );
}
