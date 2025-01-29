import 'package:cw_core/format_amount.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_zano/api/model/transfer.dart';
import 'package:cw_zano/zano_formatter.dart';

class ZanoTransactionInfo extends TransactionInfo {
  ZanoTransactionInfo({
    required this.id,
    required this.height,
    required this.direction,
    required this.date,
    required this.isPending,
    required this.zanoAmount,
    required this.fee,
    required this.confirmations,
    required this.tokenSymbol,
    required this.decimalPoint,
    required String assetId,
  }) : amount = zanoAmount.isValidInt ? zanoAmount.toInt() : 0 {
    additionalInfo['assetId'] = assetId;
  }

  ZanoTransactionInfo.fromTransfer(Transfer transfer,
      {required int confirmations,
        required bool isIncome,
        required String assetId,
        required BigInt amount,
        this.tokenSymbol = 'ZANO',
        this.decimalPoint = ZanoFormatter.defaultDecimalPoint})
      : id = transfer.txHash,
        height = transfer.height,
        direction = isIncome ? TransactionDirection.incoming : TransactionDirection.outgoing,
        date = DateTime.fromMillisecondsSinceEpoch(transfer.timestamp * 1000),
        zanoAmount = amount,
        amount = amount.isValidInt ? amount.toInt() : 0,
        fee = transfer.fee,
        confirmations = confirmations,
        isPending = confirmations < 10,
        recipientAddress = transfer.remoteAddresses.isNotEmpty
            ? transfer.remoteAddresses.first
            : '' {
    additionalInfo = <String, dynamic>{
      'comment': transfer.comment,
      'assetId': assetId,
    };
  }

  String get assetId => additionalInfo["assetId"] as String;

  set assetId(String newId) => additionalInfo["assetId"] = newId;
  final String id;
  final int height;
  final TransactionDirection direction;
  final DateTime date;
  final bool isPending;
  final BigInt zanoAmount;
  final int amount;
  final int fee;
  final int confirmations;
  final int decimalPoint;
  late String recipientAddress;
  final String tokenSymbol;
  String? _fiatAmount;
  String? key;

  @override
  String amountFormatted() =>
      '${formatAmount(ZanoFormatter.bigIntAmountToString(zanoAmount, decimalPoint))} $tokenSymbol';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  @override
  String feeFormatted() => '${formatAmount(ZanoFormatter.intAmountToString(fee))} $feeCurrency';

  String get feeCurrency => 'ZANO';
}
