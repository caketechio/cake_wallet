import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_wownero/api/account_list.dart';
import 'package:cw_wownero/api/exceptions/setup_wallet_exception.dart';
import 'package:monero/wownero.dart' as wownero;
import 'package:mutex/mutex.dart';

int getSyncingHeight() {
  // final height = wownero.WOWNERO_cw_WalletListener_height(getWlptr());
  final h2 = wownero.Wallet_blockChainHeight(wptr!);
  // printV("height: $height / $h2");
  return h2;
}

bool isNeededToRefresh() {
  // final ret = wownero.WOWNERO_cw_WalletListener_isNeedToRefresh(getWlptr());
  // wownero.WOWNERO_cw_WalletListener_resetNeedToRefresh(getWlptr());
  return true;
}

bool isNewTransactionExist() {
  // final ret =
  //     wownero.WOWNERO_cw_WalletListener_isNewTransactionExist(getWlptr());
  // wownero.WOWNERO_cw_WalletListener_resetIsNewTransactionExist(getWlptr());
  // NOTE: I don't know why wownero is being funky, but
  return true;
}

String getFilename() => wownero.Wallet_filename(wptr!);

String getSeed() {
  // wownero.Wallet_setCacheAttribute(wptr!, key: "cakewallet.seed", value: seed);
  final cakepolyseed = wownero.Wallet_getCacheAttribute(wptr!, key: "cakewallet.seed");
  if (cakepolyseed != "") {
    return cakepolyseed;
  }
  final polyseed = wownero.Wallet_getPolyseed(wptr!, passphrase: '');
  if (polyseed != "") {
    return polyseed;
  }
  final legacy = getSeedLegacy(null);
  return legacy;
}

String getSeedLegacy(String? language) {
  var legacy = wownero.Wallet_seed(wptr!, seedOffset: '');
  switch (language) {
    case "Chinese (Traditional)":
      language = "Chinese (simplified)";
      break;
    case "Chinese (Simplified)":
      language = "Chinese (simplified)";
      break;
    case "Korean":
      language = "English";
      break;
    case "Czech":
      language = "English";
      break;
    case "Japanese":
      language = "English";
      break;
  }
  if (wownero.Wallet_status(wptr!) != 0) {
    wownero.Wallet_setSeedLanguage(wptr!, language: language ?? "English");
    legacy = wownero.Wallet_seed(wptr!, seedOffset: '');
  }
  if (wownero.Wallet_status(wptr!) != 0) {
    final err = wownero.Wallet_errorString(wptr!);
    if (legacy.isNotEmpty) {
      return "$err\n\n$legacy";
    }
    return err;
  }
  return legacy;
}

Map<int, Map<int, Map<int, String>>> addressCache = {};

String getAddress({int accountIndex = 0, int addressIndex = 1}) {
  while (wownero.Wallet_numSubaddresses(wptr!, accountIndex: accountIndex) - 1 < addressIndex) {
    printV("adding subaddress");
    wownero.Wallet_addSubaddress(wptr!, accountIndex: accountIndex);
  }
  addressCache[wptr!.address] ??= {};
  addressCache[wptr!.address]![accountIndex] ??= {};
  addressCache[wptr!.address]![accountIndex]![addressIndex] ??=
      wownero.Wallet_address(wptr!, accountIndex: accountIndex, addressIndex: addressIndex);
  return addressCache[wptr!.address]![accountIndex]![addressIndex]!;
}

int getFullBalance({int accountIndex = 0}) =>
    wownero.Wallet_balance(wptr!, accountIndex: accountIndex);

int getUnlockedBalance({int accountIndex = 0}) =>
    wownero.Wallet_unlockedBalance(wptr!, accountIndex: accountIndex);

int getCurrentHeight() => wownero.Wallet_blockChainHeight(wptr!);

int getNodeHeightSync() => wownero.Wallet_daemonBlockChainHeight(wptr!);

bool isConnectedSync() => wownero.Wallet_connected(wptr!) != 0;

