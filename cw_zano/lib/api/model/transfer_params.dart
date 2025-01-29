import 'package:cw_zano/api/model/destination.dart';

class TransferParams {
  final List<Destination> destinations;
  final BigInt fee;
  final int mixin;
  final String paymentId;
  final String comment;
  final bool pushPayer;
  final bool hideReceiver;

  TransferParams({
    required this.destinations,
    required this.fee,
    required this.mixin,
    required this.paymentId,
    required this.comment,
    required this.pushPayer,
    required this.hideReceiver,
  });

  Map<String, dynamic> toJson() => {
    'destinations': destinations,
    'fee': fee.toInt(),
    'mixin': mixin,
    'payment_id': paymentId,
    'comment': comment,
    'push_payer': pushPayer,
    'hide_receiver': hideReceiver,
  };

  factory TransferParams.fromJson(Map<String, dynamic> json) => TransferParams(
        destinations: (json['destinations'] as List<dynamic>?)?.map((e) => Destination.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        fee: BigInt.from(json['fee'] as int? ?? 0),
        mixin: json['mixin'] as int? ?? 0,
        paymentId: json['payment_id'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
        pushPayer: json['push_payer'] as bool? ?? false,
        hideReceiver: json['hide_receiver'] as bool? ?? false,
      );
}
