import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/account.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/monero_balance.dart';
import 'package:cw_core/monero_transaction_priority.dart';
import 'package:cw_core/monero_wallet_keys.dart';
import 'package:cw_core/monero_wallet_utils.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_monero/api/account_list.dart';
import 'package:cw_monero/api/coins_info.dart';
import 'package:cw_monero/api/monero_output.dart';
import 'package:cw_monero/api/structs/pending_transaction.dart';
import 'package:cw_monero/api/transaction_history.dart' as transaction_history;
import 'package:cw_monero/api/wallet.dart' as monero_wallet;
import 'package:cw_monero/api/wallet_manager.dart';
import 'package:cw_monero/exceptions/monero_transaction_creation_exception.dart';
import 'package:cw_monero/ledger.dart';
import 'package:cw_monero/monero_transaction_creation_credentials.dart';
import 'package:cw_monero/monero_transaction_history.dart';
import 'package:cw_monero/monero_transaction_info.dart';
import 'package:cw_monero/monero_unspent.dart';
import 'package:cw_monero/monero_wallet_addresses.dart';
import 'package:cw_monero/pending_monero_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:ledger_flutter_plus/ledger_flutter_plus.dart';
import 'package:mobx/mobx.dart';
import 'package:monero/monero.dart' as monero;
import 'package:tor/tor.dart';

part 'monero_wallet.g.dart';

const moneroBlockSize = 1000;
// not sure if this should just be 0 but setting it higher feels safer / should catch more cases:
const MIN_RESTORE_HEIGHT = 1000;

class MoneroWallet = MoneroWalletBase with _$MoneroWallet;