Future<bool> setupNodeSync(
    {required String address,
    String? login,
    String? password,
    bool useSSL = false,
    bool isLightWallet = false,
    String? socksProxyAddress}) async {
  printV('''
{
  wptr!,
  daemonAddress: $address,
  useSsl: $useSSL,
  proxyAddress: $socksProxyAddress ?? '',
  daemonUsername: $login ?? '',
  daemonPassword: $password ?? ''
}
''');
  final addr = wptr!.address;
  await Isolate.run(() {
    wownero.Wallet_init(Pointer.fromAddress(addr),
        daemonAddress: address,
        useSsl: useSSL,
        proxyAddress: socksProxyAddress ?? '',
        daemonUsername: login ?? '',
        daemonPassword: password ?? '');
  });
  // wownero.Wallet_init3(wptr!, argv0: '', defaultLogBaseName: 'wowneroc', console: true);

  final status = wownero.Wallet_status(wptr!);

  if (status != 0) {
    final error = wownero.Wallet_errorString(wptr!);
    printV("error: $error");
    throw SetupWalletException(message: error);
  }

  return status == 0;
}

void startRefreshSync() {
  wownero.Wallet_refreshAsync(wptr!);
  wownero.Wallet_startRefresh(wptr!);
}

void setupBackgroundSync(
    {required int backgroundSyncType,
    required String walletPassword,
    required String backgroundCachePassword}) {
  wownero.Wallet_setupBackgroundSync(wptr!,
      backgroundSyncType: backgroundSyncType,
      walletPassword: walletPassword,
      backgroundCachePassword: backgroundCachePassword);
}

void startBackgroundSync() {
  wownero.Wallet_startBackgroundSync(wptr!);
}

void stopBackgroundSync(String password) {
  wownero.Wallet_stopBackgroundSync(wptr!, password);
}

Future<bool> connectToNode() async {
  return true;
}

void setRefreshFromBlockHeight({required int height}) =>
    wownero.Wallet_setRefreshFromBlockHeight(wptr!, refresh_from_block_height: height);

void setRecoveringFromSeed({required bool isRecovery}) =>
    wownero.Wallet_setRecoveringFromSeed(wptr!, recoveringFromSeed: isRecovery);

final storeMutex = Mutex();

int lastStorePointer = 0;
int lastStoreHeight = 0;
void storeSync() async {
  final addr = wptr!.address;
  final synchronized = await Isolate.run(() {
    return wownero.Wallet_synchronized(Pointer.fromAddress(addr));
  });
  if (lastStorePointer == wptr!.address &&
      lastStoreHeight + 5000 < wownero.Wallet_blockChainHeight(wptr!) &&
      !synchronized) {
    return;
  }
  lastStorePointer = wptr!.address;
  lastStoreHeight = wownero.Wallet_blockChainHeight(wptr!);
  await storeMutex.acquire();
  Isolate.run(() {
    wownero.Wallet_store(Pointer.fromAddress(addr));
  });
  storeMutex.release();
}

void setPasswordSync(String password) {
  wownero.Wallet_setPassword(wptr!, password: password);

  final status = wownero.Wallet_status(wptr!);
  if (status != 0) {
    throw Exception(wownero.Wallet_errorString(wptr!));
  }
}

void closeCurrentWallet() {
  wownero.Wallet_stop(wptr!);
}

String getSecretViewKey() => wownero.Wallet_secretViewKey(wptr!);

String getPublicViewKey() => wownero.Wallet_publicViewKey(wptr!);

String getSecretSpendKey() => wownero.Wallet_secretSpendKey(wptr!);

String getPublicSpendKey() => wownero.Wallet_publicSpendKey(wptr!);

class SyncListener {
  SyncListener(this.onNewBlock, this.onNewTransaction)
      : _cachedBlockchainHeight = 0,
        _lastKnownBlockHeight = 0,
        _initialSyncHeight = 0;

  void Function(int, int, double) onNewBlock;
  void Function() onNewTransaction;

  Timer? _updateSyncInfoTimer;
  int _cachedBlockchainHeight;
  int _lastKnownBlockHeight;
  int _initialSyncHeight;

