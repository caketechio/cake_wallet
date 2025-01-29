import 'dart:core';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_zano/model/zano_transaction_info.dart';

part 'zano_transaction_history.g.dart';

class ZanoTransactionHistory = ZanoTransactionHistoryBase
    with _$ZanoTransactionHistory;

abstract class ZanoTransactionHistoryBase
    extends TransactionHistoryBase<ZanoTransactionInfo> with Store {
  ZanoTransactionHistoryBase() {
    transactions = ObservableMap<String, ZanoTransactionInfo>();
  }

  @override
  Future<void> save() async {}

  @override
  void addOne(ZanoTransactionInfo transaction) =>
      transactions[transaction.id] = transaction;

  @override
  void addMany(Map<String, ZanoTransactionInfo> transactions) =>
      this.transactions.addAll(transactions);
}
