import 'package:cw_zano/api/model/wi.dart';
import 'package:cw_zano/api/model/wi_extended.dart';

class GetWalletInfoResult {
  final Wi wi;
  final WiExtended wiExtended;

  GetWalletInfoResult({required this.wi, required this.wiExtended});

  factory GetWalletInfoResult.fromJson(Map<String, dynamic> json) => GetWalletInfoResult(
        wi: Wi.fromJson(json['wi'] as Map<String, dynamic>? ?? {}),
        wiExtended: WiExtended.fromJson(json['wi_extended'] as Map<String, dynamic>? ?? {}),
      );
}