  Future<int> getNodeHeightOrUpdate(int baseHeight) async {
    if (_cachedBlockchainHeight < baseHeight || _cachedBlockchainHeight == 0) {
      _cachedBlockchainHeight = await getNodeHeight();
    }

    return _cachedBlockchainHeight;
  }

  void start() {
    _cachedBlockchainHeight = 0;
    _lastKnownBlockHeight = 0;
    _initialSyncHeight = 0;
    _updateSyncInfoTimer ??= Timer.periodic(Duration(milliseconds: 1200), (_) async {
      if (isNewTransactionExist()) {
        onNewTransaction();
      }

      var syncHeight = getSyncingHeight();

      if (syncHeight <= 0) {
        syncHeight = getCurrentHeight();
      }

      if (_initialSyncHeight <= 0) {
        _initialSyncHeight = syncHeight;
      }

      final bchHeight = await getNodeHeightOrUpdate(syncHeight);

      if (_lastKnownBlockHeight == syncHeight) {
        return;
      }

      _lastKnownBlockHeight = syncHeight;
      final track = bchHeight - _initialSyncHeight;
      final diff = track - (bchHeight - syncHeight);
      final ptc = diff <= 0 ? 0.0 : diff / track;
      final left = bchHeight - syncHeight;

      if (syncHeight < 0 || left < 0) {
        return;
      }

      // 1. Actual new height; 2. Blocks left to finish; 3. Progress in percents;
      onNewBlock.call(syncHeight, left, ptc);
    });
  }

  void stop() => _updateSyncInfoTimer?.cancel();
}

SyncListener setListeners(
    void Function(int, int, double) onNewBlock, void Function() onNewTransaction) {
  final listener = SyncListener(onNewBlock, onNewTransaction);
  // setListenerNative();
  return listener;
}

void onStartup() {}

void _storeSync(Object _) => storeSync();

Future<bool> _setupNodeSync(Map<String, Object?> args) async {
  final address = args['address'] as String;
  final login = (args['login'] ?? '') as String;
  final password = (args['password'] ?? '') as String;
  final useSSL = args['useSSL'] as bool;
  final isLightWallet = args['isLightWallet'] as bool;
  final socksProxyAddress = (args['socksProxyAddress'] ?? '') as String;

  return setupNodeSync(
      address: address,
      login: login,
      password: password,
      useSSL: useSSL,
      isLightWallet: isLightWallet,
      socksProxyAddress: socksProxyAddress);
}

bool _isConnected(Object _) => isConnectedSync();

int _getNodeHeight(Object _) => getNodeHeightSync();

void startRefresh() => startRefreshSync();

Future<void> setupNode(
        {required String address,
        String? login,
        String? password,
        bool useSSL = false,
        String? socksProxyAddress,
        bool isLightWallet = false}) async =>
    _setupNodeSync({
      'address': address,
      'login': login,
      'password': password,
      'useSSL': useSSL,
      'isLightWallet': isLightWallet,
      'socksProxyAddress': socksProxyAddress
    });

Future<void> store() async => _storeSync(0);

Future<bool> isConnected() async => _isConnected(0);

Future<int> getNodeHeight() async => _getNodeHeight(0);

void rescanBlockchainAsync() => wownero.Wallet_rescanBlockchainAsync(wptr!);

String getSubaddressLabel(int accountIndex, int addressIndex) {
  return wownero.Wallet_getSubaddressLabel(wptr!,
      accountIndex: accountIndex, addressIndex: addressIndex);
}

Future setTrustedDaemon(bool trusted) async => wownero.Wallet_setTrustedDaemon(wptr!, arg: trusted);

Future<bool> trustedDaemon() async => wownero.Wallet_trustedDaemon(wptr!);

String signMessage(String message, {String address = ""}) {
  return wownero.Wallet_signMessage(wptr!, message: message, address: address);
}

bool verifyMessage(String message, String address, String signature) {
  return wownero.Wallet_verifySignedMessage(wptr!,
      message: message, address: address, signature: signature);
}
