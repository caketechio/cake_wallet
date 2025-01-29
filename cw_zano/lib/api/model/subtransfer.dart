import 'package:cw_zano/zano_formatter.dart';

class Subtransfer {
  final BigInt amount;
  final String assetId;
  final bool isIncome;

  Subtransfer(
      {required this.amount, required this.assetId, required this.isIncome});

  factory Subtransfer.fromJson(Map<String, dynamic> json) => Subtransfer(
        amount: ZanoFormatter.bigIntFromDynamic(json['amount']),
        assetId: json['asset_id'] as String? ?? '',
        isIncome: json['is_income'] as bool? ?? false,
      );
}
