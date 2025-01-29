import 'package:cw_core/pending_transaction.dart';
import 'package:cw_zano/api/model/destination.dart';
import 'package:cw_zano/api/model/transfer_result.dart';
import 'package:cw_zano/zano_formatter.dart';
import 'package:cw_zano/zano_wallet.dart';

class PendingZanoTransaction with PendingTransaction {
  PendingZanoTransaction({
    required this.zanoWallet,
    required this.destinations,
    required this.fee,
    required this.comment,
    required this.assetId,
    required this.ticker,
    this.decimalPoint = ZanoFormatter.defaultDecimalPoint,
    required this.amount,
  });

  final ZanoWalletBase zanoWallet;
  final List<Destination> destinations;
  final BigInt fee;
  final String comment;
  final String assetId;
  final String ticker;
  final int decimalPoint;
  final BigInt amount;

  @override
  String get id => transferResult?.txHash ?? '';

  @override
  String get hex => '';

  @override
  String get amountFormatted => ZanoFormatter.bigIntAmountToString(amount, decimalPoint);

  @override
  String get feeFormatted => ZanoFormatter.bigIntAmountToString(fee);

  TransferResult? transferResult;

  @override
  Future<void> commit() async {
    await zanoWallet.transfer(destinations, fee, comment);
    zanoWallet.fetchTransactions();
  }
  
  @override
  Future<String?> commitUR() {
    throw UnimplementedError();
  }
}
