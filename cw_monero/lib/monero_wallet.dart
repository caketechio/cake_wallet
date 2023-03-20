import 'dart:async';
import 'package:cw_core/monero_balance.dart';
import 'package:cw_core/monero_wallet_keys.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/monero_amount_format.dart';
import 'package:cw_monero/monero_transaction_creation_exception.dart';
import 'package:cw_monero/monero_transaction_info.dart';
import 'package:cw_monero/monero_wallet_addresses.dart';
import 'package:cw_core/monero_wallet_utils.dart';
import 'package:cw_monero/api/structs/pending_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:cw_monero/api/transaction_history.dart'
    as monero_transaction_history;
import 'package:cw_monero/api/wallet.dart';
import 'package:cw_monero/api/wallet.dart' as monero_wallet;
import 'package:cw_monero/api/transaction_history.dart' as transaction_history;
import 'package:cw_monero/api/monero_output.dart';
import 'package:cw_monero/monero_transaction_creation_credentials.dart';
import 'package:cw_monero/pending_monero_transaction.dart';
import 'package:cw_monero/monero_fee_estimate.dart';
import 'package:cw_monero/monero_transaction_history.dart';
import 'package:cw_core/account.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/crypto_currency.dart';

part 'monero_wallet.g.dart';

const moneroBlockSize = 1000;

class MoneroWallet = MoneroWalletBase with _$MoneroWallet;

