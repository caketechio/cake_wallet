import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_wownero/api/account_list.dart';
import 'package:cw_wownero/api/exceptions/creation_transaction_exception.dart';
import 'package:cw_wownero/api/wallet.dart';
import 'package:cw_wownero/api/wownero_output.dart';
import 'package:cw_wownero/api/structs/pending_transaction.dart';
import 'package:cw_wownero/exceptions/wownero_transaction_creation_exception.dart';
import 'package:ffi/ffi.dart';
import 'package:monero/wownero.dart' as wownero;
import 'package:monero/src/generated_bindings_wownero.g.dart' as wownero_gen;
import 'package:mutex/mutex.dart';

String getTxKey(String txId) {
  final ret = wownero.Wallet_getTxKey(wptr!, txid: txId);
  wownero.Wallet_status(wptr!);
  return ret;
}

final txHistoryMutex = Mutex();
wownero.TransactionHistory? txhistory;

bool isRefreshingTx = false;
Future<void> refreshTransactions() async {
  if (isRefreshingTx == true) return;
  isRefreshingTx = true;
  txhistory ??= wownero.Wallet_history(wptr!);
  final ptr = txhistory!.address;
  await txHistoryMutex.acquire();
  await Isolate.run(() {
    wownero.TransactionHistory_refresh(Pointer.fromAddress(ptr));
  });
  txHistoryMutex.release();
  isRefreshingTx = false;
}

int countOfTransactions() => wownero.TransactionHistory_count(txhistory!);

Future<List<Transaction>> getAllTransactions() async {
  List<Transaction> dummyTxs = [];

  await txHistoryMutex.acquire();
  txhistory ??= wownero.Wallet_history(wptr!);
  int size = countOfTransactions();
  final list = List.generate(size, (index) => Transaction(txInfo: wownero.TransactionHistory_transaction(txhistory!, index: index)));
  txHistoryMutex.release();
  
  final accts = wownero.Wallet_numSubaddressAccounts(wptr!);
  for (var i = 0; i < accts; i++) {  
    final fullBalance = wownero.Wallet_balance(wptr!, accountIndex: i);
    final availBalance = wownero.Wallet_unlockedBalance(wptr!, accountIndex: i);
    if (fullBalance > availBalance) {
      if (list.where((element) => element.accountIndex == i && element.isConfirmed == false).isEmpty) {
        dummyTxs.add(
          Transaction.dummy(
            displayLabel: "",
            description: "",
            fee: 0,
            confirmations: 0,
            blockheight: 0,
            accountIndex: i,
            addressIndex: 0,
            addressIndexList: [0],
            paymentId: "",
            amount: fullBalance - availBalance,
            isSpend: false,
            hash: "pending",
            key: "pending",
            txInfo: Pointer.fromAddress(0),
          )..timeStamp = DateTime.now()
        );
      }
    }
  }
  list.addAll(dummyTxs);
  return list;
}

// TODO(mrcyjanek): ...
Transaction getTransaction(String txId) {
  return Transaction(txInfo: wownero.TransactionHistory_transactionById(txhistory!, txid: txId));
}

Future<PendingTransactionDescription> createTransactionSync(
    {required String address,
    required String paymentId,
    required int priorityRaw,
    String? amount,
    int accountIndex = 0,
    List<String> preferredInputs = const []}) async {

  final amt = amount == null ? 0 : wownero.Wallet_amountFromString(amount);
  
  final address_ = address.toNativeUtf8(); 
  final paymentId_ = paymentId.toNativeUtf8();
  if (preferredInputs.isEmpty) {
    throw WowneroTransactionCreationException("No inputs provided, transaction cannot be constructed");
  }
  final preferredInputs_ = preferredInputs.join(wownero.defaultSeparatorStr).toNativeUtf8();

  final waddr = wptr!.address;
  final addraddr = address_.address;
  final paymentIdAddr = paymentId_.address;
  final preferredInputsAddr = preferredInputs_.address;
  final spaddr = wownero.defaultSeparator.address;
  final pendingTx = Pointer<Void>.fromAddress(await Isolate.run(() {
    final tx = wownero_gen.WowneroC(DynamicLibrary.open(wownero.libPath)).WOWNERO_Wallet_createTransaction(
      Pointer.fromAddress(waddr),
      Pointer.fromAddress(addraddr).cast(),
      Pointer.fromAddress(paymentIdAddr).cast(),
      amt,
      1,
      priorityRaw,
      accountIndex,
      Pointer.fromAddress(preferredInputsAddr).cast(),
      Pointer.fromAddress(spaddr),
    );
    return tx.address;
  }));
  calloc.free(address_);
  calloc.free(paymentId_);
  calloc.free(preferredInputs_);
  final String? error = (() {
    final status = wownero.PendingTransaction_status(pendingTx);
    if (status == 0) {
      return null;
    }
    return wownero.PendingTransaction_errorString(pendingTx);
  })();

  if (error != null) {
    final message = error;
    throw CreationTransactionException(message: message);
  }

  final rAmt = wownero.PendingTransaction_amount(pendingTx);
  final rFee = wownero.PendingTransaction_fee(pendingTx);
  final rHash = wownero.PendingTransaction_txid(pendingTx, '');
  final rTxKey = rHash;

  return PendingTransactionDescription(
      amount: rAmt,
      fee: rFee,
      hash: rHash,
      hex: '',
      txKey: rTxKey,
      pointerAddress: pendingTx.address,
    );
}

