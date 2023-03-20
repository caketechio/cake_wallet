import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:cw_core/fee_estimate.dart';
import 'package:cw_core/transaction_priority.dart';

class ElectrumFeeEstimate extends FeeEstimate {
  ElectrumFeeEstimate(ElectrumWalletBase wallet)
    : _wallet = wallet;

  ElectrumWalletBase _wallet;

  int get({TransactionPriority? priority, int? amount, int? outputsCount}) {
    // Electrum doesn't require an async call to obtain the estimated fee.
    // We don't bother caching and just obtain it directly.
    return _wallet.calculateEstimatedFee(priority,amount, outputsCount: outputsCount);
  }

  void update({TransactionPriority? priority, int? amount, int? outputsCount}) {}

  void set({TransactionPriority? priority, int? outputsCount, int? fee}) {}
}