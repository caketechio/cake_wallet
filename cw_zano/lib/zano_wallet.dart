import 'dart:async';
import 'dart:core';
import 'dart:io';
import 'dart:math';

import 'package:cw_core/cake_hive.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/zano_asset.dart';
import 'package:cw_zano/api/model/create_wallet_result.dart';
import 'package:cw_zano/api/model/destination.dart';
import 'package:cw_zano/api/model/get_recent_txs_and_info_result.dart';
import 'package:cw_zano/api/model/get_wallet_status_result.dart';
import 'package:cw_zano/api/model/transfer.dart';
import 'package:cw_zano/model/pending_zano_transaction.dart';
import 'package:cw_zano/model/zano_balance.dart';
import 'package:cw_zano/model/zano_transaction_creation_exception.dart';
import 'package:cw_zano/model/zano_transaction_credentials.dart';
import 'package:cw_zano/model/zano_transaction_info.dart';
import 'package:cw_zano/model/zano_wallet_keys.dart';
import 'package:cw_zano/zano_formatter.dart';
import 'package:cw_zano/zano_transaction_history.dart';
import 'package:cw_zano/zano_wallet_addresses.dart';
import 'package:cw_zano/zano_wallet_api.dart';
import 'package:cw_zano/zano_wallet_exceptions.dart';
import 'package:cw_zano/zano_wallet_service.dart';
import 'package:cw_zano/api/model/balance.dart';

import 'package:mobx/mobx.dart';

part 'zano_wallet.g.dart';

class ZanoWallet = ZanoWalletBase with _$ZanoWallet;

