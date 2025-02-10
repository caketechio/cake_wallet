import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/format_amount.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_decred/amount_format.dart';

class DecredTransactionInfo extends TransactionInfo {
  DecredTransactionInfo({
    required String id,
    required int amount,
    required int fee,
    required TransactionDirection direction,
    required bool isPending,
    required DateTime date,
    required int height,
    required int confirmations,
    required String to,
  }) {
    this.id = id;
    this.amount = amount;
    this.fee = fee;
    this.height = height;
    this.direction = direction;
    this.date = date;
    this.isPending = isPending;
    this.confirmations = confirmations;
    this.to = to;
  }

  String? _fiatAmount;

  @override
  String amountFormatted() =>
      '${formatAmount(decredAmountToString(amount: amount))} ${walletTypeToCryptoCurrency(WalletType.decred).title}';

  @override
  String? feeFormatted() =>
      '${formatAmount(decredAmountToString(amount: amount))} ${walletTypeToCryptoCurrency(WalletType.decred).title}';

  @override
  String fiatAmount() => _fiatAmount ?? '';

  @override
  void changeFiatAmount(String amount) => _fiatAmount = formatAmount(amount);
}