abstract class MoneroWalletBase extends WalletBase<MoneroBalance,
    MoneroTransactionHistory, MoneroTransactionInfo> with Store {
  MoneroWalletBase({required WalletInfo walletInfo})
      : balance = ObservableMap<CryptoCurrency, MoneroBalance>.of({
            CryptoCurrency.xmr: MoneroBalance(
              fullBalance: monero_wallet.getFullBalance(accountIndex: 0),
              unlockedBalance: monero_wallet.getFullBalance(accountIndex: 0))
            }),
        _isTransactionUpdating = false,
        _hasSyncAfterStartup = false,
        walletAddresses = MoneroWalletAddresses(walletInfo),
        syncStatus = NotConnectedSyncStatus(),
        feeEstimate = MoneroFeeEstimate(),
        super(walletInfo) {
    transactionHistory = MoneroTransactionHistory();
    _onAccountChangeReaction = reaction((_) => walletAddresses.account,
            (Account? account) {
      if (account == null) {
        return;
      }

      balance = ObservableMap<CryptoCurrency, MoneroBalance>.of(
        <CryptoCurrency, MoneroBalance>{
          currency: MoneroBalance(
            fullBalance: monero_wallet.getFullBalance(accountIndex: account.id),
            unlockedBalance:
                monero_wallet.getUnlockedBalance(accountIndex: account.id))
        });
      walletAddresses.updateSubaddressList(accountIndex: account.id);
    });
  }

  static const int _autoSaveInterval = 30;

  @override
  MoneroWalletAddresses walletAddresses;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  ObservableMap<CryptoCurrency, MoneroBalance> balance;

  @override
  MoneroFeeEstimate feeEstimate;

  @override
  String get seed => monero_wallet.getSeed();

  @override
  MoneroWalletKeys get keys => MoneroWalletKeys(
      privateSpendKey: monero_wallet.getSecretSpendKey(),
      privateViewKey: monero_wallet.getSecretViewKey(),
      publicSpendKey: monero_wallet.getPublicSpendKey(),
      publicViewKey: monero_wallet.getPublicViewKey());

  SyncListener? _listener;
  ReactionDisposer? _onAccountChangeReaction;
  bool _isTransactionUpdating;
  bool _hasSyncAfterStartup;
  Timer? _autoSaveTimer;

  Future<void> init() async {
    await walletAddresses.init();
    balance =  ObservableMap<CryptoCurrency, MoneroBalance>.of(
       <CryptoCurrency, MoneroBalance>{
          currency: MoneroBalance(
            fullBalance: monero_wallet.getFullBalance(accountIndex: walletAddresses.account!.id),
            unlockedBalance: monero_wallet.getUnlockedBalance(accountIndex: walletAddresses.account!.id))
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
       Duration(seconds: _autoSaveInterval),
       (_) async => await save());
  }

  @override
  void close() {
    _listener?.stop();
    _onAccountChangeReaction?.reaction.dispose();
    _autoSaveTimer?.cancel();
  }

  @override
  Future<void> connectToNode({required Node node}) async {
    try {
      syncStatus = ConnectingSyncStatus();
      await monero_wallet.setupNode(
          address: node.uri.toString(),
          login: node.login,
          password: node.password,
          useSSL: node.isSSL,
          isLightWallet: false); // FIXME: hardcoded value

      monero_wallet.setTrustedDaemon(node.trusted);
      syncStatus = ConnectedSyncStatus();
    } catch (e) {
      syncStatus = FailedSyncStatus();
      print(e);
    }
  }

  @override
  Future<void> startSync() async {
    try {
      _setInitialHeight();
    } catch (_) {}

    try {
      syncStatus = AttemptingSyncStatus();
      monero_wallet.startRefresh();
      _setListeners();
      _listener?.start();
    } catch (e) {
      syncStatus = FailedSyncStatus();
      print(e);
      rethrow;
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    final _credentials = credentials as MoneroTransactionCreationCredentials;
    final outputs = _credentials.outputs;
    final hasMultiDestination = outputs.length > 1;
    final unlockedBalance =
    monero_wallet.getUnlockedBalance(accountIndex: walletAddresses.account!.id);

    PendingTransactionDescription pendingTransactionDescription;

    if (!(syncStatus is SyncedSyncStatus)) {
      throw MoneroTransactionCreationException('The wallet is not synced.');
    }

    if (hasMultiDestination) {
      if (outputs.any((item) => item.sendAll
          || (item.formattedCryptoAmount ?? 0) <= 0)) {
        throw MoneroTransactionCreationException('Wrong balance. Not enough XMR on your balance.');
      }

      final int totalAmount = outputs.fold(0, (acc, value) =>
          acc + (value.formattedCryptoAmount ?? 0));

      if (unlockedBalance < totalAmount) {
        throw MoneroTransactionCreationException('Wrong balance. Not enough XMR on your balance.');
      }

      final moneroOutputs = outputs.map((output) {
      final outputAddress = output.isParsedAddress
          ? output.extractedAddress
          : output.address;

      return MoneroOutput(
          address: outputAddress!,
          amount: output.cryptoAmount!.replaceAll(',', '.'));
      }).toList();

      pendingTransactionDescription =
      await transaction_history.createTransactionMultDest(
          outputs: moneroOutputs,
          priorityRaw: _credentials.priority.serialize(),
          accountIndex: walletAddresses.account!.id);
    } else {
      final output = outputs.first;
      final address = output.isParsedAddress
          ? output.extractedAddress
          : output.address;
      final amount = output.sendAll
          ? null
          : output.cryptoAmount!.replaceAll(',', '.');
      final formattedAmount = output.sendAll
          ? null
          : output.formattedCryptoAmount;

      if ((formattedAmount != null && unlockedBalance < formattedAmount) ||
          (formattedAmount == null && unlockedBalance <= 0)) {
        final formattedBalance = moneroAmountToString(amount: unlockedBalance);

        throw MoneroTransactionCreationException(
            'Incorrect unlocked balance. Unlocked: $formattedBalance. Transaction amount: ${output.cryptoAmount}.');
      }

      pendingTransactionDescription =
      await transaction_history.createTransaction(
          address: address!,
          amount: amount,
          priorityRaw: _credentials.priority.serialize(),
          accountIndex: walletAddresses.account!.id);
    }

    return PendingMoneroTransaction(pendingTransactionDescription);
  }

  @override
  Future<void> save() async {
    await walletAddresses.updateAddressesInBox();
    await backupWalletFiles(name);
    await monero_wallet.store();
  }

  @override
  Future<void> changePassword(String password) async {
    monero_wallet.setPasswordSync(password);
  }

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

  String getTransactionAddress(int accountIndex, int addressIndex) =>
      monero_wallet.getAddress(
          accountIndex: accountIndex,
          addressIndex: addressIndex);

  @override
  Future<Map<String, MoneroTransactionInfo>> fetchTransactions() async {
    monero_transaction_history.refreshTransactions();
    return _getAllTransactions(null).fold<Map<String, MoneroTransactionInfo>>(
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
      transactionHistory.addMany(transactions);
      await transactionHistory.save();
      _isTransactionUpdating = false;
    } catch (e) {
      print(e);
      _isTransactionUpdating = false;
    }
  }

  String getSubaddressLabel(int accountIndex, int addressIndex) {
    return monero_wallet.getSubaddressLabel(accountIndex, addressIndex);
  }

  List<MoneroTransactionInfo> _getAllTransactions(dynamic _) =>
      monero_transaction_history
          .getAllTransations()
          .map((row) => MoneroTransactionInfo.fromRow(row))
          .toList();

  void _setListeners() {
    _listener?.stop();
    _listener = monero_wallet.setListeners(_onNewBlock, _onNewTransaction);
  }

  void _setInitialHeight() {
    if (walletInfo.isRecovery) {
      return;
    }

    final currentHeight = getCurrentHeight();

    if (currentHeight <= 1) {
      final height = _getHeightByDate(walletInfo.date);
      monero_wallet.setRecoveringFromSeed(isRecovery: true);
      monero_wallet.setRefreshFromBlockHeight(height: height);
    }
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
      return 0;
    }

    return nodeHeight - heightDistance;
  }

  void _askForUpdateBalance() {
    final unlockedBalance = _getUnlockedBalance();
    final fullBalance = _getFullBalance();

    if (balance[currency]!.fullBalance != fullBalance ||
        balance[currency]!.unlockedBalance != unlockedBalance) {
      balance[currency] = MoneroBalance(
          fullBalance: fullBalance, unlockedBalance: unlockedBalance);
    }
  }

  Future<void> _askForUpdateTransactionHistory() async =>
      await updateTransactions();

  int _getFullBalance() =>
      monero_wallet.getFullBalance(accountIndex: walletAddresses.account!.id);

  int _getUnlockedBalance() =>
      monero_wallet.getUnlockedBalance(accountIndex: walletAddresses.account!.id);

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
      print(e.toString());
    }
  }

  void _onNewTransaction() async {
    try {
      await _askForUpdateTransactionHistory();
      _askForUpdateBalance();
      await Future<void>.delayed(Duration(seconds: 1));
    } catch (e) {
      print(e.toString());
    }
  }
}
