import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/monero_amount_format.dart';
import 'package:cw_haven/api/structs/transaction_info_row.dart';
import 'package:cw_core/parseBoolFromString.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/format_amount.dart';
import 'package:cw_haven/api/transaction_history.dart';
import 'package:intl/intl.dart';
import 'package:cw_haven/api/wallet.dart' as haven_wallet;

class HavenTransactionInfo extends TransactionInfo {
  HavenTransactionInfo(this.id, this.height, this.direction, this.date, this.isPending, this.amount,
      this.accountIndex, this.addressIndex, this.fee, this.unlockTime, this.confirmations);

  HavenTransactionInfo.fromRow(TransactionInfoRow row)
      : id = row.getHash(),
        height = row.blockHeight,
        direction = TransactionDirection.parseFromInt(row.direction),
        date = DateTime.fromMillisecondsSinceEpoch(row.getDatetime() * 1000),
        isPending = row.isPending != 0,
        amount = row.getAmount(),
        accountIndex = row.subaddrAccount,
        addressIndex = row.subaddrIndex,
        unlockTime = row.getUnlockTime(),
        confirmations = row.confirmations,
        key = null,
        //getTxKey(row.getHash()),
        fee = row.fee,
        assetType = row.getAssetType();

  final String id;
  final int height;
  final TransactionDirection direction;
  final DateTime date;
  final int accountIndex;
  final bool isPending;
  final int amount;
  final int fee;
  final int addressIndex;
  final int confirmations;
  late String recipientAddress;
  late String assetType;
  final int unlockTime;
  String? _fiatAmount;
  String? key;

  @override
  String amountFormatted() => '${formatAmount(moneroAmountToString(amount: amount))} $assetType';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);

  @override
  String feeFormatted() => '${formatAmount(moneroAmountToString(amount: fee))} $assetType';

  @override
  String? unlockTimeFormatted() {
    final currentHeight = haven_wallet.getCurrentHeight();
    if (direction == TransactionDirection.outgoing || unlockTime < (currentHeight + 10)) {
      return null;
    }

    if (unlockTime < 500000000) {
      return (unlockTime - currentHeight) * 2 > 500000
          ? '>1 year'
          : '~${(unlockTime - currentHeight) * 2} minutes';
    }
    try {
      var locked = DateTime.fromMillisecondsSinceEpoch(unlockTime).compareTo(DateTime.now());
      final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      final String formattedUnlockTime =
      formatter.format(DateTime.fromMillisecondsSinceEpoch(unlockTime));
      return locked > 0 ? '$formattedUnlockTime' : null;
    } catch (e) {
      print(e);
      return null;
    }
  }
}
