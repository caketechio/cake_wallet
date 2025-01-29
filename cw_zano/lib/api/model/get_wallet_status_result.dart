class GetWalletStatusResult {
  final int currentDaemonHeight;
  final int currentWalletHeight;
  final bool isDaemonConnected;
  final bool isInLongRefresh;
  final int progress;
  final int walletState;

  GetWalletStatusResult(
      {required this.currentDaemonHeight,
      required this.currentWalletHeight,
      required this.isDaemonConnected,
      required this.isInLongRefresh,
      required this.progress,
      required this.walletState});

  factory GetWalletStatusResult.fromJson(Map<String, dynamic> json) =>
      GetWalletStatusResult(
        currentDaemonHeight: json['current_daemon_height'] as int? ?? 0,
        currentWalletHeight: json['current_wallet_height'] as int? ?? 0,
        isDaemonConnected: json['is_daemon_connected'] as bool? ?? false,
        isInLongRefresh: json['is_in_long_refresh'] as bool? ?? false,
        progress: json['progress'] as int? ?? 0,
        walletState: json['wallet_state'] as int? ?? 0,
      );
}
