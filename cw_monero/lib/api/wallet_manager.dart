import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_monero/api/account_list.dart';
import 'package:cw_monero/api/exceptions/wallet_creation_exception.dart';
import 'package:cw_monero/api/exceptions/wallet_opening_exception.dart';
import 'package:cw_monero/api/exceptions/wallet_restore_from_keys_exception.dart';
import 'package:cw_monero/api/exceptions/wallet_restore_from_seed_exception.dart';
import 'package:cw_monero/api/transaction_history.dart';
import 'package:cw_monero/api/wallet.dart';
import 'package:cw_monero/ledger.dart';
import 'package:monero/monero.dart' as monero;

class MoneroCException implements Exception {
  final String message;

  MoneroCException(this.message);

  @override
  String toString() => message;
}

void checkIfMoneroCIsFine() {
  final cppCsCpp = monero.MONERO_checksum_wallet2_api_c_cpp();
  final cppCsH = monero.MONERO_checksum_wallet2_api_c_h();
  final cppCsExp = monero.MONERO_checksum_wallet2_api_c_exp();

  final dartCsCpp = monero.wallet2_api_c_cpp_sha256;
  final dartCsH = monero.wallet2_api_c_h_sha256;
  final dartCsExp = monero.wallet2_api_c_exp_sha256;

  if (cppCsCpp != dartCsCpp) {
    throw MoneroCException("monero_c and monero.dart cpp wrapper code mismatch.\nLogic errors can occur.\nRefusing to run in release mode.\ncpp: '$cppCsCpp'\ndart: '$dartCsCpp'");
  }

  if (cppCsH != dartCsH) {
    throw MoneroCException("monero_c and monero.dart cpp wrapper header mismatch.\nLogic errors can occur.\nRefusing to run in release mode.\ncpp: '$cppCsH'\ndart: '$dartCsH'");
  }

  if (cppCsExp != dartCsExp && (Platform.isIOS || Platform.isMacOS)) {
    throw MoneroCException("monero_c and monero.dart wrapper export list mismatch.\nLogic errors can occur.\nRefusing to run in release mode.\ncpp: '$cppCsExp'\ndart: '$dartCsExp'");
  }
}
monero.WalletManager? _wmPtr;
final monero.WalletManager wmPtr = Pointer.fromAddress((() {
  try {
    // Problems with the wallet? Crashes? Lags? this will print all calls to xmr
    // codebase, so it will be easier to debug what happens. At least easier
    // than plugging gdb in. Especially on windows/android.
    monero.printStarts = false;
    _wmPtr ??= monero.WalletManagerFactory_getWalletManager();
    printV("ptr: $_wmPtr");
  } catch (e) {
    printV(e);
    rethrow;
  }
  return _wmPtr!.address;
})());

void createWalletPointer() {
  final newWptr = monero.WalletManager_createWallet(wmPtr,
      path: "", password: "", language: "", networkType: 0);

  wptr = newWptr;
}

void createWalletSync(
    {required String path,
    required String password,
    required String language,
    int nettype = 0}) {
  txhistory = null;
  final newWptr = monero.WalletManager_createWallet(wmPtr,
      path: path, password: password, language: language, networkType: 0);

  final status = monero.Wallet_status(newWptr);
  if (status != 0) {
    throw WalletCreationException(message: monero.Wallet_errorString(newWptr));
  }
  wptr = newWptr;
  monero.Wallet_store(wptr!, path: path);
  openedWalletsByPath[path] = wptr!;
  _lastOpenedWallet = path;

  // is the line below needed?
  // setupNodeSync(address: "node.moneroworld.com:18089");
}

bool isWalletExistSync({required String path}) {
  return monero.WalletManager_walletExists(wmPtr, path);
}

void restoreWalletFromSeedSync(
    {required String path,
    required String password,
    required String passphrase,
    required String seed,
    int nettype = 0,
    int restoreHeight = 0}) async {
  txhistory = null;
  final newWptr = monero.WalletManager_recoveryWallet(
    wmPtr,
    path: path,
    password: password,
    mnemonic: seed,
    restoreHeight: restoreHeight,
    seedOffset: passphrase,
    networkType: 0,
  );

  final status = monero.Wallet_status(newWptr);

  if (status != 0) {
    final error = monero.Wallet_errorString(newWptr);
    throw WalletRestoreFromSeedException(message: error);
  }
  wptr = newWptr;

  setRefreshFromBlockHeight(height: restoreHeight);

  monero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.passphrase", value: passphrase);

  openedWalletsByPath[path] = wptr!;

  monero.Wallet_store(wptr!);
  _lastOpenedWallet = path;
}

