class StoreResult {
  final int walletFileSize;

  StoreResult({required this.walletFileSize});

  factory StoreResult.fromJson(Map<String, dynamic> json) => StoreResult(
        walletFileSize: json['wallet_file_size'] as int? ?? 0,
      );
}