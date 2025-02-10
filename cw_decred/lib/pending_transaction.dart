import 'package:cw_core/pending_transaction.dart';
import 'package:cw_decred/amount_format.dart';

class DecredPendingTransaction with PendingTransaction {
  DecredPendingTransaction(
      {required this.txid,
      required this.amount,
      required this.fee,
      required this.rawHex,
      required this.send});

  final int amount;
  final int fee;
  final String txid;
  final String rawHex;
  final Future<void> Function() send;

  @override
  String get id => txid;

  @override
  String get amountFormatted => decredAmountToString(amount: amount);

  @override
  String get feeFormatted => decredAmountToString(amount: fee);

  @override
  String get hex => rawHex;

  @override
  Future<void> commit() async {
    return send();
  }

  @override
  Future<String?> commitUR() {
    throw UnimplementedError();
  }
}
