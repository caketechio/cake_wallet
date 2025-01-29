import 'dart:convert' as convert;
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/zano_asset.dart';
import 'package:cw_zano/api/consts.dart';
import 'package:cw_zano/api/model/asset_id_params.dart';
import 'package:cw_zano/api/model/create_wallet_result.dart';
import 'package:cw_zano/api/model/destination.dart';
import 'package:cw_zano/api/model/get_address_info_result.dart';
import 'package:cw_zano/api/model/get_recent_txs_and_info_params.dart';
import 'package:cw_zano/api/model/get_recent_txs_and_info_result.dart';
import 'package:cw_zano/api/model/get_wallet_info_result.dart';
import 'package:cw_zano/api/model/get_wallet_status_result.dart';
import 'package:cw_zano/api/model/proxy_to_daemon_params.dart';
import 'package:cw_zano/api/model/proxy_to_daemon_result.dart';
import 'package:cw_zano/api/model/store_result.dart';
import 'package:cw_zano/api/model/transfer.dart';
import 'package:cw_zano/api/model/transfer_params.dart';
import 'package:cw_zano/api/model/transfer_result.dart';
import 'package:cw_zano/zano_wallet_exceptions.dart';
import 'package:ffi/ffi.dart';
import 'package:json_bigint/json_bigint.dart';
import 'package:monero/zano.dart' as zano;
import 'package:monero/src/generated_bindings_zano.g.dart' as zanoapi;

