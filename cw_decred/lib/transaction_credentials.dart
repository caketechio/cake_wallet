import 'package:cw_decred/transaction_priority.dart';
import 'package:cw_core/output_info.dart';

class DecredTransactionCredentials {
  DecredTransactionCredentials(this.outputs, {required this.priority, this.feeRate});

  final List<OutputInfo> outputs;
  final DecredTransactionPriority? priority;
  final int? feeRate;
}
