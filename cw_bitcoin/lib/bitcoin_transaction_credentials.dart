import 'package:cw_bitcoin/bitcoin_transaction_priority.dart';
import 'package:cw_core/output_info.dart';
import 'package:cw_core/unspent_coin_type.dart';

class BitcoinTransactionCredentials {
  BitcoinTransactionCredentials(
    this.outputs, {
    required this.priority,
    this.feeRate,
    this.coinTypeToSpendFrom = UnspentCoinType.any,
    this.payjoinUri,
  });

  final List<OutputInfo> outputs;
  final BitcoinTransactionPriority? priority;
  final int? feeRate;
  final UnspentCoinType coinTypeToSpendFrom;
  final String? payjoinUri;
}
