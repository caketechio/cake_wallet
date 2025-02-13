import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cw_decred/api/libdcrwallet_bindings.dart';
import 'package:cw_decred/api/util.dart';

final int ErrCodeNotSynced = 1;

final String libraryName = Platform.isAndroid || Platform.isLinux // TODO: Linux.
    ? 'libdcrwallet.so'
    : 'cw_decred.framework/cw_decred';

final dcrwalletApi = libdcrwallet(DynamicLibrary.open(libraryName));

/// initLibdcrwallet initializes libdcrwallet using the provided logDir and gets
/// it ready for use. This must be done before attempting to create, load or use
/// a wallet.
void initLibdcrwallet(String logDir) {
  final cLogDir = logDir.toCString();
  executePayloadFn(
    fn: () => dcrwalletApi.initialize(cLogDir),
    ptrsToFree: [cLogDir],
  );
}

/// createWalletAsync calls the libdcrwallet's createWallet function
/// asynchronously.
Future<void> createWalletAsync(String config) {
  return compute(createWalletSync, config);
}

/// createWalletSync calls the libdcrwallet's createWallet function
/// synchronously.
void createWalletSync(String config) {
  final cConfig = config.toCString();

  executePayloadFn(
    fn: () => dcrwalletApi.createWallet(cConfig),
    ptrsToFree: [cConfig],
  );
}

void createWatchOnlyWallet(String config) {
  final cConfig = config.toCString();
  executePayloadFn(
    fn: () => dcrwalletApi.createWatchOnlyWallet(cConfig),
    ptrsToFree: [cConfig],
  );
}

/// loadWalletAsync calls the libdcrwallet's loadWallet function asynchronously.
Future<void> loadWalletAsync(String config) {
  return compute(loadWalletSync, config);
}

/// loadWalletSync calls the libdcrwallet's loadWallet function synchronously.
void loadWalletSync(String config) {
  final cConfig = config.toCString();
  executePayloadFn(
    fn: () => dcrwalletApi.loadWallet(cConfig),
    ptrsToFree: [cConfig],
  );
}

Future<void> startSyncAsync({required String name, required String peers}) {
  final args = <String, String>{
    "name": name,
    "peers": peers,
  };
  return compute(startSync, args);
}

void startSync(Map<String, String> args) {
  final name = args["name"]!.toCString();
  final peers = args["peers"]!.toCString();
  executePayloadFn(
    fn: () => dcrwalletApi.syncWallet(name, peers),
    ptrsToFree: [name, peers],
  );
}

void closeWallet(String walletName) {
  final name = walletName.toCString();
  executePayloadFn(
    fn: () => dcrwalletApi.closeWallet(name),
    ptrsToFree: [name],
  );
}

String changeWalletPassword(String walletName, String currentPassword, String newPassword) {
  final cName = walletName.toCString();
  final cCurrentPass = currentPassword.toCString();
  final cNewPass = newPassword.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.changePassphrase(cName, cCurrentPass, cNewPass),
    ptrsToFree: [cName, cCurrentPass, cNewPass],
  );
  return res.payload;
}

String? walletSeed(String walletName, String walletPassword) {
  final cName = walletName.toCString();
  final pass = walletPassword.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.walletSeed(cName, pass),
    ptrsToFree: [cName, pass],
  );
  return res.payload;
}

// NOTE: Currently unused.
// String? currentReceiveAddress(String walletName) {
//   final cName = walletName.toCString();
//   final res = executePayloadFn(
//     fn: () => dcrwalletApi.currentReceiveAddress(cName),
//     ptrsToFree: [cName],
//     skipErrorCheck: true, // errCode is checked below, before checking err
//   );
//
//   if (res.errCode == ErrCodeNotSynced) {
//     // Wallet is not synced. We do not want to give out a used address so give
//     // nothing.
//     return null;
//   }
//   checkErr(res.err);
//   return res.payload;
// }

