class GetAddressInfoResult {
  final bool valid;
  final bool auditable;
  final bool paymentId;
  final bool wrap;

  GetAddressInfoResult(
      {required this.valid, required this.auditable, required this.paymentId, required this.wrap});

  factory GetAddressInfoResult.fromJson(Map<String, dynamic> json) => GetAddressInfoResult(
        valid: json['valid'] as bool? ?? false,
        auditable: json['auditable'] as bool? ?? false,
        paymentId: json['payment_id'] as bool? ?? false,
        wrap: json['wrap'] as bool? ?? false,
      );
}
