import 'dart:convert';

import 'package:cw_bitcoin/electrum_worker/electrum_worker_params.dart';
import 'package:cw_bitcoin/electrum_worker/methods/methods.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:bitbox/bitbox.dart' as bitbox;
import 'package:cw_core/pending_transaction.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/wallet_type.dart';

class PendingBitcoinCashTransaction with PendingTransaction {
  PendingBitcoinCashTransaction(
    this._tx,
    this.type, {
    required this.sendWorker,
    required this.amount,
    required this.fee,
    required this.hasChange,
    required this.isSendAll,
  }) : _listeners = <void Function(ElectrumTransactionInfo transaction)>[];

  final WalletType type;
  final bitbox.Transaction _tx;
  Future<dynamic> Function(ElectrumWorkerRequest) sendWorker;
  final int amount;
  final int fee;
  final bool hasChange;
  final bool isSendAll;

  @override
  String get id => _tx.getId();

  @override
  String get hex => _tx.toHex();

  @override
  String get amountFormatted => BitcoinAmountUtils.bitcoinAmountToString(amount: amount);

  @override
  String get feeFormatted => BitcoinAmountUtils.bitcoinAmountToString(amount: fee);

  final List<void Function(ElectrumTransactionInfo transaction)> _listeners;

  @override
  Future<void> commit() async {
    final result = await sendWorker(
      ElectrumWorkerBroadcastRequest(transactionRaw: hex),
    ) as String;

    String? error;
    try {
      final resultJson = jsonDecode(result) as Map<String, dynamic>;
      error = resultJson["error"] as String;
    } catch (_) {}

    if (error != null) {
      if (error.contains("dust")) {
        if (hasChange) {
          throw BitcoinTransactionCommitFailedDustChange();
        } else if (!isSendAll) {
          throw BitcoinTransactionCommitFailedDustOutput();
        } else {
          throw BitcoinTransactionCommitFailedDustOutputSendAll();
        }
      }

      if (error.contains("bad-txns-vout-negative")) {
        throw BitcoinTransactionCommitFailedVoutNegative();
      }

      if (error.contains("non-BIP68-final")) {
        throw BitcoinTransactionCommitFailedBIP68Final();
      }

      if (error.contains("min fee not met")) {
        throw BitcoinTransactionCommitFailedLessThanMin();
      }

      throw BitcoinTransactionCommitFailed(errorMessage: error);
    }

    _listeners.forEach((listener) => listener(transactionInfo()));
  }

  void addListener(void Function(ElectrumTransactionInfo transaction) listener) =>
      _listeners.add(listener);

  ElectrumTransactionInfo transactionInfo() => ElectrumTransactionInfo(
        type,
        id: id,
        height: 0,
        amount: amount,
        direction: TransactionDirection.outgoing,
        date: DateTime.now(),
        isPending: true,
        confirmations: 0,
        fee: fee,
        isReplaced: false,
      );

  @override
  Future<String?> commitUR() {
    throw UnimplementedError();
  }
}
