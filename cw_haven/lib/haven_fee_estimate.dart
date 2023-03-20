import 'package:mobx/mobx.dart';
import 'package:cw_core/fee_estimate.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_haven/api/wallet.dart' as haven_wallet;

part 'haven_fee_estimate.g.dart';

class HavenFeeEstimate = _HavenFeeEstimate with _$HavenFeeEstimate;

abstract class _HavenFeeEstimate extends FeeEstimate with Store {
  _HavenFeeEstimate()
      : _estimatedFee = new ObservableMap<String, int>();

  @observable
  ObservableMap<String, int> _estimatedFee;

  @override
  void update({required TransactionPriority priority, int outputsCount = 1}) {
    Future(() async {
      final fee = await haven_wallet.estimateTransactionFee(priorityRaw: priority.raw, outputsCount: outputsCount);
      set(priority: priority, fee: fee, outputsCount: outputsCount);
    });
  }

  @override
  int get({required TransactionPriority priority, required int amount, int outputsCount = 1}) {
    return _estimatedFee[_key(priority, outputsCount)] ?? 0;
  }

  @override
  void set({required TransactionPriority priority, required int outputsCount, required int fee}) {
    _estimatedFee[_key(priority, outputsCount)] = fee;
  }

  String _key(TransactionPriority priority, int outputsCount) {
    return "$priority:$outputsCount";
  }
}