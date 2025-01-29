import 'package:cw_zano/api/model/recent_history.dart';
import 'package:cw_zano/api/model/wi.dart';

class CreateWalletResult {
  final String name;
  final String pass;
  final RecentHistory recentHistory;
  final bool recovered;
  final String seed;
  final int walletFileSize;
  final int walletId;
  final int walletLocalBcSize;
  final Wi wi;

  CreateWalletResult(
      {required this.name,
      required this.pass,
      required this.recentHistory,
      required this.recovered,
      required this.seed,
      required this.walletFileSize,
      required this.walletId,
      required this.walletLocalBcSize,
      required this.wi});

  factory CreateWalletResult.fromJson(Map<String, dynamic> json) =>
      CreateWalletResult(
        name: json['name'] as String? ?? '',
        pass: json['pass'] as String? ?? '',
        recentHistory: RecentHistory.fromJson(
            json['recent_history'] as Map<String, dynamic>? ?? {}),
        recovered: json['recovered'] as bool? ?? false,
        seed: json['seed'] as String? ?? '',
        walletFileSize: json['wallet_file_size'] as int? ?? 0,
        walletId: json['wallet_id'] as int? ?? 0,
        walletLocalBcSize: json['wallet_local_bc_size'] as int? ?? 0,
        wi: Wi.fromJson(json['wi'] as Map<String, dynamic>? ?? {}),
      );
}
