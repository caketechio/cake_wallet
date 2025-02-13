import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cw_core/transaction_direction.dart';
import 'package:cw_core/utils/print_verbose.dart';
import 'package:cw_decred/pending_transaction.dart';
import 'package:cw_decred/transaction_credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:mobx/mobx.dart';
import 'package:hive/hive.dart';

import 'package:cw_decred/api/libdcrwallet.dart' as libdcrwallet;
import 'package:cw_decred/transaction_history.dart';
import 'package:cw_decred/wallet_addresses.dart';
import 'package:cw_decred/transaction_priority.dart';
import 'package:cw_decred/wallet_service.dart';
import 'package:cw_decred/balance.dart';
import 'package:cw_decred/transaction_info.dart';
import 'package:cw_core/crypto_currency.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/transaction_priority.dart';
import 'package:cw_core/pending_transaction.dart';
import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/sync_status.dart';
import 'package:cw_core/node.dart';
import 'package:cw_core/unspent_coins_info.dart';
import 'package:cw_core/unspent_transaction_output.dart';

part 'wallet.g.dart';

class DecredWallet = DecredWalletBase with _$DecredWallet;

abstract class DecredWalletBase
    extends WalletBase<DecredBalance, DecredTransactionHistory, DecredTransactionInfo> with Store {
  DecredWalletBase(WalletInfo walletInfo, String password, Box<UnspentCoinsInfo> unspentCoinsInfo)
      : _password = password,
        this.syncStatus = NotConnectedSyncStatus(),
        this.unspentCoinsInfo = unspentCoinsInfo,
        this.watchingOnly =
            walletInfo.derivationInfo?.derivationPath == DecredWalletService.pubkeyRestorePath ||
                walletInfo.derivationInfo?.derivationPath ==
                    DecredWalletService.pubkeyRestorePathTestnet,
        this.balance = ObservableMap.of({CryptoCurrency.dcr: DecredBalance.zero()}),
        this.isTestnet = walletInfo.derivationInfo?.derivationPath ==
                DecredWalletService.seedRestorePathTestnet ||
            walletInfo.derivationInfo?.derivationPath ==
                DecredWalletService.pubkeyRestorePathTestnet,
        super(walletInfo) {
    walletAddresses = DecredWalletAddresses(walletInfo);
    transactionHistory = DecredTransactionHistory();

    reaction((_) => isEnabledAutoGenerateSubaddress, (bool enabled) {
      this.walletAddresses.isEnabledAutoGenerateSubaddress = enabled;
    });
  }

  // NOTE: Hitting this max fee would be unexpected with current on chain use
  // but this may need to be updated in the future.
  final maxFeeRate = 100000;

  // syncIntervalSyncing is used up until synced, then transactions are checked
  // every syncIntervalSynced.
  final syncIntervalSyncing = 5; // seconds
  final syncIntervalSynced = 30; // seconds
  static final defaultFeeRate = 10000;
  final String _password;
  final idPrefix = "decred_";

  // synced is used to set the syncTimer interval.
  bool synced = false;
  bool watchingOnly;
  bool connecting = false;
  String persistantPeer = "default-spv-nodes";
  FeeCache feeRateFast = FeeCache(defaultFeeRate);
  FeeCache feeRateMedium = FeeCache(defaultFeeRate);
  FeeCache feeRateSlow = FeeCache(defaultFeeRate);
  Timer? syncTimer;
  Box<UnspentCoinsInfo> unspentCoinsInfo;

  @override
  @observable
  bool isEnabledAutoGenerateSubaddress = true;

  @override
  @observable
  SyncStatus syncStatus;

  @override
  @observable
  late ObservableMap<CryptoCurrency, DecredBalance> balance;

  @override
  late DecredWalletAddresses walletAddresses;

  @override
  String? get seed {
    if (watchingOnly) {
      return null;
    }
    return libdcrwallet.walletSeed(walletInfo.name, _password);
  }

  @override
  Object get keys => {};

  @override
  bool isTestnet;

  String get pubkey {
    return libdcrwallet.defaultPubkey(walletInfo.name);
  }

  Future<void> init() async {
    await updateBalance();
    await updateTransactionHistory();
    await walletAddresses.init();

    fetchTransactions();
  }

  void performBackgroundTasks() async {
    if (!checkSync()) {
      if (synced == true) {
        synced = false;
        if (syncTimer != null) {
          syncTimer!.cancel();
        }
        syncTimer = Timer.periodic(
            Duration(seconds: syncIntervalSyncing), (Timer t) => performBackgroundTasks());
      }
      return;
    }
    await updateBalance();
    await walletAddresses.updateAddressesInBox();
    // Set sync check interval lower since we are synced.
    if (synced == false) {
      synced = true;
      if (syncTimer != null) {
        syncTimer!.cancel();
      }
      syncTimer = Timer.periodic(
          Duration(seconds: syncIntervalSynced), (Timer t) => performBackgroundTasks());
    }
    await updateTransactionHistory();
  }

  Future<void> updateTransactionHistory() async {
    // from is the number of transactions skipped from most recent, not block
    // height.
    var from = 0;
    while (true) {
      // Transactions are returned from newest to oldest. Loop fetching 5 txn
      // at a time until we find a batch with txn that no longer need to be
      // updated.
      final txs = await this.fetchFiveTransactions(from);
      if (txs.length == 0) {
        return;
      }
      if (this.transactionHistory.update(txs)) {
        return;
      }
      from += 5;
    }
  }

  bool checkSync() {
    final syncStatusJSON = libdcrwallet.syncStatus(walletInfo.name);
    final decoded = json.decode(syncStatusJSON);

    final syncStatusCode = decoded["syncstatuscode"] ?? 0;
    // final syncStatusStr = decoded["syncstatus"] ?? "";
    final targetHeight = decoded["targetheight"] ?? 1;
    final numPeers = decoded["numpeers"] ?? 0;
    // final cFiltersHeight = decoded["cfiltersheight"] ?? 0;
    final headersHeight = decoded["headersheight"] ?? 0;
    final rescanHeight = decoded["rescanheight"] ?? 0;

    if (numPeers == 0) {
      syncStatus = NotConnectedSyncStatus();
      return false;
    }

    // Sync codes:
    // NotStarted = 0
    // FetchingCFilters = 1
    // FetchingHeaders = 2
    // DiscoveringAddrs = 3
    // Rescanning = 4
    // Complete = 5

    if (syncStatusCode > 4) {
      syncStatus = SyncedSyncStatus();
      return true;
    }

    if (syncStatusCode == 0) {
      syncStatus = ConnectedSyncStatus();
      return false;
    }

    if (syncStatusCode == 1) {
      syncStatus = SyncingSyncStatus(targetHeight, 0.0);
      return false;
    }

    if (syncStatusCode == 2) {
      final headersProg = headersHeight / targetHeight;
      // Only allow headers progress to go up half way.
      syncStatus = SyncingSyncStatus(targetHeight - headersHeight, headersProg);
      return false;
    }

    // TODO: This step takes a while so should really get more info to the UI
    // that we are discovering addresses.
    if (syncStatusCode == 3) {
      // Hover at half.
      syncStatus = ProcessingSyncStatus();
      return false;
    }

    if (syncStatusCode == 4) {
      // Start at 75%.
      final rescanProg = rescanHeight / targetHeight / 4;
      syncStatus = SyncingSyncStatus(targetHeight - rescanHeight, .75 + rescanProg);
      return false;
    }
    return false;
  }

  @action
  @override
  Future<void> connectToNode({required Node node}) async {
    if (connecting) {
      return;
    }
    connecting = true;
    String addr = "default-spv-nodes";
    if (node.uri.host != addr) {
      addr = node.uri.host;
      if (node.uri.port != "") {
        addr += ":" + node.uri.port.toString();
      }
    }
    if (addr != persistantPeer) {
      if (syncTimer != null) {
        syncTimer!.cancel();
        syncTimer = null;
      }
      persistantPeer = addr;
      libdcrwallet.closeWallet(walletInfo.name);
      final network = isTestnet ? "testnet" : "mainnet";
      final config = {
        "name": walletInfo.name,
        "datadir": walletInfo.dirPath,
        "net": network,
        "unsyncedaddrs": true,
      };
      libdcrwallet.loadWalletSync(jsonEncode(config));
    }
    await this._startSync();
    connecting = false;
  }

  @action
  @override
  Future<void> startSync() async {
    if (connecting) {
      return;
    }
    connecting = true;
    await this._startSync();
    connecting = false;
  }

  Future<void> _startSync() async {
    if (syncTimer != null) {
      return;
    }
    try {
      syncStatus = ConnectingSyncStatus();
      libdcrwallet.startSyncAsync(
        name: walletInfo.name,
        peers: persistantPeer == "default-spv-nodes" ? "" : persistantPeer,
      );
      syncTimer = Timer.periodic(
          Duration(seconds: syncIntervalSyncing), (Timer t) => performBackgroundTasks());
    } catch (e) {
      printV(e.toString());
      syncStatus = FailedSyncStatus();
    }
  }

  @override
  Future<PendingTransaction> createTransaction(Object credentials) async {
    if (watchingOnly) {
      return DecredPendingTransaction(
          txid: "",
          amount: 0,
          fee: 0,
          rawHex: "",
          send: () async {
            throw "unable to send with watching only wallet";
          });
    }
    var totalIn = 0;
    final ignoreInputs = [];
    this.unspentCoinsInfo.values.forEach((unspent) {
      if (unspent.isFrozen || !unspent.isSending) {
        final input = {"txid": unspent.hash, "vout": unspent.vout};
        ignoreInputs.add(input);
        return;
      }
      totalIn += unspent.value;
    });
    final creds = credentials as DecredTransactionCredentials;
    var totalAmt = 0;
    var sendAll = false;
    final outputs = [];
    for (final out in creds.outputs) {
      var amt = 0;
      if (out.sendAll) {
        if (creds.outputs.length != 1) {
          throw "can only send all to one output";
        }
        sendAll = true;
        totalAmt = totalIn;
      } else if (out.cryptoAmount != null) {
        final coins = double.parse(out.cryptoAmount!);
        amt = (coins * 1e8).toInt();
      }
      totalAmt += amt;
      final o = {
        "address": out.isParsedAddress ? out.extractedAddress! : out.address,
        "amount": amt
      };
      outputs.add(o);
    }

    // The inputs are always used. Currently we don't have use for this
    // argument. sendall ingores output value and sends everything.
    final signReq = {
      // "inputs": inputs,
      "ignoreInputs": ignoreInputs,
      "outputs": outputs,
      "feerate": creds.feeRate ?? defaultFeeRate,
      "password": _password,
      "sendall": sendAll,
    };
    final res = libdcrwallet.createSignedTransaction(walletInfo.name, jsonEncode(signReq));
    final decoded = json.decode(res);
    final signedHex = decoded["signedhex"];
    final send = () async {
      libdcrwallet.sendRawTransaction(walletInfo.name, signedHex);
      await updateBalance();
    };
    final fee = decoded["fee"] ?? 0;
    if (sendAll) {
      totalAmt = (totalAmt - fee).toInt();
    }
    return DecredPendingTransaction(
        txid: decoded["txid"] ?? "", amount: totalAmt, fee: fee, rawHex: signedHex, send: send);
  }

  int feeRate(TransactionPriority priority) {
    if (!(priority is DecredTransactionPriority)) {
      return defaultFeeRate;
    }
    int Function(int nb) feeForNb = (int nb) {
      try {
        final feeStr = libdcrwallet.estimateFee(walletInfo.name, nb);
        var fee = int.parse(feeStr);
        if (fee > maxFeeRate) {
          throw "dcr fee returned from estimate fee was over max";
        } else if (fee <= 0) {
          throw "dcr fee returned from estimate fee was zero";
        }
        return fee;
      } catch (e) {
        printV(e);
        return defaultFeeRate;
      }
    };
    final p = priority;
    switch (p) {
      case DecredTransactionPriority.slow:
        if (feeRateSlow.isOld()) {
          feeRateSlow.update(feeForNb(4));
        }
        return feeRateSlow.feeRate();
      case DecredTransactionPriority.medium:
        if (feeRateMedium.isOld()) {
          feeRateMedium.update(feeForNb(2));
        }
        return feeRateMedium.feeRate();
      case DecredTransactionPriority.fast:
        if (feeRateFast.isOld()) {
          feeRateFast.update(feeForNb(1));
        }
        return feeRateFast.feeRate();
    }
    return defaultFeeRate;
  }

  @override
  int calculateEstimatedFee(TransactionPriority priority, int? amount) {
    if (priority is DecredTransactionPriority) {
      final P2PKHOutputSize =
          36; // 8 bytes value + 2 bytes version + at least 1 byte varint script size + P2PKHPkScriptSize
      // MsgTxOverhead is 4 bytes version (lower 2 bytes for the real transaction
      // version and upper 2 bytes for the serialization type) + 4 bytes locktime
      // + 4 bytes expiry + 3 bytes of varints for the number of transaction
      // inputs (x2 for witness and prefix) and outputs
      final MsgTxOverhead = 15;
      // TxInOverhead is the overhead for a wire.TxIn with a scriptSig length <
      // 254. prefix (41 bytes) + ValueIn (8 bytes) + BlockHeight (4 bytes) +
      // BlockIndex (4 bytes) + sig script var int (at least 1 byte)
      final TxInOverhead = 57;
      final P2PKHInputSize =
          TxInOverhead + 109; // TxInOverhead (57) + var int (1) + P2PKHSigScriptSize (108)

      // Estimate using a transaction consuming three inputs and paying to one
      // address with change.
      return this.feeRate(priority) * (MsgTxOverhead + P2PKHInputSize * 3 + P2PKHOutputSize * 2);
    }
    return 0;
  }

  @override
  Future<Map<String, DecredTransactionInfo>> fetchTransactions() async {
    return this.fetchFiveTransactions(0);
  }

  Future<Map<String, DecredTransactionInfo>> fetchFiveTransactions(int from) async {
    final res = libdcrwallet.listTransactions(walletInfo.name, from.toString(), "5");
    final decoded = json.decode(res);
    var txs = <String, DecredTransactionInfo>{};
    for (final d in decoded) {
      final txid = uniqueTxID(d["txid"] ?? "", d["vout"] ?? 0);
      var direction = TransactionDirection.outgoing;
      if (d["category"] == "receive") {
        direction = TransactionDirection.incoming;
      }
      final amountDouble = d["amount"] ?? 0.0;
      final amount = (amountDouble * 1e8).toInt().abs();
      final feeDouble = d["fee"] ?? 0.0;
      final fee = (feeDouble * 1e8).toInt().abs();
      final confs = d["confirmations"] ?? 0;
      final sendTime = d["time"] ?? 0;
      final height = d["height"] ?? 0;
      final txInfo = DecredTransactionInfo(
        id: txid,
        amount: amount,
        fee: fee,
        direction: direction,
        isPending: confs == 0,
        date: DateTime.fromMillisecondsSinceEpoch(sendTime * 1000, isUtc: true),
        height: height,
        confirmations: confs,
        to: d["address"] ?? "",
      );
      txs[txid] = txInfo;
    }
    return txs;
  }

  // uniqueTxID combines the tx id and vout to create a unique id.
  String uniqueTxID(String id, int vout) {
    return id + ":" + vout.toString();
  }

  @override
  Future<void> save() async {}

  @override
  bool get hasRescan => walletBirthdayBlockHeight() != -1;

  @override
  Future<void> rescan({required int height}) async {
    // The required height is not used. A birthday time is recorded in the
    // mnemonic. As long as not private data is imported into the wallet, we
    // can always rescan from there.
    var rescanHeight = 0;
    if (!watchingOnly) {
      rescanHeight = walletBirthdayBlockHeight();
      // Sync has not yet reached the birthday block.
      if (rescanHeight == -1) {
        return;
      }
    }
    libdcrwallet.rescanFromHeight(walletInfo.name, rescanHeight.toString());
  }

  @override
  Future<void> close({bool shouldCleanup = false}) async {
    if (syncTimer != null) {
      syncTimer!.cancel();
      syncTimer = null;
    }
    return () async {
      libdcrwallet.closeWallet(walletInfo.name);
    }();
  }

  @override
  Future<void> changePassword(String password) async {
    if (watchingOnly) {
      return;
    }
    return () async {
      libdcrwallet.changeWalletPassword(walletInfo.name, _password, password);
    }();
  }

  @override
  Future<void>? updateBalance() async {
    final balanceMap = libdcrwallet.balance(walletInfo.name);
    balance[CryptoCurrency.dcr] = DecredBalance(
      confirmed: balanceMap["confirmed"] ?? 0,
      unconfirmed: balanceMap["unconfirmed"] ?? 0,
    );
  }

  @override
  void setExceptionHandler(void Function(FlutterErrorDetails) onError) => onError;

  Future<void> renameWalletFiles(String newWalletName) async {
    final currentDirPath = await pathForWalletDir(name: walletInfo.name, type: type);

    final newDirPath = await pathForWalletDir(name: newWalletName, type: type);

    if (File(newDirPath).existsSync()) {
      throw "wallet already exists at $newDirPath";
    }
    ;

    await Directory(currentDirPath).rename(newDirPath);
  }

  @override
  Future<String> signMessage(String message, {String? address = null}) {
    if (watchingOnly) {
      throw "a watching only wallet cannot sign";
    }
    var addr = address;
    if (addr == null) {
      addr = walletAddresses.address;
    }
    if (addr == "") {
      throw "unable to get an address from unsynced wallet";
    }
    return libdcrwallet.signMessageAsync(walletInfo.name, message, addr, _password);
  }

  List<Unspent> unspents() {
    final res = libdcrwallet.listUnspents(walletInfo.name);
    final decoded = json.decode(res);
    var unspents = <Unspent>[];
    for (final d in decoded) {
      final spendable = d["spendable"] ?? false;
      if (!spendable) {
        continue;
      }
      final amountDouble = d["amount"] ?? 0.0;
      final amount = (amountDouble * 1e8).toInt().abs();
      final utxo = Unspent(d["address"] ?? "", d["txid"] ?? "", amount, d["vout"] ?? 0, null);
      utxo.isChange = d["ischange"] ?? false;
      unspents.add(utxo);
    }
    this.updateUnspents(unspents);
    return unspents;
  }

  void updateUnspents(List<Unspent> unspentCoins) {
    if (this.unspentCoinsInfo.isEmpty) {
      unspentCoins.forEach((coin) => this.addCoinInfo(coin));
      return;
    }

    if (unspentCoins.isEmpty) {
      this.unspentCoinsInfo.clear();
      return;
    }

    final walletID = idPrefix + walletInfo.name;
    if (unspentCoins.isNotEmpty) {
      unspentCoins.forEach((coin) {
        final coinInfoList = this.unspentCoinsInfo.values.where((element) =>
            element.walletId == walletID && element.hash == coin.hash && element.vout == coin.vout);

        if (coinInfoList.isEmpty) {
          this.addCoinInfo(coin);
        } else {
          final coinInfo = coinInfoList.first;

          coin.isFrozen = coinInfo.isFrozen;
          coin.isSending = coinInfo.isSending;
          coin.note = coinInfo.note;
        }
      });
    }

    final List<dynamic> keys = <dynamic>[];
    this.unspentCoinsInfo.values.forEach((element) {
      final existUnspentCoins = unspentCoins.where((coin) => element.hash.contains(coin.hash));

      if (existUnspentCoins.isEmpty) {
        keys.add(element.key);
      }
    });

    if (keys.isNotEmpty) {
      unspentCoinsInfo.deleteAll(keys);
    }
  }

  void addCoinInfo(Unspent coin) {
    final newInfo = UnspentCoinsInfo(
      walletId: idPrefix + walletInfo.name,
      hash: coin.hash,
      isFrozen: false,
      isSending: coin.isSending,
      noteRaw: "",
      address: coin.address,
      value: coin.value,
      vout: coin.vout,
      isChange: coin.isChange,
      keyImage: coin.keyImage,
    );

    unspentCoinsInfo.add(newInfo);
  }

  // walletBirthdayBlockHeight checks if the wallet birthday is set and returns
  // it. Returns -1 if not.
  int walletBirthdayBlockHeight() {
    final res = libdcrwallet.birthState(walletInfo.name);
    final decoded = json.decode(res);
    // Having these values set indicates that sync has not reached the birthday
    // yet, so no birthday is set.
    if (decoded["setfromheight"] == true || decoded["setfromtime"] == true) {
      return -1;
    }
    return decoded["height"] ?? 0;
  }

  Future<bool> verifyMessage(String message, String signature, {String? address = null}) {
    var addr = address;
    if (addr == null) {
      throw "an address is required to verify message";
    }
    return () async {
      final verified = libdcrwallet.verifyMessage(walletInfo.name, message, addr, signature);
      if (verified == "true") {
        return true;
      }
      return false;
    }();
  }

  @override
  String get password => _password;
}