PendingTransactionDescription createTransactionMultDestSync(
    {required List<WowneroOutput> outputs,
    required String paymentId,
    required int priorityRaw,
    int accountIndex = 0,
    List<String> preferredInputs = const []}) {
  
  final txptr = wownero.Wallet_createTransactionMultDest(
    wptr!,
    dstAddr: outputs.map((e) => e.address).toList(),
    isSweepAll: false,
    amounts: outputs.map((e) => wownero.Wallet_amountFromString(e.amount)).toList(),
    mixinCount: 0,
    pendingTransactionPriority: priorityRaw,
    subaddr_account: accountIndex,
  );
  if (wownero.PendingTransaction_status(txptr) != 0) {
    throw CreationTransactionException(message: wownero.PendingTransaction_errorString(txptr));
  }
  return PendingTransactionDescription(
    amount: wownero.PendingTransaction_amount(txptr),
    fee: wownero.PendingTransaction_fee(txptr),
    hash: wownero.PendingTransaction_txid(txptr, ''),
    hex: wownero.PendingTransaction_txid(txptr, ''),
    txKey: wownero.PendingTransaction_txid(txptr, ''),
    pointerAddress: txptr.address,
  );
}

void commitTransactionFromPointerAddress({required int address}) =>
    commitTransaction(transactionPointer: wownero.PendingTransaction.fromAddress(address));

void commitTransaction({required wownero.PendingTransaction transactionPointer}) {
  
  final txCommit = wownero.PendingTransaction_commit(transactionPointer, filename: '', overwrite: false);

  String? error = (() {
    final status = wownero.PendingTransaction_status(transactionPointer.cast());
    if (status == 0) {
      return null;
    }
    return wownero.PendingTransaction_errorString(transactionPointer.cast());
  })();
  if (error == null) {
    error = (() {
      final status = wownero.Wallet_status(wptr!);
      if (status == 0) {
        return null;
      }
      return wownero.Wallet_errorString(wptr!);
    })();

  }
  
  if (error != null) {
    throw CreationTransactionException(message: error);
  }
}

Future<PendingTransactionDescription> _createTransactionSync(Map args) async {
  final address = args['address'] as String;
  final paymentId = args['paymentId'] as String;
  final amount = args['amount'] as String?;
  final priorityRaw = args['priorityRaw'] as int;
  final accountIndex = args['accountIndex'] as int;
  final preferredInputs = args['preferredInputs'] as List<String>;

  return createTransactionSync(
      address: address,
      paymentId: paymentId,
      amount: amount,
      priorityRaw: priorityRaw,
      accountIndex: accountIndex,
      preferredInputs: preferredInputs);
}

PendingTransactionDescription _createTransactionMultDestSync(Map args) {
  final outputs = args['outputs'] as List<WowneroOutput>;
  final paymentId = args['paymentId'] as String;
  final priorityRaw = args['priorityRaw'] as int;
  final accountIndex = args['accountIndex'] as int;
  final preferredInputs = args['preferredInputs'] as List<String>;

  return createTransactionMultDestSync(
      outputs: outputs,
      paymentId: paymentId,
      priorityRaw: priorityRaw,
      accountIndex: accountIndex,
      preferredInputs: preferredInputs);
}

