import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/monero_transaction_priority.dart';
import 'package:cw_core/output_info.dart';

class ZanoTransactionCredentials {
  ZanoTransactionCredentials({required this.outputs, required this.priority, required this.currency});

  final List<OutputInfo> outputs;
  final MoneroTransactionPriority priority;
  final CryptoCurrency currency;
}