String syncStatus(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.syncWalletStatus(cName),
    ptrsToFree: [cName],
  );
  return res.payload;
}

Map balance(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.walletBalance(cName),
    ptrsToFree: [cName],
  );
  return jsonDecode(res.payload);
}

String estimateFee(String walletName, int numBlocks) {
  final cName = walletName.toCString();
  final cNumBlocks = numBlocks.toString().toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.estimateFee(cName, cNumBlocks),
    ptrsToFree: [cName, cNumBlocks],
  );
  return res.payload;
}

String createSignedTransaction(String walletName, String createSignedTransactionReq) {
  final cName = walletName.toCString();
  final cCreateSignedTransactionReq = createSignedTransactionReq.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.createSignedTransaction(cName, cCreateSignedTransactionReq),
    ptrsToFree: [cName, cCreateSignedTransactionReq],
  );
  return res.payload;
}

String sendRawTransaction(String walletName, String txHex) {
  final cName = walletName.toCString();
  final cTxHex = txHex.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.sendRawTransaction(cName, cTxHex),
    ptrsToFree: [cName, cTxHex],
  );
  return res.payload;
}

String listTransactions(String walletName, String from, String count) {
  final cName = walletName.toCString();
  final cFrom = from.toCString();
  final cCount = count.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.listTransactions(cName, cFrom, cCount),
    ptrsToFree: [cName, cFrom, cCount],
  );
  return res.payload;
}

String bestBlock(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.bestBlock(cName),
    ptrsToFree: [cName],
  );
  return res.payload;
}

String listUnspents(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.listUnspents(cName),
    ptrsToFree: [cName],
  );
  return res.payload;
}

String rescanFromHeight(String walletName, String height) {
  final cName = walletName.toCString();
  final cHeight = height.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.rescanFromHeight(cName, cHeight),
    ptrsToFree: [cName, cHeight],
  );
  return res.payload;
}

Future<String> signMessageAsync(String name, String message, String address, String walletPass) {
  final args = <String, String>{
    "walletname": name,
    "message": message,
    "address": address,
    "walletpass": walletPass,
  };
  return compute(signMessage, args);
}

String signMessage(Map<String, String> args) {
  final cName = args["walletname"]!.toCString();
  final cMessage = args["message"]!.toCString();
  final cAddress = args["address"]!.toCString();
  final cPass = args["walletpass"]!.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.signMessage(cName, cMessage, cAddress, cPass),
    ptrsToFree: [cName, cMessage, cAddress, cPass],
  );
  return res.payload;
}

String verifyMessage(String name, String message, String address, String sig) {
  final cName = name.toCString();
  final cMessage = message.toCString();
  final cAddress = address.toCString();
  final cSig = sig.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.verifyMessage(cName, cMessage, cAddress, cSig),
    ptrsToFree: [cName, cMessage, cAddress, cSig],
  );
  return res.payload;
}

String? newExternalAddress(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.newExternalAddress(cName),
    ptrsToFree: [cName],
    skipErrorCheck: true, // errCode is checked below, before checking err
  );
  if (res.errCode == ErrCodeNotSynced) {
    // Wallet is not synced. We do not want to give out a used address so give
    // nothing.
    return null;
  }
  checkErr(res.err);
  return res.payload;
}

String defaultPubkey(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.defaultPubkey(cName),
    ptrsToFree: [cName],
  );
  return res.payload;
}

String addresses(String walletName, String nUsed, String nUnused) {
  final cName = walletName.toCString();
  final cNUsed = nUsed.toCString();
  final cNUnused = nUnused.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.addresses(cName, cNUsed, cNUnused),
    ptrsToFree: [cName],
  );
  return res.payload;
}

String birthState(String walletName) {
  final cName = walletName.toCString();
  final res = executePayloadFn(
    fn: () => dcrwalletApi.birthState(cName),
    ptrsToFree: [cName],
  );
  return res.payload;
}
