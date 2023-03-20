import 'dart:ffi';
import 'package:cw_monero/api/structs/pending_transaction.dart';
import 'package:cw_monero/api/structs/ut8_box.dart';
import 'package:ffi/ffi.dart';

typedef CreateWallet = int Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, Pointer<Utf8>);

typedef RestoreWalletFromSeed = int Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, int, Pointer<Utf8>);

typedef RestoreWalletFromKeys = int Function(Pointer<Utf8>, Pointer<Utf8>,
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, int, Pointer<Utf8>);

typedef IsWalletExist = int Function(Pointer<Utf8>);

typedef LoadWallet = int Function(Pointer<Utf8>, Pointer<Utf8>, int);

typedef ErrorString = Pointer<Utf8> Function();

typedef GetFilename = Pointer<Utf8> Function();

typedef GetSeed = Pointer<Utf8> Function();

typedef GetAddress = Pointer<Utf8> Function(int, int);

typedef GetFullBalance = int Function(int);

typedef GetUnlockedBalance = int Function(int);

typedef GetCurrentHeight = int Function();

typedef GetNodeHeight = int Function();

typedef IsConnected = int Function();

typedef SetupNode = int Function(
    Pointer<Utf8>, Pointer<Utf8>?, Pointer<Utf8>?, int, int, Pointer<Utf8>);

typedef StartRefresh = void Function();

typedef ConnectToNode = int Function();

typedef SetRefreshFromBlockHeight = void Function(int);

typedef SetRecoveringFromSeed = void Function(int);

typedef Store = void Function(Pointer<Utf8>);

typedef SetPassword = int Function(Pointer<Utf8> password, Pointer<Utf8Box> error);

typedef SetListener = void Function();

typedef GetSyncingHeight = int Function();

typedef IsNeededToRefresh = int Function();

typedef IsNewTransactionExist = int Function();

typedef SubaddressSize = int Function();

typedef SubaddressRefresh = void Function(int);

typedef SubaddressGetAll = Pointer<Int64> Function();

typedef SubaddressAddNew = void Function(int accountIndex, Pointer<Utf8> label);

typedef SubaddressSetLabel = void Function(
    int accountIndex, int addressIndex, Pointer<Utf8> label);

typedef AccountSize = int Function();

typedef AccountRefresh = void Function();

typedef AccountGetAll = Pointer<Int64> Function();

typedef AccountAddNew = void Function(Pointer<Utf8> label);

typedef AccountSetLabel = void Function(int accountIndex, Pointer<Utf8> label);

typedef TransactionsRefresh = void Function();

typedef GetTxKey = Pointer<Utf8>? Function(Pointer<Utf8> txId);

typedef TransactionsCount = int Function();

typedef TransactionsGetAll = Pointer<Int64> Function();

typedef TransactionCreate = int Function(
    Pointer<Utf8> address,
    Pointer<Utf8> paymentId,
    Pointer<Utf8> amount,
    int priorityRaw,
    int subaddrAccount,
    Pointer<Utf8Box> error,
    Pointer<PendingTransactionRaw> pendingTransaction);

typedef TransactionCreateMultDest = int Function(
    Pointer<Pointer<Utf8>> addresses,
    Pointer<Utf8> paymentId,
    Pointer<Pointer<Utf8>> amounts,
    int size,
    int priorityRaw,
    int subaddrAccount,
    Pointer<Utf8Box> error,
    Pointer<PendingTransactionRaw> pendingTransaction);

typedef TransactionCommit = int Function(Pointer<PendingTransactionRaw>, Pointer<Utf8Box>);

typedef SecretViewKey = Pointer<Utf8> Function();

typedef PublicViewKey = Pointer<Utf8> Function();

typedef SecretSpendKey = Pointer<Utf8> Function();

typedef PublicSpendKey = Pointer<Utf8> Function();

typedef CloseCurrentWallet = void Function();

typedef OnStartup = void Function();

typedef RescanBlockchainAsync = void Function();

typedef GetSubaddressLabel = Pointer<Utf8> Function(
    int accountIndex,
    int addressIndex);

typedef SetTrustedDaemon = void Function(int);

typedef TrustedDaemon = int Function();

typedef EstimateTransactionFee = int Function(int, int);