Future<PendingTransactionDescription> createTransaction(
        {required String address,
        required int priorityRaw,
        String? amount,
        String paymentId = '',
        int accountIndex = 0,
        List<String> preferredInputs = const []}) async =>
    _createTransactionSync({
      'address': address,
      'paymentId': paymentId,
      'amount': amount,
      'priorityRaw': priorityRaw,
      'accountIndex': accountIndex,
      'preferredInputs': preferredInputs
    });

Future<PendingTransactionDescription> createTransactionMultDest(
        {required List<WowneroOutput> outputs,
        required int priorityRaw,
        String paymentId = '',
        int accountIndex = 0,
        List<String> preferredInputs = const []}) async =>
    _createTransactionMultDestSync({
      'outputs': outputs,
      'paymentId': paymentId,
      'priorityRaw': priorityRaw,
      'accountIndex': accountIndex,
      'preferredInputs': preferredInputs
    });


class Transaction {
  final String displayLabel;
  late final String subaddressLabel = wownero.Wallet_getSubaddressLabel(wptr!, accountIndex: accountIndex, addressIndex: addressIndex);
  late final String address = getAddress(
    accountIndex: accountIndex,
    addressIndex: addressIndex,
  );
  late final List<String> addressList = List.generate(addressIndexList.length, (index) =>
    getAddress(
      accountIndex: accountIndex,
      addressIndex: addressIndexList[index],
    ));
  final String description;
  final int fee;
  final int confirmations;
  late final bool isPending = confirmations < 3;
  final int blockheight;
  final int addressIndex;
  final int accountIndex;
  final List<int> addressIndexList;
  final String paymentId;
  final int amount;
  final bool isSpend;
  late final DateTime timeStamp;
  late final bool isConfirmed = !isPending;
  final String hash;
  final String key;

  Map<String, dynamic> toJson() {
    return {
      "displayLabel": displayLabel,
      "subaddressLabel": subaddressLabel,
      "address": address,
      "description": description,
      "fee": fee,
      "confirmations": confirmations,
      "isPending": isPending,
      "blockheight": blockheight,
      "accountIndex": accountIndex,
      "addressIndex": addressIndex,
      "paymentId": paymentId,
      "amount": amount,
      "isSpend": isSpend,
      "timeStamp": timeStamp.toIso8601String(),
      "isConfirmed": isConfirmed,
      "hash": hash,
    };
  }

  // final SubAddress? subAddress;
  // List<Transfer> transfers = [];
  // final int txIndex;
  final wownero.TransactionInfo txInfo;
  Transaction({
    required this.txInfo,
  })  : displayLabel = wownero.TransactionInfo_label(txInfo),
        hash = wownero.TransactionInfo_hash(txInfo),
        timeStamp = DateTime.fromMillisecondsSinceEpoch(
          wownero.TransactionInfo_timestamp(txInfo) * 1000,
        ),
        isSpend = wownero.TransactionInfo_direction(txInfo) ==
            wownero.TransactionInfo_Direction.Out,
        amount = wownero.TransactionInfo_amount(txInfo),
        paymentId = wownero.TransactionInfo_paymentId(txInfo),
        accountIndex = wownero.TransactionInfo_subaddrAccount(txInfo),
        addressIndex = int.tryParse(wownero.TransactionInfo_subaddrIndex(txInfo).split(", ")[0]) ?? 0,
        addressIndexList = wownero.TransactionInfo_subaddrIndex(txInfo).split(", ").map((e) => int.tryParse(e) ?? 0).toList(),
        blockheight = wownero.TransactionInfo_blockHeight(txInfo),
        confirmations = wownero.TransactionInfo_confirmations(txInfo),
        fee = wownero.TransactionInfo_fee(txInfo),
        description = wownero.TransactionInfo_description(txInfo),
        key = wownero.Wallet_getTxKey(wptr!, txid: wownero.TransactionInfo_hash(txInfo));

  Transaction.dummy({
    required this.displayLabel,
    required this.description,
    required this.fee,
    required this.confirmations,
    required this.blockheight,
    required this.accountIndex,
    required this.addressIndex,
    required this.addressIndexList,
    required this.paymentId,
    required this.amount,
    required this.isSpend,
    required this.hash,
    required this.key,
    required this.txInfo
  });
}
