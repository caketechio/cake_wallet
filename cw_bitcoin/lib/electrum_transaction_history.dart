import 'dart:convert';
import 'package:cw_core/encryption_file_utils.dart';

import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/utils/file.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';

part 'electrum_transaction_history.g.dart';

const transactionsHistoryFileName = 'transactions.json';

class ElectrumTransactionHistory = ElectrumTransactionHistoryBase with _$ElectrumTransactionHistory;

abstract class ElectrumTransactionHistoryBase
    extends TransactionHistoryBase<ElectrumTransactionInfo> with Store {
  ElectrumTransactionHistoryBase(
      {required this.walletInfo, required String password, required this.encryptionFileUtils})
      : _password = password,
        _height = 0 {
    transactions = ObservableMap<String, ElectrumTransactionInfo>();
  }

  final WalletInfo walletInfo;
  final EncryptionFileUtils encryptionFileUtils;
  String _password;
  int _height;

  Future<void> init() async => await _load();

  @action
  @override
  void addOne(ElectrumTransactionInfo transaction) => _update(transaction);

  @action
  @override
  void addMany(Map<String, ElectrumTransactionInfo> transactions) =>
      transactions.forEach((_, tx) => _update(tx));

  @override
  Future<void> save() async {
    try {
      final dirPath = await pathForWalletDir(name: walletInfo.name, type: walletInfo.type);
      final path = '$dirPath/$transactionsHistoryFileName';
      final txjson = {};
      for (final tx in transactions.entries) {
        txjson[tx.key] = tx.value.toJson();
      }
      final data = json.encode({'height': _height, 'transactions': txjson});
      await encryptionFileUtils.write(path: path, password: _password, data: data);
    } catch (e) {
      print('Error while save bitcoin transaction history: ${e.toString()}');
    }
  }

  Future<void> changePassword(String password) async {
    _password = password;
    await save();
  }

  Future<Map<String, dynamic>> _read() async {
    final dirPath = await pathForWalletDir(name: walletInfo.name, type: walletInfo.type);
    final path = '$dirPath/$transactionsHistoryFileName';
    final content = await encryptionFileUtils.read(path: path, password: _password);
    return json.decode(content) as Map<String, dynamic>;
  }

  Future<void> _load() async {
    try {
      final content = await _read();
      final txs = content['transactions'] as Map<String, dynamic>? ?? {};

      txs.entries.forEach((entry) {
        final val = entry.value;

        if (val is Map<String, dynamic>) {
          final tx = ElectrumTransactionInfo.fromJson(val, walletInfo.type);
          _update(tx);
        }
      });

      _height = content['height'] as int;
    } catch (e, s) {
      print(e);
      print(s);
    }
  }

  @action
  void _update(ElectrumTransactionInfo transaction) {
    transactions.update(transaction.id, (_) => transaction, ifAbsent: () => transaction);
  }
}
