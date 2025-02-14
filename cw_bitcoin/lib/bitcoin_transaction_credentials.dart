import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/output_info.dart';
import 'package:cw_core/unspent_coin_type.dart';

class BitcoinTransactionCredentials {
  BitcoinTransactionCredentials(this.outputs,
      {required this.priority, this.feeRate, this.coinTypeToSpendFrom = UnspentCoinType.any});

  final List<OutputInfo> outputs;
  final TransactionPriority? priority;
  final int? feeRate;
  final UnspentCoinType coinTypeToSpendFrom;
}