mixin ZanoWalletApi {
  static const _maxReopenAttempts = 5;
  static const _logInfo = false;
  static const int _zanoMixinValue = 10;

  int _hWallet = 0;

  int get hWallet => _hWallet;

  set hWallet(int value) {
    _hWallet = value;
  }

  int getCurrentTxFee(TransactionPriority priority) => zano.PlainWallet_getCurrentTxFee(priority.raw);

  void setPassword(String password) => zano.PlainWallet_resetWalletPassword(hWallet, password);

  void closeWallet(int? walletToClose, {bool force = false}) async {
    printV('close_wallet ${walletToClose ?? hWallet}');
    if (Platform.isWindows || force) {
      final result = await _closeWallet(walletToClose ?? hWallet);
      printV('close_wallet result $result');
      openWalletCache.removeWhere((_, cwr) => cwr.walletId == (walletToClose ?? hWallet));
    }
  }

  bool isInit = false;

  Future<bool> initWallet() async {
    // pathForWallet(name: , type: type)
    if (isInit) return true;
    final result = zano.PlainWallet_init("", "", 0);
    isInit = true;
    return result == "OK";
  }

  Future<bool> setupNode(String nodeUrl) async {
    await _setupNode(hWallet, nodeUrl);
    return true;
  }

  Future<GetWalletInfoResult> getWalletInfo() async {
    final json = await _getWalletInfo(hWallet);
    final result = GetWalletInfoResult.fromJson(jsonDecode(json));
    printV('get_wallet_info got ${result.wi.balances.length} balances: ${result.wi.balances}');
    return result;
  }

  Future<GetWalletStatusResult> getWalletStatus() async {
    final json = await _getWalletStatus(hWallet);
    if (json == Consts.errorWalletWrongId) {
      printV('wrong wallet id');
      throw ZanoWalletException('Wrong wallet id');
    }
    final status = GetWalletStatusResult.fromJson(jsonDecode(json));
    if (_logInfo)
      printV(
          'get_wallet_status connected: ${status.isDaemonConnected} in refresh: ${status.isInLongRefresh} progress: ${status.progress} wallet state: ${status.walletState} sync: ${status.currentWalletHeight}/${status.currentDaemonHeight} ${(status.currentWalletHeight/status.currentDaemonHeight*100).toStringAsFixed(2)}%');
    return status;
  }

  Future<String> invokeMethod(String methodName, Object params) async {
    final request = jsonEncode({
      "method": methodName,
      "params": params,
    });
    final invokeResult = await callSyncMethod('invoke', hWallet, request);
    try {
      jsonDecode(invokeResult);
    } catch (e) {
      if (invokeResult.contains(Consts.errorWalletWrongId)) throw ZanoWalletException('Wrong wallet id');
      printV('exception in parsing json in invokeMethod: $invokeResult');
      rethrow;
    }
    return invokeResult;
  }

  Future<List<ZanoAsset>> getAssetsWhitelist() async {
    try {
      final json = await invokeMethod('assets_whitelist_get', '{}');
      final map = jsonDecode(json) as Map<String, dynamic>?;
      _checkForErrors(map);
      List<ZanoAsset> assets(String type, bool isGlobalWhitelist) =>
          (map?['result']?[type] as List<dynamic>?)
              ?.map((e) => ZanoAsset.fromJson(e as Map<String, dynamic>, isInGlobalWhitelist: isGlobalWhitelist))
              .toList() ??
          [];
      final localWhitelist = assets('local_whitelist', false);
      final globalWhitelist = assets('global_whitelist', true);
      final ownAssets = assets('own_assets', false);
      if (_logInfo)
        printV('assets_whitelist_get got local whitelist: ${localWhitelist.length} ($localWhitelist); '
            'global whitelist: ${globalWhitelist.length} ($globalWhitelist); '
            'own assets: ${ownAssets.length} ($ownAssets)');
      return [...globalWhitelist, ...localWhitelist, ...ownAssets];
    } catch (e) {
      printV('assets_whitelist_get $e');
      return [];
      // rethrow;
    }
  }

  Future<ZanoAsset?> addAssetsWhitelist(String assetId) async {
    try {
      final json = await invokeMethod('assets_whitelist_add', AssetIdParams(assetId: assetId));
      final map = jsonDecode(json) as Map<String, dynamic>?;
      _checkForErrors(map);
      if (map!['result']!['status']! == 'OK') {
        final assetDescriptor = ZanoAsset.fromJson(map['result']!['asset_descriptor']! as Map<String, dynamic>);
        printV('assets_whitelist_add added ${assetDescriptor.fullName} ${assetDescriptor.ticker}');
        return assetDescriptor;
      } else {
        printV('assets_whitelist_add status ${map['result']!['status']!}');
        return null;
      }
    } catch (e) {
      printV('assets_whitelist_add $e');
      return null;
    }
  }

  Future<bool> removeAssetsWhitelist(String assetId) async {
    try {
      final json = await invokeMethod('assets_whitelist_remove', AssetIdParams(assetId: assetId));
      final map = jsonDecode(json) as Map<String, dynamic>?;
      _checkForErrors(map);
      printV('assets_whitelist_remove status ${map!['result']!['status']!}');
      return (map['result']!['status']! == 'OK');
    } catch (e) {
      printV('assets_whitelist_remove $e');
      return false;
    }
  }

  Future<ProxyToDaemonResult?> _proxyToDaemon(String uri, String body) async {
    final json = await invokeMethod('proxy_to_daemon', ProxyToDaemonParams(body: body, uri: uri));
    final map = jsonDecode(json) as Map<String, dynamic>?;
    _checkForErrors(map);
    return ProxyToDaemonResult.fromJson(map!['result'] as Map<String, dynamic>);
  }

  Future<ZanoAsset?> getAssetInfo(String assetId) async {
    final methodName = 'get_asset_info';
    final params = AssetIdParams(assetId: assetId);
    final result = await _proxyToDaemon('/json_rpc', '{"method": "$methodName","params": ${jsonEncode(params)}}');
    if (result == null) {
      printV('get_asset_info empty result');
      return null;
    }
    final map = jsonDecode(result.body) as Map<String, dynamic>?;
    if (map!['error'] != null) {
      printV('get_asset_info $assetId error ${map['error']!['code']} ${map['error']!['message']}');
      return null;
    } else if (map['result']!['status']! == 'OK') {
      final assetDescriptor = ZanoAsset.fromJson(map['result']!['asset_descriptor']! as Map<String, dynamic>);
      printV('get_asset_info $assetId ${assetDescriptor.fullName} ${assetDescriptor.ticker}');
      return assetDescriptor;
    } else {
      printV('get_asset_info $assetId status ${map['result']!['status']!}');
      return null;
    }
  }

  Future<StoreResult?> store() async {
    try {
      final json = await invokeMethod('store', '{}');
      final map = jsonDecode(json) as Map<String, dynamic>?;
      _checkForErrors(map);
      return StoreResult.fromJson(map!['result'] as Map<String, dynamic>);
    } catch (e) {
      printV('store $e');
      return null;
    }
  }

  Future<GetRecentTxsAndInfoResult> getRecentTxsAndInfo({required int offset, required int count}) async {
    printV('get_recent_txs_and_info $offset $count');
    try {
      final json = await invokeMethod('get_recent_txs_and_info', GetRecentTxsAndInfoParams(offset: offset, count: count));
      final map = jsonDecode(json) as Map<String, dynamic>?;
      _checkForErrors(map);
      final lastItemIndex = map?['result']?['last_item_index'] as int?;
      final totalTransfers = map?['result']?['total_transfers'] as int?;
      final transfers = map?['result']?['transfers'] as List<dynamic>?;
      if (transfers == null || lastItemIndex == null || totalTransfers == null) {
        printV('get_recent_txs_and_info empty transfers');
        return GetRecentTxsAndInfoResult.empty();
      }
      printV('get_recent_txs_and_info transfers.length: ${transfers.length}');
      return GetRecentTxsAndInfoResult(
        transfers: transfers.map((e) => Transfer.fromJson(e as Map<String, dynamic>)).toList(),
        lastItemIndex: lastItemIndex,
        totalTransfers: totalTransfers,
      );
    } catch (e) {
      printV('get_recent_txs_and_info $e');
      return GetRecentTxsAndInfoResult.empty();
    }
  }

  GetAddressInfoResult getAddressInfo(String address) => GetAddressInfoResult.fromJson(
        jsonDecode(zano.PlainWallet_getAddressInfo(address)),
      );

  String _shorten(String s) => s.length > 10 ? '${s.substring(0, 4)}...${s.substring(s.length - 4)}' : s;

  Future<CreateWalletResult> createWallet(String path, String password) async {
    printV('create_wallet path $path password ${_shorten(password)}');
    final json = zano.PlainWallet_generate(path, password);
    final map = jsonDecode(json) as Map<String, dynamic>?;
    if (map?['error'] != null) {
      final code = map!['error']?['code'] ?? '';
      final message = map['error']?['message'] ?? '';
      throw ZanoWalletException('Error creating wallet file, $message ($code)');
    }
    if (map?['result'] == null) {
      throw ZanoWalletException('Error creating wallet file, empty response');
    }
    final result = CreateWalletResult.fromJson(map!['result'] as Map<String, dynamic>);
    openWalletCache[path] = result;
    printV('create_wallet ${result.name} ${result.seed}');
    return result;
  }

  Future<CreateWalletResult> restoreWalletFromSeed(String path, String password, String seed, String? passphrase) async {
    printV('restore_wallet path $path password ${_shorten(password)} seed ${_shorten(seed)}');
    final json = zano.PlainWallet_restore(seed, path, password, passphrase??'');
    final map = jsonDecode(json) as Map<String, dynamic>?;
    if (map?['error'] != null) {
      final code = map!['error']!['code'] ?? '';
      final message = map['error']!['message'] ?? '';
      if (code == Consts.errorWrongSeed) {
        throw RestoreFromSeedsException('Error restoring wallet, wrong seed');
      } else if (code == Consts.errorAlreadyExists) {
        throw RestoreFromSeedsException('Error restoring wallet, already exists');
      }
      throw RestoreFromSeedsException('Error restoring wallet, $message ($code)');
    }
    if (map?['result'] == null) {
      throw RestoreFromSeedsException('Error restoring wallet, empty response');
    }
    final result = CreateWalletResult.fromJson(map!['result'] as Map<String, dynamic>);
    openWalletCache[path] = result;
    printV('restore_wallet ${result.name} ${result.wi.address}');
    return result;
  }

  Future<CreateWalletResult>loadWallet(String path, String password, [int attempt = 0]) async {
    printV('load_wallet1 path $path password ${_shorten(password)}');
    final String json;
    try {
      json = zano.PlainWallet_open(path, password);
    } catch (e) {
      printV('error in loadingWallet $e'); 
      rethrow;
    }
    // printV('load_wallet2: $json');
    final map = jsonDecode(json) as Map<String, dynamic>?;
    if (map?['error'] != null) {
      final code = map?['error']!['code'] ?? '';
      final message = map?['error']!['message'] ?? '';
      if (code == Consts.errorAlreadyExists && attempt <= _maxReopenAttempts) {
        // already connected to this wallet. closing and trying to reopen
        printV('already connected. closing and reopen wallet (attempt $attempt)');
        closeWallet(attempt, force: true);
        await Future.delayed(const Duration(milliseconds: 500));
        return await loadWallet(path, password, attempt + 1);
      }
      throw ZanoWalletException('Error loading wallet, $message ($code)');
    }
    if (map?['result'] == null) {
      throw ZanoWalletException('Error loading wallet, empty response');
    }
    final result = CreateWalletResult.fromJson(map!['result'] as Map<String, dynamic>);
    printV('load_wallet3 ${result.name} ${result.wi.address}');
    openWalletCache[path] = result;
    return result;
  }

  static Map<String, CreateWalletResult> openWalletCache = {};

  Future<TransferResult> transfer(List<Destination> destinations, BigInt fee, String comment) async {
    final params = TransferParams(
      destinations: destinations,
      fee: fee,
      mixin: _zanoMixinValue,
      paymentId: '',
      comment: comment,
      pushPayer: false,
      hideReceiver: true,
    );
    final json = await invokeMethod('transfer', params);
    final map = jsonDecode(json);
    final resultMap = map as Map<String, dynamic>?;
    if (resultMap != null) {
      final transferResultMap = resultMap['result'] as Map<String, dynamic>?;
      if (transferResultMap != null) {
        final transferResult = TransferResult.fromJson(transferResultMap);
        printV('transfer success hash ${transferResult.txHash}');
        return transferResult;
      } else {
        final errorCode = resultMap['error']?['code'];
        final code = errorCode is int ? errorCode.toString() : errorCode as String? ?? '';
        final message = resultMap['error']?['message'] as String? ?? '';
        printV('transfer error $code $message');
        throw TransferException('Transfer error, $message ($code)');
      }
    }
    printV('transfer error empty result');
    throw TransferException('Transfer error, empty result');
  }

  void _checkForErrors(Map<String, dynamic>? map) {
    if (map == null) {
      throw ZanoWalletException('Empty response');
    }
    final result = map['result'];
    if (result == null) {
      throw ZanoWalletException('Empty response');
    }
    if (result['error'] != null) {
      final code = result['error']!['code'] ?? '';
      final message = result['error']!['message'] ?? '';
      if (code == -1 && message == Consts.errorBusy) {
        throw ZanoWalletBusyException();
      }
      throw ZanoWalletException('Error, $message ($code)');
    }
  }

}

