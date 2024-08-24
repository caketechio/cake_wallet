import 'package:cw_bitcoin/bitcoin_amount_format.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/format_amount.dart';
import 'package:cw_core/wallet_type.dart';

class LightningTransactionInfo extends ElectrumTransactionInfo {
  LightningTransactionInfo({
    required String id,
    required int amount,
    int? fee,
    required TransactionDirection direction,
    required bool isPending,
    required DateTime date,
    required bool isChannelClose,
  }) : super(
          WalletType.lightning,
          amount: amount,
          fee: fee,
          direction: direction,
          date: date,
          isPending: isPending,
          id: id,
          confirmations: 0,
          height: 0,
        ) {
          additionalInfo['isChannelClose'] = isChannelClose;
        }

  @override
  String amountFormatted() =>
      '${formatAmount(bitcoinAmountToLightningString(amount: amount))} ${walletTypeToCryptoCurrency(type).title}';

  @override
  String? feeFormatted() => fee != null
      ? '${formatAmount(bitcoinAmountToLightningString(amount: fee!))} ${walletTypeToCryptoCurrency(type).title}'
      : '';

  factory LightningTransactionInfo.fromJson(Map<String, dynamic> data, WalletType type) {
    return LightningTransactionInfo(
      id: data['id'] as String,
      amount: data['amount'] as int,
      fee: data['fee'] as int,
      direction: parseTransactionDirectionFromInt(data['direction'] as int),
      date: DateTime.fromMillisecondsSinceEpoch(data['date'] as int),
      isPending: data['isPending'] as bool,
      isChannelClose: data['isChannelClose'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    m['id'] = id;
    m['amount'] = amount;
    m['direction'] = direction.index;
    m['date'] = date.millisecondsSinceEpoch;
    m['isPending'] = isPending;
    m['fee'] = fee;
    // to remain compatible with electrumTx's when loaded from a file:
    m['height'] = super.height;
    m['confirmations'] = super.confirmations;
    m['isChannelClose'] = additionalInfo['isChannelClose'];
    return m;
  }
}
