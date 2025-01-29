class Destination {
  final BigInt amount;     // transfered as string
  final String address;
  final String assetId;

  Destination(
      {required this.amount, required this.address, required this.assetId});

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
        amount: BigInt.parse(json['amount'] as String? ?? '0'),
        address: json['address'] as String? ?? '',
        assetId: json['asset_id'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'amount': amount.toString(),
    'address': address,
    'asset_id': assetId,
  };
}
