import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_evm/evm_chain_transaction_info.dart';
import 'package:cw_evm/file.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';

part 'evm_chain_transaction_history.g.dart';

const transactionsHistoryFileName = 'transactions.json';

class EVMChainTransactionHistory = EVMChainTransactionHistoryBase with _$EVMChainTransactionHistory;

abstract class EVMChainTransactionHistoryBase
    extends TransactionHistoryBase<EVMChainTransactionInfo> with Store {
  EVMChainTransactionHistoryBase({required this.walletInfo, required String password})
      : _password = password {
    transactions = ObservableMap<String, EVMChainTransactionInfo>();
  }

  final WalletInfo walletInfo;
  String _password;

  Future<void> init() async => await _load();

  @override
  Future<void> save() async {
    try {
      final dirPath = await pathForWalletDir(name: walletInfo.name, type: walletInfo.type);

      // For backward compatibility
      // Ethereum transactions is currently saved in [transactions.json]
      // Polygon transactions is currently saved in [polygon_transactions.json]
      String path;
      if (walletInfo.type == WalletType.ethereum) {
        path = '$dirPath/$transactionsHistoryFileName';
      } else {
        path = '$dirPath/${walletInfo.type.name}_$transactionsHistoryFileName';
      }

      final data = json.encode({'transactions': transactions});
      await writeData(path: path, password: _password, data: data);
    } catch (e, s) {
      log('Error while saving ${walletInfo.type.name} transaction history: ${e.toString()}');
      log(s.toString());
    }
  }

  @override
  void addOne(EVMChainTransactionInfo transaction) => transactions[transaction.id] = transaction;

  @override
  void addMany(Map<String, EVMChainTransactionInfo> transactions) =>
      this.transactions.addAll(transactions);

  Future<Map<String, dynamic>> _read() async {
    final dirPath = await pathForWalletDir(name: walletInfo.name, type: walletInfo.type);

    // For backward compatibility
    // Ethereum transactions is currently saved in  [transactions.json]
    // Polygon transactions is currently saved in [polygon_transactions.json]
    String path;
    if (walletInfo.type == WalletType.ethereum) {
      path = '$dirPath/$transactionsHistoryFileName';
    } else {
      path = '$dirPath/${walletInfo.type.name}_$transactionsHistoryFileName';
    }

    final content = await read(path: path, password: _password);
    if (content.isEmpty) {
      return {};
    }
    return json.decode(content) as Map<String, dynamic>;
  }

  Future<void> _load() async {
    try {
      final content = await _read();
      final txs = content['transactions'] as Map<String, dynamic>? ?? {};

      for (var entry in txs.entries) {
        final val = entry.value;

        if (val is Map<String, dynamic>) {
          final tx = EVMChainTransactionInfo.fromJson(val);
          _update(tx);
        }
      }
    } catch (e) {
      log(e.toString());
    }
  }

  void _update(EVMChainTransactionInfo transaction) => transactions[transaction.id] = transaction;
}