Future<String> callSyncMethod(String methodName, int hWallet, String params) async {
  final params_ = params.toNativeUtf8().address;
  final method_name_ = methodName.toNativeUtf8().address;
  final invokeResult = await Isolate.run(() async {
    final lib = zanoapi.ZanoC(DynamicLibrary.open(zano.libPath));
    final txid = lib.ZANO_PlainWallet_syncCall(
      Pointer.fromAddress(method_name_).cast(), 
      hWallet, 
      Pointer.fromAddress(params_).cast()
    );
    try {
      final strPtr = txid.cast<Utf8>();
      final str = strPtr.toDartString();
      lib.ZANO_free(strPtr.cast());
      return str;
    } catch (e) {
      return "";
    }
  });
  calloc.free(Pointer.fromAddress(method_name_));
  calloc.free(Pointer.fromAddress(params_));
  return invokeResult;
}

Map<String, dynamic> jsonDecode(String json) {
  try {
    return decodeJson(json.replaceAll("\\/", "/")) as Map<String, dynamic>;
  } catch (e) {
    return convert.jsonDecode(json) as Map<String, dynamic>;
  }
}

String jsonEncode(Object? object) {
  return convert.jsonEncode(object);
}

Future<String> _getWalletStatus(int hWallet) async {
  final jsonPtr = await Isolate.run(() async {
    final lib = zanoapi.ZanoC(DynamicLibrary.open(zano.libPath));
    final status = lib.ZANO_PlainWallet_getWalletStatus(
      hWallet, 
    );
    return status.address;
  });
  String json = "";
  try {
    final strPtr = Pointer.fromAddress(jsonPtr).cast<Utf8>();
    final str = strPtr.toDartString();
    zano.ZANO_free(strPtr.cast());
    json = str;
  } catch (e) {
    json = "";
  }
  return json;
}
Future<String> _getWalletInfo(int hWallet) async {
  final jsonPtr = await Isolate.run(() async {
    final lib = zanoapi.ZanoC(DynamicLibrary.open(zano.libPath));
    final status = lib.ZANO_PlainWallet_getWalletInfo(
      hWallet, 
    );
    return status.address;
  });
  String json = "";
  try {
    final strPtr = Pointer.fromAddress(jsonPtr).cast<Utf8>();
    final str = strPtr.toDartString();
    zano.ZANO_free(strPtr.cast());
    json = str;
  } catch (e) {
    json = "";
  }
  return json;
}

Future<String> _setupNode(int hWallet, String nodeUrl) async {
  final resp = await callSyncMethod("reset_connection_url", hWallet, nodeUrl);
  printV(resp);
  final resp2 = await callSyncMethod("run_wallet", hWallet, "");
  printV(resp2);
  return "OK";
}

Future<String> _closeWallet(int hWallet) async {
  final str = await Isolate.run(() async {
    return zano.PlainWallet_closeWallet(hWallet);
  });
  printV("Closing wallet: $str");
  return str;
}