void restoreWalletFromKeysSync(
    {required String path,
    required String password,
    required String language,
    required String address,
    required String viewKey,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0}) {
  txhistory = null;
  var newWptr = (spendKey != "")
      ? monero.WalletManager_createDeterministicWalletFromSpendKey(wmPtr,
          path: path,
          password: password,
          language: language,
          spendKeyString: spendKey,
          newWallet: true,
          // TODO(mrcyjanek): safe to remove
          restoreHeight: restoreHeight)
      : monero.WalletManager_createWalletFromKeys(
          wmPtr,
          path: path,
          password: password,
          restoreHeight: restoreHeight,
          addressString: address,
          viewKeyString: viewKey,
          spendKeyString: spendKey,
          nettype: 0,
        );

  final status = monero.Wallet_status(newWptr);
  if (status != 0) {
    throw WalletRestoreFromKeysException(
        message: monero.Wallet_errorString(newWptr));
  }

  // CW-712 - Try to restore deterministic wallet first, if the view key doesn't
  // match the view key provided
  if (spendKey != "") {
    final viewKeyRestored = monero.Wallet_secretViewKey(newWptr);
    if (viewKey != viewKeyRestored && viewKey != "") {
      monero.WalletManager_closeWallet(wmPtr, newWptr, false);
      File(path).deleteSync();
      File(path + ".keys").deleteSync();
      newWptr = monero.WalletManager_createWalletFromKeys(
        wmPtr,
        path: path,
        password: password,
        restoreHeight: restoreHeight,
        addressString: address,
        viewKeyString: viewKey,
        spendKeyString: spendKey,
        nettype: 0,
      );
      final status = monero.Wallet_status(newWptr);
      if (status != 0) {
        throw WalletRestoreFromKeysException(
            message: monero.Wallet_errorString(newWptr));
      }
    }
  }

  wptr = newWptr;

  openedWalletsByPath[path] = wptr!;
  _lastOpenedWallet = path;
}


// English only, because normalization.
void restoreWalletFromPolyseedWithOffset(
    {required String path,
    required String password,
    required String seed,
    required String seedOffset,
    required String language,
    int nettype = 0}) {

  txhistory = null;
  final newWptr = monero.WalletManager_createWalletFromPolyseed(
    wmPtr,
    path: path,
    password: password,
    networkType: nettype,
    mnemonic: seed,
    seedOffset: seedOffset,
    newWallet: true, // safe to remove
    restoreHeight: 0,
    kdfRounds: 1,
  );

  final status = monero.Wallet_status(newWptr);

  if (status != 0) {
    final err = monero.Wallet_errorString(newWptr);
    printV("err: $err");
    throw WalletRestoreFromKeysException(message: err);
  }

  wptr = newWptr;

  monero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);
  monero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.passphrase", value: seedOffset);
  monero.Wallet_store(wptr!);
  storeSync();

  openedWalletsByPath[path] = wptr!;
}


void restoreWalletFromSpendKeySync(
    {required String path,
    required String password,
    required String seed,
    required String language,
    required String spendKey,
    int nettype = 0,
    int restoreHeight = 0}) {
  // txhistory = null;
  // wptr = monero.WalletManager_createWalletFromKeys(
  //   wmPtr,
  //   path: path,
  //   password: password,
  //   restoreHeight: restoreHeight,
  //   addressString: '',
  //   spendKeyString: spendKey,
  //   viewKeyString: '',
  //   nettype: 0,
  // );

  txhistory = null;
  final newWptr = monero.WalletManager_createDeterministicWalletFromSpendKey(
    wmPtr,
    path: path,
    password: password,
    language: language,
    spendKeyString: spendKey,
    newWallet: true, // TODO(mrcyjanek): safe to remove
    restoreHeight: restoreHeight,
  );

  final status = monero.Wallet_status(newWptr);

  if (status != 0) {
    final err = monero.Wallet_errorString(newWptr);
    printV("err: $err");
    throw WalletRestoreFromKeysException(message: err);
  }

  wptr = newWptr;

  monero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);

  storeSync();

  openedWalletsByPath[path] = wptr!;
  _lastOpenedWallet = path;
}

String _lastOpenedWallet = "";

Future<void> restoreWalletFromHardwareWallet(
    {required String path,
    required String password,
    required String deviceName,
    int nettype = 0,
    int restoreHeight = 0}) async {
  txhistory = null;

  final newWptrAddr = await Isolate.run(() {
    return monero.WalletManager_createWalletFromDevice(wmPtr,
            path: path,
            password: password,
            restoreHeight: restoreHeight,
            deviceName: deviceName)
        .address;
  });
  final newWptr = Pointer<Void>.fromAddress(newWptrAddr);

  final status = monero.Wallet_status(newWptr);

  if (status != 0) {
    final error = monero.Wallet_errorString(newWptr);
    throw WalletRestoreFromSeedException(message: error);
  }
  wptr = newWptr;
  _lastOpenedWallet = path;
  openedWalletsByPath[path] = wptr!;
}

Map<String, monero.wallet> openedWalletsByPath = {};