abstract class ZanoWalletBase
    extends WalletBase<ZanoBalance, ZanoTransactionHistory, ZanoTransactionInfo>
    with Store, ZanoWalletApi {
  static const int _autoSaveIntervalSeconds = 30;
  static const int _pollIntervalMilliseconds = 5000;
  static const int _maxLoadAssetsRetries = 5;

  @override
  void setPassword(String password) {
    _password = password;
    super.setPassword(password);
  }

  String _password;

  @override
  String get password => _password;

  @override
  Future<String> signMessage(String message, {String? address = null}) {
    throw UnimplementedError();
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address = null}) {
    throw UnimplementedError();
  }

  @override
  ZanoWalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  ObservableMap<CryptoCurrency, ZanoBalance> balance;

  @override
  String seed = '';

  @override
  String? passphrase = '';

  @override
  ZanoWalletKeys keys = ZanoWalletKeys(
      privateSpendKey: '', privateViewKey: '', publicSpendKey: '', publicViewKey: '');

  static const String zanoAssetId =
      'd6329b5b1f7c0805b5c345f4957554002a2f557845f64d7645dae0e051a6498a';

  Map<String, ZanoAsset> zanoAssets = {};

  Timer? _updateSyncInfoTimer;

  int _lastKnownBlockHeight = 0;
  int _initialSyncHeight = 0;
  int currentDaemonHeight = 0;
  bool _isTransactionUpdating;
  bool _hasSyncAfterStartup;
  Timer? _autoSaveTimer;

  /// number of transactions in each request
  static final int _txChunkSize = (pow(2, 32) - 1).toInt();

  ZanoWalletBase(WalletInfo walletInfo, String password)
      : balance = ObservableMap.of({CryptoCurrency.zano: ZanoBalance.empty()}),
        _isTransactionUpdating = false,
        _hasSyncAfterStartup = false,
        walletAddresses = ZanoWalletAddresses(walletInfo),
        syncStatus = NotConnectedSyncStatus(),
        _password = password,
        super(walletInfo) {
    transactionHistory = ZanoTransactionHistory();
    if (!CakeHive.isAdapterRegistered(ZanoAsset.typeId)) {
      CakeHive.registerAdapter(ZanoAssetAdapter());
    }
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, [int? amount = null]) =>
      getCurrentTxFee(priority);

  @override
  Future<void> changePassword(String password) async {
    setPassword(password);
  }

  static Future<ZanoWallet> create({required WalletCredentials credentials}) async {
    final wallet = ZanoWallet(credentials.walletInfo!, credentials.password!);
    await wallet.initWallet();
    final path = await pathForWallet(name: credentials.name, type: credentials.walletInfo!.type);
    final createWalletResult = await wallet.createWallet(path, credentials.password!);
    await wallet.initWallet();
    await wallet.parseCreateWalletResult(createWalletResult);
    if (credentials.passphrase != null) {
      await wallet.setPassphrase(credentials.passphrase!);
      wallet.seed = await createWalletResult.seed(wallet);
      wallet.passphrase = await wallet.getPassphrase();
    }
    await wallet.init(createWalletResult.wi.address);
    return wallet;
  }

  static Future<ZanoWallet> restore(
      {required ZanoRestoreWalletFromSeedCredentials credentials}) async {
    final wallet = ZanoWallet(credentials.walletInfo!, credentials.password!);
    await wallet.initWallet();
    final path = await pathForWallet(name: credentials.name, type: credentials.walletInfo!.type);
    final createWalletResult = await wallet.restoreWalletFromSeed(
        path, credentials.password!, credentials.mnemonic, credentials.passphrase);
    await wallet.initWallet();
    await wallet.parseCreateWalletResult(createWalletResult);
    if (credentials.passphrase != null) {
      await wallet.setPassphrase(credentials.passphrase!);
      wallet.seed = await createWalletResult.seed(wallet);
      wallet.passphrase = await wallet.getPassphrase();
    }
    await wallet.init(createWalletResult.wi.address);
    return wallet;
  }

  static Future<ZanoWallet> open(
      {required String name, required String password, required WalletInfo walletInfo}) async {
    final path = await pathForWallet(name: name, type: walletInfo.type);
    if (ZanoWalletApi.openWalletCache[path] != null) {
      final wallet = ZanoWallet(walletInfo, password);
      await wallet.parseCreateWalletResult(ZanoWalletApi.openWalletCache[path]!).then((_) {
        unawaited(wallet.init(ZanoWalletApi.openWalletCache[path]!.wi.address));
      });
      return wallet;
    } else {
      final wallet = ZanoWallet(walletInfo, password);
      await wallet.initWallet();
      final createWalletResult = await wallet.loadWallet(path, password);
      await wallet.parseCreateWalletResult(createWalletResult).then((_) {
        unawaited(wallet.init(createWalletResult.wi.address));
      });
      return wallet;
    }
  }

  Future<void> parseCreateWalletResult(CreateWalletResult result) async {
    hWallet = result.walletId;
    seed = await result.seed(this);
    passphrase = await getPassphrase();

    printV('setting hWallet = ${result.walletId}');
    walletAddresses.address = result.wi.address;
    await loadAssets(result.wi.balances, maxRetries: _maxLoadAssetsRetries);
    for (final item in result.wi.balances) {
      if (item.assetInfo.assetId == zanoAssetId) {
        balance[CryptoCurrency.zano] = ZanoBalance(
          total: item.total,
          unlocked: item.unlocked,
        );
      }
    }
    if (result.recentHistory.history != null) {
      final transfers = result.recentHistory.history!;
      final transactions = Transfer.makeMap(transfers, zanoAssets, currentDaemonHeight);
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
    }
  }

  @override
  Future<void> close({bool shouldCleanup = true}) async {
    closeWallet(null);
    _updateSyncInfoTimer?.cancel();
    _autoSaveTimer?.cancel();
  }

  @override
  Future<void> connectToNode({required Node node}) async {
    syncStatus = ConnectingSyncStatus();
    await setupNode(node.uriRaw);
    syncStatus = ConnectedSyncStatus();
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    credentials as ZanoTransactionCredentials;
    final isZano = credentials.currency == CryptoCurrency.zano;
    final outputs = credentials.outputs;
    final hasMultiDestination = outputs.length > 1;
    final unlockedBalanceZano = balance[CryptoCurrency.zano]?.unlocked ?? BigInt.zero;
    final unlockedBalanceCurrency = balance[credentials.currency]?.unlocked ?? BigInt.zero;
    final fee = BigInt.from(calculateEstimatedFee(credentials.priority));
    late BigInt totalAmount;
    void checkForEnoughBalances() {
      if (isZano) {
        if (totalAmount + fee > unlockedBalanceZano) {
          throw ZanoTransactionCreationException(
              "You don't have enough coins (required: ${ZanoFormatter.bigIntAmountToString(totalAmount + fee)} ZANO, unlocked ${ZanoFormatter.bigIntAmountToString(unlockedBalanceZano)} ZANO).");
        }
      } else {
        if (fee > unlockedBalanceZano) {
          throw ZanoTransactionCreationException(
              "You don't have enough coins (required: ${ZanoFormatter.bigIntAmountToString(fee)} ZANO, unlocked ${ZanoFormatter.bigIntAmountToString(unlockedBalanceZano)} ZANO).");
        }
        if (totalAmount > unlockedBalanceCurrency) {
          throw ZanoTransactionCreationException(
              "You don't have enough coins (required: ${ZanoFormatter.bigIntAmountToString(totalAmount, credentials.currency.decimals)} ${credentials.currency.title}, unlocked ${ZanoFormatter.bigIntAmountToString(unlockedBalanceCurrency, credentials.currency.decimals)} ${credentials.currency.title}).");
        }
      }
    }

    final assetId = isZano ? zanoAssetId : (credentials.currency as ZanoAsset).assetId;
    late List<Destination> destinations;
    if (hasMultiDestination) {
      if (outputs.any((output) => output.sendAll || (output.formattedCryptoAmount ?? 0) <= 0)) {
        throw ZanoTransactionCreationException("You don't have enough coins.");
      }
      totalAmount = outputs.fold(
          BigInt.zero, (acc, value) => acc + BigInt.from(value.formattedCryptoAmount ?? 0));
      checkForEnoughBalances();
      destinations = outputs
          .map((output) => Destination(
                amount: BigInt.from(output.formattedCryptoAmount ?? 0),
                address: output.isParsedAddress ? output.extractedAddress! : output.address,
                assetId: assetId,
              ))
          .toList();
    } else {
      final output = outputs.first;
      if (output.sendAll) {
        if (isZano) {
          totalAmount = unlockedBalanceZano - fee;
        } else {
          totalAmount = unlockedBalanceCurrency;
        }
      } else {
        totalAmount = BigInt.from(output.formattedCryptoAmount!);
      }
      checkForEnoughBalances();
      destinations = [
        Destination(
          amount: totalAmount,
          address: output.isParsedAddress ? output.extractedAddress! : output.address,
          assetId: assetId,
        )
      ];
    }
    return PendingZanoTransaction(
      zanoWallet: this,
      destinations: destinations,
      fee: fee,
      comment: outputs.first.note ?? '',
      assetId: assetId,
      ticker: credentials.currency.title,
      decimalPoint: credentials.currency.decimals,
      amount: totalAmount,
    );
  }

  @override
  Future<Map<String, ZanoTransactionInfo>> fetchTransactions() async {
    try {
      final transfers = <Transfer>[];
      late GetRecentTxsAndInfoResult result;
      do {
        result = await getRecentTxsAndInfo(offset: 0, count: _txChunkSize);
        // _lastTxIndex += result.transfers.length;
        transfers.addAll(result.transfers);
      } while (result.lastItemIndex + 1 < result.totalTransfers);
      return Transfer.makeMap(transfers, zanoAssets, currentDaemonHeight);
    } catch (e) {
      printV((e.toString()));
      return {};
    }
  }

  Future<void> init(String address) async {
    await walletAddresses.init();
    await walletAddresses.updateAddress(address);
    await updateTransactions();
    _autoSaveTimer = Timer.periodic(Duration(seconds: _autoSaveIntervalSeconds), (_) async {
      await save();
    });
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final currentWalletPath = await pathForWallet(name: name, type: type);
    final currentCacheFile = File(currentWalletPath);
    final currentKeysFile = File('$currentWalletPath.keys');
    final currentAddressListFile = File('$currentWalletPath.address.txt');

    final newWalletPath = await pathForWallet(name: newWalletName, type: type);

    // Copies current wallet files into new wallet name's dir and files
    if (currentCacheFile.existsSync()) {
      await currentCacheFile.copy(newWalletPath);
    }
    if (currentKeysFile.existsSync()) {
      await currentKeysFile.copy('$newWalletPath.keys');
    }
    if (currentAddressListFile.existsSync()) {
      await currentAddressListFile.copy('$newWalletPath.address.txt');
    }

    // Delete old name's dir and files
    await Directory(currentWalletPath).delete(recursive: true);
  }

  @override
  Future<void> rescan({required int height}) => throw UnimplementedError();

  @override
  Future<void> save() async {
    try {
      await store();
      await walletAddresses.updateAddressesInBox();
    } catch (e) {
      printV(('Error while saving Zano wallet file ${e.toString()}'));
    }
  }

  Future<void> loadAssets(List<Balance> balances, {int maxRetries = 1}) async {
    List<ZanoAsset> assets = [];
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        assets = await getAssetsWhitelist();
        break;
      } on ZanoWalletBusyException {
        if (retryCount < maxRetries - 1) {
          retryCount++;
          await Future.delayed(Duration(seconds: 1));
        } else {
          printV(('failed to load assets after $retryCount retries'));
          break;
        }
      }
    }
    zanoAssets = {};
    for (final asset in assets) {
      final newAsset = ZanoAsset.copyWith(
        asset,
        enabled: balances.any((element) => element.assetId == asset.assetId),
      );
      zanoAssets.putIfAbsent(asset.assetId, () => newAsset);
    }
  }

  @override
  Future<void> startSync() async {
    try {
      syncStatus = AttemptingSyncStatus();
      _lastKnownBlockHeight = 0;
      _initialSyncHeight = 0;
      _updateSyncInfoTimer ??=
          Timer.periodic(Duration(milliseconds: _pollIntervalMilliseconds), (_) => _updateSyncInfo());
    } catch (e) {
      syncStatus = FailedSyncStatus();
      printV((e.toString()));
    }
  }

  @override
  Future<void>? updateBalance() => null;

  Future<void> updateTransactions() async {
    try {
      if (_isTransactionUpdating) {
        return;
      }
      _isTransactionUpdating = true;
      final transactions = await fetchTransactions();
      transactionHistory.clear();
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
      _isTransactionUpdating = false;
    } catch (e) {
      printV("e: $e");
      printV((e.toString()));
      _isTransactionUpdating = false;
    }
  }

  Future<CryptoCurrency> addZanoAssetById(String assetId) async {
    if (zanoAssets.containsKey(assetId)) {
      throw ZanoWalletException('zano asset with id $assetId already added');
    }
    final assetDescriptor = await addAssetsWhitelist(assetId);
    if (assetDescriptor == null) {
      throw ZanoWalletException("there's no zano asset with id $assetId");
    }
    final asset = ZanoAsset.copyWith(
      assetDescriptor,
      assetId: assetId,
      enabled: true,
    );
    zanoAssets[asset.assetId] = asset;
    balance[asset] = ZanoBalance.empty(decimalPoint: asset.decimalPoint);
    return asset;
  }

  Future<void> changeZanoAssetAvailability(ZanoAsset asset) async {
    if (asset.enabled) {
      final assetDescriptor = await addAssetsWhitelist(asset.assetId);
      if (assetDescriptor == null) {
        printV(('Error adding zano asset'));
      }
    } else {
      final result = await removeAssetsWhitelist(asset.assetId);
      if (result == false) {
        printV(('Error removing zano asset'));
      }
    }
  }

  Future<void> deleteZanoAsset(ZanoAsset asset) async {
    final _ = await removeAssetsWhitelist(asset.assetId);
  }

  Future<ZanoAsset?> getZanoAsset(String assetId) async {
    // wallet api is not available while the wallet is syncing so only call it if it's synced
    if (syncStatus is SyncedSyncStatus) {
      return await getAssetInfo(assetId);
    }
    return null;
  }

  Future<void> _askForUpdateTransactionHistory() async => await updateTransactions();

  void _onNewBlock(int height, int blocksLeft, double ptc) async {
    try {
      if (blocksLeft < 1000) {
        await _askForUpdateTransactionHistory();
        syncStatus = SyncedSyncStatus();

        if (!_hasSyncAfterStartup) {
          _hasSyncAfterStartup = true;
          await save();
        }
      } else {
        syncStatus = SyncingSyncStatus(blocksLeft, ptc);
      }
    } catch (e) {
      printV((e.toString()));
    }
  }

  void _updateSyncProgress(GetWalletStatusResult walletStatus) {
    final syncHeight = walletStatus.currentWalletHeight;
    if (_initialSyncHeight <= 0) {
      _initialSyncHeight = syncHeight;
    }
    final bchHeight = walletStatus.currentDaemonHeight;

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
    _onNewBlock.call(syncHeight, left, ptc);
  }

  void _updateSyncInfo() async {
    GetWalletStatusResult walletStatus;
    // ignoring get wallet status exception (in case of wrong wallet id)
    try {
      walletStatus = await getWalletStatus();
    } on ZanoWalletException {
      return;
    }
    currentDaemonHeight = walletStatus.currentDaemonHeight;
    _updateSyncProgress(walletStatus);

    // we can call getWalletInfo ONLY if getWalletStatus returns NOT is in long refresh and wallet state is 2 (ready)
    if (!walletStatus.isInLongRefresh && walletStatus.walletState == 2) {
      final walletInfo = await getWalletInfo();
      seed = await walletInfo.wiExtended.seed(this);
      keys = ZanoWalletKeys(
        privateSpendKey: walletInfo.wiExtended.spendPrivateKey,
        privateViewKey: walletInfo.wiExtended.viewPrivateKey,
        publicSpendKey: walletInfo.wiExtended.spendPublicKey,
        publicViewKey: walletInfo.wiExtended.viewPublicKey,
      );
      loadAssets(walletInfo.wi.balances);
      // matching balances and whitelists
      // 1. show only balances available in whitelists
      // 2. set whitelists available in balances as 'enabled' ('disabled' by default)
      for (final b in walletInfo.wi.balances) {
        if (b.assetId == zanoAssetId) {
          balance[CryptoCurrency.zano] = ZanoBalance(total: b.total, unlocked: b.unlocked);
        } else {
          final asset = zanoAssets[b.assetId];
          if (asset == null) {
            printV('balance for an unknown asset ${b.assetInfo.assetId}');
            continue;
          }
          if (balance.keys.any(
                  (element) => element is ZanoAsset && element.assetId == b.assetInfo.assetId)) {
            balance[balance.keys.firstWhere((element) =>
            element is ZanoAsset && element.assetId == b.assetInfo.assetId)] =
                ZanoBalance(
                    total: b.total, unlocked: b.unlocked, decimalPoint: asset.decimalPoint);
          } else {
            balance[asset] = ZanoBalance(
                total: b.total, unlocked: b.unlocked, decimalPoint: asset.decimalPoint);
          }
        }
      }
      await updateTransactions();
      // removing balances for assets missing in wallet info balances
      balance.removeWhere(
            (key, _) =>
        key != CryptoCurrency.zano &&
            !walletInfo.wi.balances
                .any((element) => element.assetId == (key as ZanoAsset).assetId),
      );
    }
  }
}
