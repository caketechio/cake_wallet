import 'dart:convert';
import 'dart:core';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/utils/file.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_polygon/polygon_transaction_info.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';

part 'polygon_transaction_history.g.dart';

const transactionsHistoryFileName = 'polygon_transactions.json';

class PolygonTransactionHistory = PolygonTransactionHistoryBase with _$PolygonTransactionHistory;

abstract class PolygonTransactionHistoryBase extends TransactionHistoryBase<PolygonTransactionInfo>
    with Store {
  PolygonTransactionHistoryBase(
      {required this.walletInfo, required String password, required this.isFlatpak})
      : _password = password {
    transactions = ObservableMap<String, PolygonTransactionInfo>();
  }

  final bool isFlatpak;
  final WalletInfo walletInfo;
  String _password;

  Future<void> init() async => await _load();

  @override
  Future<void> save() async {
    try {
      final dirPath = await pathForWalletDir(
          name: walletInfo.name, type: walletInfo.type, isFlatpak: isFlatpak);
      final path = '$dirPath/$transactionsHistoryFileName';
      final data = json.encode({'transactions': transactions});
      await writeData(path: path, password: _password, data: data);
    } catch (e, s) {
      print('Error while saving polygon  transaction history: ${e.toString()}');
      print(s);
    }
  }

  @override
  void addOne(PolygonTransactionInfo transaction) => transactions[transaction.id] = transaction;

  @override
  void addMany(Map<String, PolygonTransactionInfo> transactions) =>
      this.transactions.addAll(transactions);

  Future<Map<String, dynamic>> _read() async {
    final dirPath =
        await pathForWalletDir(name: walletInfo.name, type: walletInfo.type, isFlatpak: isFlatpak);
    final path = '$dirPath/$transactionsHistoryFileName';
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

      txs.entries.forEach((entry) {
        final val = entry.value;

        if (val is Map<String, dynamic>) {
          final tx = PolygonTransactionInfo.fromJson(val);
          _update(tx);
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _update(PolygonTransactionInfo transaction) => transactions[transaction.id] = transaction;
}