abstract class MoneroWalletBase extends WalletBase<MoneroBalance,
    MoneroTransactionHistory, MoneroTransactionInfo> with Store {
  MoneroWalletBase(
      {required WalletInfo walletInfo,
      required Box<UnspentCoinsInfo> unspentCoinsInfo,
      required String password})
      : balance = ObservableMap<CryptoCurrency, MoneroBalance>.of({
          CryptoCurrency.xmr: MoneroBalance(
            fullBalance: monero_wallet.getFullBalance(accountIndex: 0),
            unlockedBalance: monero_wallet.getUnlockedBalance(accountIndex: 0),
          )
        }),
        _isTransactionUpdating = false,
        _hasSyncAfterStartup = false,
        isEnabledAutoGenerateSubaddress = true,
        _password = password,
        syncStatus = NotConnectedSyncStatus(),
        unspentCoins = [],
        this.unspentCoinsInfo = unspentCoinsInfo,
        super(walletInfo) {
    transactionHistory = MoneroTransactionHistory();
    walletAddresses = MoneroWalletAddresses(walletInfo, transactionHistory);

    _onAccountChangeReaction =
        reaction((_) => walletAddresses.account, (Account? account) {
      if (account == null) return;

      balance = ObservableMap<CryptoCurrency, MoneroBalance>.of(<CryptoCurrency,
          MoneroBalance>{
        currency: MoneroBalance(
            fullBalance: monero_wallet.getFullBalance(accountIndex: account.id),
            unlockedBalance:
                monero_wallet.getUnlockedBalance(accountIndex: account.id))
      });
      _updateSubAddress(isEnabledAutoGenerateSubaddress, account: account);
      _askForUpdateTransactionHistory();
    });

    reaction((_) => isEnabledAutoGenerateSubaddress, (bool enabled) {
      _updateSubAddress(enabled, account: walletAddresses.account);
    });
    _onTxHistoryChangeReaction = reaction((_) => transactionHistory, (__) {
      _updateSubAddress(isEnabledAutoGenerateSubaddress, account: walletAddresses.account);
    });
  }

  static const int _autoSaveInterval = 30;

  Box<UnspentCoinsInfo> unspentCoinsInfo;

  void Function(FlutterErrorDetails)? onError;

  @override
  late MoneroWalletAddresses walletAddresses;

  @override
  @observable
  bool isEnabledAutoGenerateSubaddress;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  ObservableMap<CryptoCurrency, MoneroBalance> balance;

  @override
  String get seed => monero_wallet.getSeed();
  String seedLegacy(String? language) => monero_wallet.getSeedLegacy(language);

  @override
  String get password => _password;

  @override
  MoneroWalletKeys get keys => MoneroWalletKeys(
      primaryAddress: monero_wallet.getAddress(accountIndex: 0, addressIndex: 0),
      privateSpendKey: monero_wallet.getSecretSpendKey(),
      privateViewKey: monero_wallet.getSecretViewKey(),
      publicSpendKey: monero_wallet.getPublicSpendKey(),
      publicViewKey: monero_wallet.getPublicViewKey());

  int? get restoreHeight =>
      transactionHistory.transactions.values.firstOrNull?.height;

  monero_wallet.SyncListener? _listener;
  ReactionDisposer? _onAccountChangeReaction;
  ReactionDisposer? _onTxHistoryChangeReaction;
  bool _isTransactionUpdating;
  bool _hasSyncAfterStartup;
  Timer? _autoSaveTimer;
  List<MoneroUnspent> unspentCoins;
  String _password;

  Future<void> init() async {
    await walletAddresses.init();
    balance = ObservableMap<CryptoCurrency, MoneroBalance>.of(<CryptoCurrency,
        MoneroBalance>{
      currency: MoneroBalance(
          fullBalance: monero_wallet.getFullBalance(
              accountIndex: walletAddresses.account!.id),
          unlockedBalance: monero_wallet.getUnlockedBalance(
              accountIndex: walletAddresses.account!.id))
    });
    _setListeners();
    await updateTransactions();

    if (walletInfo.isRecovery) {
      monero_wallet.setRecoveringFromSeed(isRecovery: walletInfo.isRecovery);

      if (monero_wallet.getCurrentHeight() <= 1) {
        monero_wallet.setRefreshFromBlockHeight(
            height: walletInfo.restoreHeight);
      }
    }

    _autoSaveTimer = Timer.periodic(
        Duration(seconds: _autoSaveInterval), (_) async => await save());
    // update transaction details after restore
    walletAddresses.subaddressList.update(accountIndex: walletAddresses.account?.id??0);
  }

  @override
  Future<void>? updateBalance() => null;

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    _listener?.stop();
    _onAccountChangeReaction?.reaction.dispose();
    _onTxHistoryChangeReaction?.reaction.dispose();
    _autoSaveTimer?.cancel();
  }

  @override
  Future<void> connectToNode({required Node node}) async {
    String socksProxy = node.socksProxyAddress ?? '';
    printV("bootstrapped: ${Tor.instance.bootstrapped}");
    printV("     enabled: ${Tor.instance.enabled}");
    printV("        port: ${Tor.instance.port}");
    printV("     started: ${Tor.instance.started}");
    if (Tor.instance.enabled) {
      socksProxy = "127.0.0.1:${Tor.instance.port}";
    }
    try {
      syncStatus = ConnectingSyncStatus();
      await monero_wallet.setupNode(
          address: node.uri.toString(),
          login: node.login,
          password: node.password,
          useSSL: node.isSSL,
          isLightWallet: false,
          // FIXME: hardcoded value
          socksProxyAddress: socksProxy);

      monero_wallet.setTrustedDaemon(node.trusted);
      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
      printV(e);
    }
  }

  @override
  Future<void> startSync() async {
    try {
      _assertInitialHeight();
    } catch (_) {
      // our restore height wasn't correct, so lets see if using the backup works:
      try {
        await resetCache(name); // Resetting the cache removes the TX Keys and Polyseed
        _assertInitialHeight();
      } catch (e) {
        // we still couldn't get a valid height from the backup?!:
        // try to use the date instead:
        try {
          _setHeightFromDate();
        } catch (_) {
          // we still couldn't get a valid sync height :/
        }
      }
    }

    try {
      syncStatus = AttemptingSyncStatus();
      monero_wallet.startRefresh();
      _setListeners();
      _listener?.start();
    } catch (e) {
      syncStatus = FailedSyncStatus();
      printV(e);
      rethrow;
    }
  }

  Future<bool> submitTransactionUR(String ur) async {
    final retStatus = monero.Wallet_submitTransactionUR(wptr!, ur);
    final status = monero.Wallet_status(wptr!);
    if (status != 0) {
      final err = monero.Wallet_errorString(wptr!);
      throw MoneroTransactionCreationException("unable to broadcast signed transaction: $err");
    }
    return retStatus;
  }

  bool importKeyImagesUR(String ur) {
    final retStatus = monero.Wallet_importKeyImagesUR(wptr!, ur);
    final status = monero.Wallet_status(wptr!);
    if (status != 0) {
      final err = monero.Wallet_errorString(wptr!);
      throw Exception("unable to import key images: $err");
    }
    return retStatus;
  }

  String exportOutputsUR(bool all) {
    final str = monero.Wallet_exportOutputsUR(wptr!, all: all);
    final status = monero.Wallet_status(wptr!);
    if (status != 0) {
      final err = monero.Wallet_errorString(wptr!);
      throw MoneroTransactionCreationException("unable to export UR: $err");
    }
    return str;
  }

  bool needExportOutputs(int amount) {
    // viewOnlyBalance - balance that we can spend
    // TODO(mrcyjanek): remove hasUnknownKeyImages when we cleanup coin control
    return (monero.Wallet_viewOnlyBalance(wptr!,
                accountIndex: walletAddresses.account!.id) < amount) ||
              monero.Wallet_hasUnknownKeyImages(wptr!);
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final _credentials = credentials as MoneroTransactionCreationCredentials;
    final inputs = <String>[];
    final outputs = _credentials.outputs;
    final hasMultiDestination = outputs.length > 1;
    final unlockedBalance = monero_wallet.getUnlockedBalance(
        accountIndex: walletAddresses.account!.id);

    PendingTransactionDescription pendingTransactionDescription;

    if (!(syncStatus is SyncedSyncStatus)) {
      throw MoneroTransactionCreationException('The wallet is not synced.');
    }

    if (unspentCoins.isEmpty) {
      await updateUnspent();
    }

    for (final utx in unspentCoins) {
      if (utx.isSending) {
        inputs.add(utx.keyImage!);
      }
    }

    if (hasMultiDestination) {
      if (outputs.any(
          (item) => item.sendAll || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw MoneroTransactionCreationException(
            'You do not have enough XMR to send this amount.');
      }

      final int totalAmount = outputs.fold(
          0, (acc, value) => acc + (value.formattedCryptoAmount ?? 0));

      if (unlockedBalance < totalAmount) {
        throw MoneroTransactionCreationException(
            'You do not have enough XMR to send this amount.');
      }

      if (inputs.isEmpty) MoneroTransactionCreationException(
        'No inputs selected');

      final moneroOutputs = outputs.map((output) {
        final outputAddress =
            output.isParsedAddress ? output.extractedAddress : output.address;

        return MoneroOutput(
            address: outputAddress!,
            amount: output.cryptoAmount!.replaceAll(',', '.'));
      }).toList();

      pendingTransactionDescription =
          await transaction_history.createTransactionMultDest(
              outputs: moneroOutputs,
              priorityRaw: _credentials.priority.serialize(),
              accountIndex: walletAddresses.account!.id,
              preferredInputs: inputs);
    } else {
      final output = outputs.first;
      final address =
          output.isParsedAddress ? output.extractedAddress : output.address;
      final amount =
          output.sendAll ? null : output.cryptoAmount!.replaceAll(',', '.');

      // if ((formattedAmount != null && unlockedBalance < formattedAmount) ||
      //     (formattedAmount == null && unlockedBalance <= 0)) {
      //   final formattedBalance = moneroAmountToString(amount: unlockedBalance);
      //
      //   throw MoneroTransactionCreationException(
      //       'You do not have enough unlocked balance. Unlocked: $formattedBalance. Transaction amount: ${output.cryptoAmount}.');
      // }

      if (inputs.isEmpty) MoneroTransactionCreationException(
        'No inputs selected');
      pendingTransactionDescription =
          await transaction_history.createTransaction(
              address: address!,
              amount: amount,
              priorityRaw: _credentials.priority.serialize(),
              accountIndex: walletAddresses.account!.id,
              preferredInputs: inputs);
    }

    // final status = monero.PendingTransaction_status(pendingTransactionDescription);

    return PendingMoneroTransaction(pendingTransactionDescription);
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) {
    // FIXME: hardcoded value;

    if (priority is MoneroTransactionPriority) {
      switch (priority) {
        case MoneroTransactionPriority.slow:
          return 24590000;
        case MoneroTransactionPriority.automatic:
          return 123050000;
        case MoneroTransactionPriority.medium:
          return 245029999;
        case MoneroTransactionPriority.fast:
          return 614530000;
        case MoneroTransactionPriority.fastest:
          return 26021600000;
      }
    }

    return 0;
  }

  @override
  Future<void> save() async {
    await walletAddresses.updateUsedSubaddress();

    if (isEnabledAutoGenerateSubaddress) {
      walletAddresses.updateUnusedSubaddress(
          accountIndex: walletAddresses.account?.id ?? 0,
          defaultLabel: walletAddresses.account?.label ?? '');
    }

    await walletAddresses.updateAddressesInBox();
    await monero_wallet.store();
    try {
      await backupWalletFiles(name);
    } catch (e) {
      printV("¯\\_(ツ)_/¯");
      printV(e);
    }
  }

  @override
  Future<void> renameWalletFiles(String newWalletName) async {
    final currentWalletDirPath = await pathForWalletDir(name: name, type: type);
    if (openedWalletsByPath["$currentWalletDirPath/$name"] != null) {
      // NOTE: this is realistically only required on windows.
      printV("closing wallet");
      final wmaddr = wmPtr.address;
      final waddr = openedWalletsByPath["$currentWalletDirPath/$name"]!.address;
      await Isolate.run(() {
        monero.WalletManager_closeWallet(
            Pointer.fromAddress(wmaddr), Pointer.fromAddress(waddr), true);
      });
      openedWalletsByPath.remove("$currentWalletDirPath/$name");
      printV("wallet closed");
    }
    try {
      // -- rename the waller folder --
      final currentWalletDir =
          Directory(await pathForWalletDir(name: name, type: type));
      final newWalletDirPath =
          await pathForWalletDir(name: newWalletName, type: type);
      await currentWalletDir.rename(newWalletDirPath);

      // -- use new waller folder to rename files with old names still --
      final renamedWalletPath = newWalletDirPath + '/$name';

      final currentCacheFile = File(renamedWalletPath);
      final currentKeysFile = File('$renamedWalletPath.keys');
      final currentAddressListFile = File('$renamedWalletPath.address.txt');

      final newWalletPath =
          await pathForWallet(name: newWalletName, type: type);

      if (currentCacheFile.existsSync()) {
        await currentCacheFile.rename(newWalletPath);
      }
      if (currentKeysFile.existsSync()) {
        await currentKeysFile.rename('$newWalletPath.keys');
      }
      if (currentAddressListFile.existsSync()) {
        await currentAddressListFile.rename('$newWalletPath.address.txt');
      }

      await backupWalletFiles(newWalletName);
    } catch (e) {
      final currentWalletPath = await pathForWallet(name: name, type: type);

      final currentCacheFile = File(currentWalletPath);
      final currentKeysFile = File('$currentWalletPath.keys');
      final currentAddressListFile = File('$currentWalletPath.address.txt');

      final newWalletPath =
          await pathForWallet(name: newWalletName, type: type);

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
      await Directory(currentWalletDirPath).delete(recursive: true);
    }
  }

  @override
  Future<void> changePassword(String password) async =>
      monero_wallet.setPasswordSync(password);

  Future<int> getNodeHeight() async => monero_wallet.getNodeHeight();

  Future<bool> isConnected() async => monero_wallet.isConnected();

  Future<void> setAsRecovered() async {
    walletInfo.isRecovery = false;
    await walletInfo.save();
  }

  @override
  Future<void> rescan({required int height}) async {
    walletInfo.restoreHeight = height;
    walletInfo.isRecovery = true;
    monero_wallet.setRefreshFromBlockHeight(height: height);
    monero_wallet.rescanBlockchainAsync();
    await startSync();
    _askForUpdateBalance();
    walletAddresses.accountList.update();
    await _askForUpdateTransactionHistory();
    await save();
    await walletInfo.save();
  }

  Future<void> updateUnspent() async {
    try {
      refreshCoins(walletAddresses.account!.id);

      unspentCoins.clear();

      final coinCount = countOfCoins();
      for (var i = 0; i < coinCount; i++) {
        final coin = getCoin(i);
        final coinSpent = monero.CoinsInfo_spent(coin);
        if (coinSpent == false && monero.CoinsInfo_subaddrAccount(coin) == walletAddresses.account!.id) {
          final unspent = MoneroUnspent(
            monero.CoinsInfo_address(coin),
            monero.CoinsInfo_hash(coin),
            monero.CoinsInfo_keyImage(coin),
            monero.CoinsInfo_amount(coin),
            monero.CoinsInfo_frozen(coin),
            monero.CoinsInfo_unlocked(coin),
          );
          // TODO: double-check the logic here
          if (unspent.hash.isNotEmpty) {
            unspent.isChange = transaction_history.getTransaction(unspent.hash).isSpend == true;
          }
          unspentCoins.add(unspent);
        }
      }

      if (unspentCoinsInfo.isEmpty) {
        unspentCoins.forEach((coin) => _addCoinInfo(coin));
        return;
      }

      if (unspentCoins.isNotEmpty) {
        unspentCoins.forEach((coin) {
          final coinInfoList = unspentCoinsInfo.values.where((element) =>
              element.walletId.contains(id) &&
              element.accountIndex == walletAddresses.account!.id &&
              element.keyImage!.contains(coin.keyImage!));

          if (coinInfoList.isNotEmpty) {
            final coinInfo = coinInfoList.first;

            coin.isFrozen = coinInfo.isFrozen;
            coin.isSending = coinInfo.isSending;
            coin.note = coinInfo.note;
          } else {
            _addCoinInfo(coin);
          }
        });
      }

      await _refreshUnspentCoinsInfo();
      _askForUpdateBalance();
    } catch (e, s) {
      printV(e.toString());
      onError?.call(FlutterErrorDetails(
        exception: e,
        stack: s,
        library: this.runtimeType.toString(),
      ));
    }
  }

  Future<void> _addCoinInfo(MoneroUnspent coin) async {
    final newInfo = UnspentCoinsInfo(
        walletId: id,
        hash: coin.hash,
        isFrozen: coin.isFrozen,
        isSending: coin.isSending,
        noteRaw: coin.note,
        address: coin.address,
        value: coin.value,
        vout: 0,
        keyImage: coin.keyImage,
        isChange: coin.isChange,
        accountIndex: walletAddresses.account!.id);

    await unspentCoinsInfo.add(newInfo);
  }

  Future<void> _refreshUnspentCoinsInfo() async {
    try {
      final List<dynamic> keys = <dynamic>[];
      final currentWalletUnspentCoins = unspentCoinsInfo.values.where(
          (element) =>
              element.walletId.contains(id) &&
              element.accountIndex == walletAddresses.account!.id);

      if (currentWalletUnspentCoins.isNotEmpty) {
        currentWalletUnspentCoins.forEach((element) {
          final existUnspentCoins = unspentCoins
              .where((coin) => element.keyImage!.contains(coin.keyImage!));

          if (existUnspentCoins.isEmpty) {
            keys.add(element.key);
          }
        });
      }

      if (keys.isNotEmpty) {
        await unspentCoinsInfo.deleteAll(keys);
      }
    } catch (e) {
      printV(e.toString());
    }
  }

  String getTransactionAddress(int accountIndex, int addressIndex) =>
      monero_wallet.getAddress(
          accountIndex: accountIndex, addressIndex: addressIndex);

  @override
  Future<Map<String, MoneroTransactionInfo>> fetchTransactions() async {
    transaction_history.refreshTransactions();
    return (await _getAllTransactionsOfAccount(walletAddresses.account?.id))
        .fold<Map<String, MoneroTransactionInfo>>(
            <String, MoneroTransactionInfo>{},
            (Map<String, MoneroTransactionInfo> acc, MoneroTransactionInfo tx) {
      acc[tx.id] = tx;
      return acc;
    });
  }

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
      printV(e);
      _isTransactionUpdating = false;
    }
  }

  String getSubaddressLabel(int accountIndex, int addressIndex) =>
      monero_wallet.getSubaddressLabel(accountIndex, addressIndex);

  Future<List<MoneroTransactionInfo>> _getAllTransactionsOfAccount(int? accountIndex) async =>
      (await transaction_history
          .getAllTransactions())
          .map(
            (row) => MoneroTransactionInfo(
              row.hash,
              row.blockheight,
              row.isSpend
                  ? TransactionDirection.outgoing
                  : TransactionDirection.incoming,
              row.timeStamp,
              row.isPending,
              row.amount,
              row.accountIndex,
              0,
              row.fee,
              row.confirmations,
            )..additionalInfo = <String, dynamic>{
                'key': row.key,
                'accountIndex': row.accountIndex,
                'addressIndex': row.addressIndex
              },
          )
          .where((element) => element.accountIndex == (accountIndex ?? 0))
          .toList();

  void _setListeners() {
    _listener?.stop();
    _listener = monero_wallet.setListeners(_onNewBlock, _onNewTransaction);
  }

  /// Asserts the current height to be above [MIN_RESTORE_HEIGHT]
  void _assertInitialHeight() {
    if (walletInfo.isRecovery) return;

    final height = monero_wallet.getCurrentHeight();

    // the restore height is probably correct, so we do nothing:
    if (height > MIN_RESTORE_HEIGHT) return;

    throw Exception("height isn't > $MIN_RESTORE_HEIGHT!");
  }

  void _setHeightFromDate() {
    if (walletInfo.isRecovery) {
      return;
    }

    int height = 0;
    try {
      height = _getHeightByDate(walletInfo.date);
    } catch (_) {}

    monero_wallet.setRecoveringFromSeed(isRecovery: true);
    monero_wallet.setRefreshFromBlockHeight(height: height);
  }

  int _getHeightDistance(DateTime date) {
    final distance =
        DateTime.now().millisecondsSinceEpoch - date.millisecondsSinceEpoch;
    final daysTmp = (distance / 86400).round();
    final days = daysTmp < 1 ? 1 : daysTmp;

    return days * 1000;
  }

  int _getHeightByDate(DateTime date) {
    final nodeHeight = monero_wallet.getNodeHeightSync();
    final heightDistance = _getHeightDistance(date);

    if (nodeHeight <= 0) {
      // the node returned 0 (an error state)
      throw Exception("nodeHeight is <= 0!");
    }

    return nodeHeight - heightDistance;
  }

  void _askForUpdateBalance() {
    final unlockedBalance = _getUnlockedBalance();
    final fullBalance = monero_wallet.getFullBalance(
      accountIndex: walletAddresses.account!.id);
    final frozenBalance = _getFrozenBalance();
    if (balance[currency]!.fullBalance != fullBalance ||
        balance[currency]!.unlockedBalance != unlockedBalance ||
        balance[currency]!.frozenBalance != frozenBalance) {
      balance[currency] = MoneroBalance(
          fullBalance: fullBalance,
          unlockedBalance: unlockedBalance,
          frozenBalance: frozenBalance);
    }
  }

  Future<void> _askForUpdateTransactionHistory() async =>
      await updateTransactions();

  int _getUnlockedBalance() => monero_wallet.getUnlockedBalance(
      accountIndex: walletAddresses.account!.id);

  int _getFrozenBalance() {
    var frozenBalance = 0;

    for (var coin in unspentCoinsInfo.values.where((element) =>
        element.walletId == id && element.accountIndex == walletAddresses.account!.id)) {
      if (coin.isFrozen && !coin.isSending) frozenBalance += coin.value;
    }

    return frozenBalance;
  }

  void _onNewBlock(int height, int blocksLeft, double ptc) async {
    try {
      if (walletInfo.isRecovery) {
        await _askForUpdateTransactionHistory();
        _askForUpdateBalance();
        walletAddresses.accountList.update();
      }

      if (blocksLeft < 100) {
        await _askForUpdateTransactionHistory();
        _askForUpdateBalance();
        walletAddresses.accountList.update();
        syncStatus = SyncedSyncStatus();

        if (!_hasSyncAfterStartup) {
          _hasSyncAfterStartup = true;
          await save();
        }

        if (walletInfo.isRecovery) {
          await setAsRecovered();
        }
      } else {
        syncStatus = SyncingSyncStatus(blocksLeft, ptc);
      }
    } catch (e) {
      printV(e.toString());
    }
  }

  void _onNewTransaction() async {
    try {
      await _askForUpdateTransactionHistory();
      _askForUpdateBalance();
      await Future<void>.delayed(Duration(seconds: 1));
    } catch (e) {
      printV(e.toString());
    }
  }

  void _updateSubAddress(bool enableAutoGenerate, {Account? account}) {
    if (enableAutoGenerate) {
      walletAddresses.updateUnusedSubaddress(
        accountIndex: account?.id ?? 0,
        defaultLabel: account?.label ?? '',
      );
    } else {
      walletAddresses.updateSubaddressList(accountIndex: account?.id ?? 0);
    }
  }

  @override
  void setExceptionHandler(void Function(FlutterErrorDetails) e) => onError = e;

  @override
  Future<String> signMessage(String message, {String? address}) async {
    final useAddress = address ?? "";
    return monero_wallet.signMessage(message, address: useAddress);
  }

  @override
  Future<bool> verifyMessage(String message, String signature, {String? address = null}) async {
    if (address == null) return false;

    return monero_wallet.verifyMessage(message, address, signature);
  }

  void setLedgerConnection(LedgerConnection connection) {
    final dummyWPtr = wptr ??
        monero.WalletManager_openWallet(wmPtr, path: '', password: '');
    enableLedgerExchange(dummyWPtr, connection);
  }
}
