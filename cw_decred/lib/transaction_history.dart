import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_history.dart';

class DecredTransactionHistory extends TransactionHistoryBase<TransactionInfo> {
  DecredTransactionHistory() {
    transactions = ObservableMap<String, TransactionInfo>();
  }

  @override
  void addOne(TransactionInfo transaction) => transactions[transaction.id] = transaction;

  @override
  void addMany(Map<String, TransactionInfo> transactions) => this.transactions.addAll(transactions);

  @override
  Future<void> save() async {}

  // update returns true if a known transaction that is not pending was found.
  bool update(Map<String, TransactionInfo> txs) {
    var foundOldTx = false;
    txs.forEach((_, tx) {
      if (!this.transactions.containsKey(tx.id) || this.transactions[tx.id]!.isPending) {
        this.transactions[tx.id] = tx;
      } else {
        foundOldTx = true;
      }
    });
    return foundOldTx;
  }
}
