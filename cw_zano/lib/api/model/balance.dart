import 'package:cw_core/zano_asset.dart';
import 'package:cw_zano/model/zano_asset.dart';
import 'package:cw_zano/zano_formatter.dart';

class Balance {
  final ZanoAsset assetInfo;
  final BigInt awaitingIn;
  final BigInt awaitingOut;
  final BigInt total;
  final BigInt unlocked;

  Balance(
      {required this.assetInfo,
      required this.awaitingIn,
      required this.awaitingOut,
      required this.total,
      required this.unlocked});
      
  String get assetId => assetInfo.assetId;

  @override
  String toString() => '$assetInfo: $total/$unlocked';

  factory Balance.fromJson(Map<String, dynamic> json) => Balance(
        assetInfo:
            ZanoAsset.fromJson(json['asset_info'] as Map<String, dynamic>? ?? {}),
        awaitingIn: ZanoFormatter.bigIntFromDynamic(json['awaiting_in']),
        awaitingOut: ZanoFormatter.bigIntFromDynamic(json['awaiting_out']),
        total: ZanoFormatter.bigIntFromDynamic(json['total']),
        unlocked: ZanoFormatter.bigIntFromDynamic(json['unlocked']),
      );
}
