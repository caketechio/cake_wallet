import 'package:mobx/mobx.dart';
import 'package:cw_core/balance.dart';
import 'package:cw_core/transaction_info.dart';
import 'package:cw_core/transaction_history.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/wallet_addresses.dart';
import 'package:flutter/foundation.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/currency_for_wallet_type.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/wallet_type.dart';

abstract class WalletBase<BalanceType extends Balance, HistoryType extends TransactionHistoryBase,
    TransactionType extends TransactionInfo> {
  WalletBase(this.walletInfo);

  static String idFor(String name, WalletType type) =>
      walletTypeToString(type).toLowerCase() + '_' + name;

  WalletInfo walletInfo;

  WalletType get type => walletInfo.type;

  CryptoCurrency get currency => currencyForWalletType(type, isTestnet: isTestnet);

  String get id => walletInfo.id;

  String get name => walletInfo.name;

  //String get address;

  //set address(String address);

  ObservableMap<CryptoCurrency, BalanceType> get balance;

  SyncStatus get syncStatus;

  set syncStatus(SyncStatus status);

  String? get seed;

  String? get privateKey => null;

  String? get hexSeed => null;

  Object get keys;

  WalletAddresses get walletAddresses;

  late HistoryType transactionHistory;

  set isEnabledAutoGenerateSubaddress(bool value) {}

  bool get isEnabledAutoGenerateSubaddress => false;

  bool get isHardwareWallet => walletInfo.isHardwareWallet;

  Future<void> connectToNode({required Node node});

  // there is a default definition here because only coins with a pow node (nano based) need to override this
  Future<void> connectToPowNode({required Node node}) async {}

  Future<void> startSync();

  Future<PendingTransaction> createTransaction(Object credentials);

  int calculateEstimatedFee(TransactionPriority priority, int? amount);

  // void fetchTransactionsAsync(
  //     void Function(TransactionType transaction) onTransactionLoaded,
  //     {void Function() onFinished});

  Future<Map<String, TransactionType>> fetchTransactions();

  Future<void> save();

  Future<void> rescan({required int height});

  void close({bool? switchingToSameWalletType});

  Future<void> changePassword(String password);

  String get password;

  Future<void>? updateBalance();

  void setExceptionHandler(void Function(FlutterErrorDetails) onError) => null;

  Future<void> renameWalletFiles(String newWalletName);

  Future<String> signMessage(String message, {String? address = null});

  Future<bool> verifyMessage(String message, String signature, {String? address = null});

  bool isTestnet = false;
}
