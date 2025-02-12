import 'package:cw_bitcoin/electrum_wallet.dart';
import 'package:grpc/grpc.dart';
import 'package:cw_bitcoin/exceptions.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:blockchain_utils/blockchain_utils.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_bitcoin/electrum.dart';
import 'package:cw_bitcoin/bitcoin_amount_format.dart';
import 'package:cw_bitcoin/electrum_transaction_info.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_mweb/cw_mweb.dart';
import 'package:cw_mweb/mwebd.pb.dart';

class PendingBitcoinTransaction with PendingTransaction {
  PendingBitcoinTransaction(
    this._tx,
    this.type, {
    required this.electrumClient,
    required this.amount,
    required this.fee,
    required this.feeRate,
    this.network,
    required this.hasChange,
    this.isSendAll = false,
    this.hasTaprootInputs = false,
    this.isMweb = false,
    this.utxos = const [],
    this.publicKeys,
    this.commitOverride,
  }) : _listeners = <void Function(ElectrumTransactionInfo transaction)>[];

  final WalletType type;
  final BtcTransaction _tx;
  final ElectrumClient electrumClient;
  final int amount;
  final int fee;
  final String feeRate;
  final BasedUtxoNetwork? network;
  final bool isSendAll;
  final bool hasChange;
  final bool hasTaprootInputs;
  List<UtxoWithAddress> utxos;
  bool isMweb;
  String? changeAddressOverride;
  String? idOverride;
  String? hexOverride;
  List<String>? outputAddresses;
  final Map<String, PublicKeyWithDerivationPath>? publicKeys;
  Future<void> Function()? commitOverride;

  @override
  String get id => idOverride ?? _tx.txId();

  @override
  String get hex => hexOverride ?? _tx.serialize();

  @override
  String get amountFormatted => bitcoinAmountToString(amount: amount);

  @override
  String get feeFormatted => bitcoinAmountToString(amount: fee);

  @override
  int? get outputCount => _tx.outputs.length;

  List<TxOutput> get outputs => _tx.outputs;

  bool get hasSilentPayment => _tx.hasSilentPayment;

  PendingChange? get change {
    try {
      final change = _tx.outputs.firstWhere((out) => out.isChange);
      if (changeAddressOverride != null) {
        return PendingChange(changeAddressOverride!, BtcUtils.fromSatoshi(change.amount));
      }
      return PendingChange(change.scriptPubKey.toAddress(), BtcUtils.fromSatoshi(change.amount));
    } catch (_) {
      return null;
    }
  }

  final List<void Function(ElectrumTransactionInfo transaction)> _listeners;

  Future<void> _commit() async {
    int? callId;

    final result = await electrumClient.broadcastTransaction(
        transactionRaw: hex, network: network, idCallback: (id) => callId = id);

    if (result.isEmpty) {
      if (callId != null) {
        final error = electrumClient.getErrorMessage(callId!);

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

      throw BitcoinTransactionCommitFailed();
    }
  }

  Future<void> _ltcCommit() async {
    try {
      final resp = await CwMweb.broadcast(BroadcastRequest(rawTx: BytesUtils.fromHexString(hex)));
      idOverride = resp.txid;
    } on GrpcError catch (e) {
      throw BitcoinTransactionCommitFailed(errorMessage: e.message);
    } catch (e) {
      throw BitcoinTransactionCommitFailed(errorMessage: "Unknown error: ${e.toString()}");
    }
  }

  @override
  Future<void> commit() async {
    if (commitOverride != null) {
      return commitOverride?.call();
    }

    if (isMweb) {
      await _ltcCommit();
    } else {
      await _commit();
    }

    _listeners.forEach((listener) => listener(transactionInfo()));
  }

  void addListener(void Function(ElectrumTransactionInfo transaction) listener) =>
      _listeners.add(listener);

  ElectrumTransactionInfo transactionInfo() => ElectrumTransactionInfo(type,
      id: id,
      height: 0,
      amount: amount,
      direction: TransactionDirection.outgoing,
      date: DateTime.now(),
      isPending: true,
      isReplaced: false,
      confirmations: 0,
      inputAddresses: _tx.inputs.map((input) => input.txId).toList(),
      outputAddresses: outputAddresses,
      fee: fee);
      
  @override
  Future<String?> commitUR() {
    throw UnimplementedError();
  }
}