Future<void> loadWallet(
    {required String path, required String password, int nettype = 0}) async {
  if (openedWalletsByPath[path] != null) {
    txhistory = null;
    wptr = openedWalletsByPath[path]!;
    return;
  }
  if (wptr == null || path != _lastOpenedWallet) {
    if (wptr != null) {
      final addr = wptr!.address;
      Isolate.run(() {
        monero.Wallet_store(Pointer.fromAddress(addr));
      });
    }
    txhistory = null;

    /// Get the device type
    /// 0: Software Wallet
    /// 1: Ledger
    /// 2: Trezor
    late final deviceType;

    if (Platform.isAndroid || Platform.isIOS) {
      deviceType = monero.WalletManager_queryWalletDevice(
        wmPtr,
        keysFileName: "$path.keys",
        password: password,
        kdfRounds: 1,
      );
      final status = monero.WalletManager_errorString(wmPtr);
      if (status != "") {
        printV("loadWallet:"+status);
        throw WalletOpeningException(message: status);
      }
    } else {
      deviceType = 0;
    }

    if (deviceType == 1) {
      final dummyWPtr = wptr ??
          monero.WalletManager_openWallet(wmPtr, path: '', password: '');
      enableLedgerExchange(dummyWPtr, gLedger!);
    }

    final addr = wmPtr.address;
    final newWptrAddr = await Isolate.run(() {
      return monero.WalletManager_openWallet(Pointer.fromAddress(addr),
              path: path, password: password)
          .address;
    });

    final newWptr = Pointer<Void>.fromAddress(newWptrAddr);

    final status = monero.Wallet_status(newWptr);
    if (status != 0) {
      final err = monero.Wallet_errorString(newWptr);
      printV("loadWallet:"+err);
      throw WalletOpeningException(message: err);
    }

    wptr = newWptr;
    _lastOpenedWallet = path;
    openedWalletsByPath[path] = wptr!;
  }
}

void _createWallet(Map<String, dynamic> args) {
  final path = args['path'] as String;
  final password = args['password'] as String;
  final language = args['language'] as String;

  createWalletSync(path: path, password: password, language: language);
}

void _restoreFromSeed(Map<String, dynamic> args) {
  final path = args['path'] as String;
  final password = args['password'] as String;
  final passphrase = args['passphrase'] as String;
  final seed = args['seed'] as String;
  final restoreHeight = args['restoreHeight'] as int;

  restoreWalletFromSeedSync(
      path: path, password: password, passphrase: passphrase, seed: seed, restoreHeight: restoreHeight);
}

void _restoreFromKeys(Map<String, dynamic> args) {
  final path = args['path'] as String;
  final password = args['password'] as String;
  final language = args['language'] as String;
  final restoreHeight = args['restoreHeight'] as int;
  final address = args['address'] as String;
  final viewKey = args['viewKey'] as String;
  final spendKey = args['spendKey'] as String;

  restoreWalletFromKeysSync(
      path: path,
      password: password,
      language: language,
      restoreHeight: restoreHeight,
      address: address,
      viewKey: viewKey,
      spendKey: spendKey);
}

void _restoreFromSpendKey(Map<String, dynamic> args) {
  final path = args['path'] as String;
  final password = args['password'] as String;
  final seed = args['seed'] as String;
  final language = args['language'] as String;
  final spendKey = args['spendKey'] as String;
  final restoreHeight = args['restoreHeight'] as int;

  restoreWalletFromSpendKeySync(
      path: path,
      password: password,
      seed: seed,
      language: language,
      restoreHeight: restoreHeight,
      spendKey: spendKey);
}

Future<void> _openWallet(Map<String, String> args) async => loadWallet(
    path: args['path'] as String, password: args['password'] as String);

bool _isWalletExist(String path) => isWalletExistSync(path: path);

Future<void> openWallet(
        {required String path,
        required String password,
        int nettype = 0}) async =>
    loadWallet(path: path, password: password, nettype: nettype);

Future<void> openWalletAsync(Map<String, String> args) async =>
    _openWallet(args);

Future<void> createWallet(
        {required String path,
        required String password,
        required String language,
        int nettype = 0}) async =>
    _createWallet({
      'path': path,
      'password': password,
      'language': language,
      'nettype': nettype
    });

Future<void> restoreFromSeed(
        {required String path,
        required String password,
        required String passphrase,
        required String seed,
        int nettype = 0,
        int restoreHeight = 0}) async =>
    _restoreFromSeed({
      'path': path,
      'password': password,
      'passphrase': passphrase,
      'seed': seed,
      'nettype': nettype,
      'restoreHeight': restoreHeight
    });

Future<void> restoreFromKeys(
        {required String path,
        required String password,
        required String language,
        required String address,
        required String viewKey,
        required String spendKey,
        int nettype = 0,
        int restoreHeight = 0}) async =>
    _restoreFromKeys({
      'path': path,
      'password': password,
      'language': language,
      'address': address,
      'viewKey': viewKey,
      'spendKey': spendKey,
      'nettype': nettype,
      'restoreHeight': restoreHeight
    });

Future<void> restoreFromSpendKey(
        {required String path,
        required String password,
        required String seed,
        required String language,
        required String spendKey,
        int nettype = 0,
        int restoreHeight = 0}) async =>
    _restoreFromSpendKey({
      'path': path,
      'password': password,
      'seed': seed,
      'language': language,
      'spendKey': spendKey,
      'nettype': nettype,
      'restoreHeight': restoreHeight
    });

bool isWalletExist({required String path}) => _isWalletExist(path);

bool isViewOnlyBySpendKey() => int.tryParse(monero.Wallet_secretSpendKey(wptr!)) == 0;