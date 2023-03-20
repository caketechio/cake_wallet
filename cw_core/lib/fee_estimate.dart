import 'package:cw_core/transaction_priority.dart';

abstract class FeeEstimate
{
  void update({required TransactionPriority priority, int outputsCount = 1});

  int get({required TransactionPriority priority, required int amount, int outputsCount = 1});

  void set({required TransactionPriority priority, required int outputsCount, required int fee});
}