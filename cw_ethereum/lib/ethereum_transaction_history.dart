import 'dart:convert';
import 'dart:core';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/encryption_file_utils.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_ethereum/ethereum_transaction_info.dart';

part 'ethereum_transaction_history.g.dart';

const transactionsHistoryFileName = 'transactions.json';

class EthereumTransactionHistory = EthereumTransactionHistoryBase with _$EthereumTransactionHistory;

abstract class EthereumTransactionHistoryBase
    extends TransactionHistoryBase<EthereumTransactionInfo> with Store {
  EthereumTransactionHistoryBase({
    required this.walletInfo,
    required String password,
    required this.encryptionFileUtils,
    required this.isFlatpak,
  }) : _password = password {
    transactions = ObservableMap<String, EthereumTransactionInfo>();
  }

  final WalletInfo walletInfo;
  final EncryptionFileUtils encryptionFileUtils;
  final bool isFlatpak;
  String _password;

  Future<void> init() async => await _load();

  @override
  Future<void> save() async {
    try {
      final dirPath = await pathForWalletDir(
          name: walletInfo.name, type: walletInfo.type, isFlatpak: isFlatpak);
      final path = '$dirPath/$transactionsHistoryFileName';
      final data = json.encode({'transactions': transactions});
      await encryptionFileUtils.write(path: path, password: _password, data: data);
    } catch (e, s) {
      print('Error while save ethereum transaction history: ${e.toString()}');
      print(s);
    }
  }

  @override
  void addOne(EthereumTransactionInfo transaction) => transactions[transaction.id] = transaction;

  @override
  void addMany(Map<String, EthereumTransactionInfo> transactions) =>
      this.transactions.addAll(transactions);

  Future<Map<String, dynamic>> _read() async {
    final dirPath =
        await pathForWalletDir(name: walletInfo.name, type: walletInfo.type, isFlatpak: isFlatpak);
    final path = '$dirPath/$transactionsHistoryFileName';
    final content = await encryptionFileUtils.read(path: path, password: _password);
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
          final tx = EthereumTransactionInfo.fromJson(val);
          _update(tx);
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _update(EthereumTransactionInfo transaction) => transactions[transaction.id] = transaction;
}
