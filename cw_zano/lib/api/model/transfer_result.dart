class TransferResult {
  final String txHash;
  final int txSize;
  final String txUnsignedHex;

  TransferResult({required this.txHash, required this.txSize, required this.txUnsignedHex});

  factory TransferResult.fromJson(Map<String, dynamic> json) => TransferResult(
        txHash: json['tx_hash'] as String? ?? '',
        txSize: json['tx_size'] as int? ?? 0,
        txUnsignedHex: json['tx_unsigned_hex'] as String? ?? '',
      );
}
